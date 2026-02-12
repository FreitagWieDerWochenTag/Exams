import SwiftUI
import PDFKit
import PencilKit

// MARK: - Page Types

enum PageType {
    case blank
    case lined
    case grid
}

// MARK: - SwiftUI View

struct PDFViewerView: View {
    let klasse: String
    let fach: String
    let pdfName: String
    let studentName: String
    var isTeacherView: Bool = false

    @State private var containerView: PDFContainerView?
    @Environment(\.dismiss) private var dismiss

    @State private var showExitConfirm = false
    @State private var isSubmitting = false
    @State private var showSubmitResult = false
    @State private var submitSuccess = false

    var body: some View {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let nestedFileURL = buildFileURL(docs: docs)

        PDFViewRepresentable(pdfName: pdfName, fileURL: nestedFileURL, containerRef: $containerView, isTeacherView: isTeacherView)
            .navigationTitle(pdfName)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)

            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if isTeacherView {
                            dismiss()
                        } else {
                            showExitConfirm = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text(isTeacherView ? "Zurück" : "Test beenden")
                        }
                    }
                    .disabled(isSubmitting)
                }
                
                if !isTeacherView {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                addBlankPage(type: .blank)
                            } label: {
                                Label("Leere Seite", systemImage: "doc")
                            }
                            
                            Button {
                                addBlankPage(type: .lined)
                            } label: {
                                Label("Linierte Seite", systemImage: "text.alignleft")
                            }
                            
                            Button {
                                addBlankPage(type: .grid)
                            } label: {
                                Label("Karierte Seite", systemImage: "squareshape.split.3x3")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .disabled(isSubmitting)
                    }
                }
            }

            .confirmationDialog(
                "Test abgeben?",
                isPresented: $showExitConfirm,
                titleVisibility: .visible
            ) {
                Button("Ja, abgeben", role: .destructive) {
                    submitAndClose()
                }
                Button("Abbrechen", role: .cancel) {
                    // Dialog schließen ohne Aktion
                }
            } message: {
                Text("Der Test ist danach nicht mehr bearbeitbar.")
            }

            .alert("Abgabe", isPresented: $showSubmitResult) {
                Button("OK") {
                    if submitSuccess {
                        dismiss()
                    }
                }
            } message: {
                Text(submitSuccess
                     ? "Deine Abgabe wurde erfolgreich gesendet."
                     : "Die Abgabe ist fehlgeschlagen. Bitte erneut versuchen.")
            }
    }

    private func buildFileURL(docs: URL) -> URL {
        if isTeacherView {
            // Lehrer sehen Abgaben im Submissions-Ordner
            return docs.appendingPathComponent("Exams")
                .appendingPathComponent(klasse)
                .appendingPathComponent(fach)
                .appendingPathComponent("Submissions")
                .appendingPathComponent(pdfName)
        } else {
            // Schüler sehen ihre Tests im normalen Ordner
            return docs.appendingPathComponent("Exams")
                .appendingPathComponent(klasse)
                .appendingPathComponent(fach)
                .appendingPathComponent(pdfName)
        }
    }

    private func submitAndClose() {
        isSubmitting = true
        
        // WICHTIG: Speichere Zeichnungen bevor wir das PDF laden
        containerView?.saveDrawingToPDF()

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = docs.appendingPathComponent("Exams")
            .appendingPathComponent(klasse)
            .appendingPathComponent(fach)
            .appendingPathComponent(pdfName)

        guard let data = try? Data(contentsOf: fileURL) else {
            print("=== Submit: PDF konnte nicht geladen werden ===")
            submitSuccess = false
            showSubmitResult = true
            isSubmitting = false
            return
        }

        // Name formatieren: "Max Mustermann" -> "Mustermann_Max.pdf"
        let studentFilename = formatStudentFilename(studentName)
        print("=== Submit: Original Name: '\(studentName)' ===")
        print("=== Submit: Formatted Filename: '\(studentFilename)' ===")
        print("=== Submit: Klasse=\(klasse), Fach=\(fach), Test=\(pdfName) ===")
        print("=== Submit: Student File=\(studentFilename), Size=\(data.count) bytes ===")

        // Der Filename für die Submit-API ist der Test-Name (z.B. "Angabe.pdf")
        // Der eigentliche Schüler-Dateiname wird als Multipart-Filename verwendet
        RPiService.shared.submitTest(klasse: klasse,
                                     fach: fach,
                                     filename: pdfName,  // Test-Name für URL
                                     studentFilename: studentFilename,  // Schüler-Name für Datei
                                     pdfData: data) { success in
            print("=== Submit: Server Antwort: \(success ? "OK" : "FEHLER") ===")
            
            if success {
                // Markiere Test als abgegeben
                UserDefaults.standard.set(true, forKey: "submitted_\(klasse)_\(fach)_\(pdfName)")
                
                // Lösche die gespeicherten Zeichnungen (nicht mehr nötig nach Submit)
                PDFStorage.delete(for: pdfName, klasse: klasse, fach: fach)
            }
            
            submitSuccess = success
            showSubmitResult = true
            isSubmitting = false
        }
    }

    private func addBlankPage(type: PageType) {
        containerView?.addBlankPage(type: type)
    }

    /// "Max Mustermann" -> "Max_Mustermann.pdf"
    /// "Mustermann, Max" -> "Max_Mustermann.pdf"
    private func formatStudentFilename(_ name: String) -> String {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "Unbekannt.pdf" }

        var vorname = ""
        var nachname = ""
        
        if cleaned.contains(",") {
            // "Mustermann, Max" -> ["Mustermann", "Max"]
            let parts = cleaned.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count >= 2 {
                nachname = parts[0]
                vorname = parts[1]
            } else if parts.count == 1 {
                nachname = parts[0]
            }
        } else {
            // "Max Mustermann" -> Vorname ist erstes Wort(e), Nachname ist letztes
            let words = cleaned.split(separator: " ").map(String.init)
            if words.count >= 2 {
                vorname = words.dropLast().joined(separator: " ")
                nachname = words.last!
            } else if words.count == 1 {
                vorname = words[0]
            }
        }
        
        // Entferne Leerzeichen und erstelle Filename: Vorname_Nachname.pdf
        let vornameClean = vorname.replacingOccurrences(of: " ", with: "_")
        let nachnameClean = nachname.replacingOccurrences(of: " ", with: "_")
        
        if !vornameClean.isEmpty && !nachnameClean.isEmpty {
            return "\(vornameClean)_\(nachnameClean).pdf"
        } else if !vornameClean.isEmpty {
            return "\(vornameClean).pdf"
        } else {
            return "\(nachnameClean).pdf"
        }
    }
}

// MARK: - Brücke: SwiftUI <-> UIKit

struct PDFViewRepresentable: UIViewRepresentable {
    let pdfName: String
    let fileURL: URL?
    @Binding var containerRef: PDFContainerView?
    let isTeacherView: Bool

    func makeUIView(context: Context) -> PDFContainerView {
        let v = PDFContainerView(pdfName: pdfName, fileURL: fileURL, coordinator: context.coordinator, isTeacherView: isTeacherView)
        context.coordinator.containerView = v
        context.coordinator.pdfName = pdfName
        context.coordinator.klasse = extractKlasseFromPath(fileURL: fileURL)
        context.coordinator.fach = extractFachFromPath(fileURL: fileURL)
        DispatchQueue.main.async { containerRef = v }
        return v
    }
    
    // Extrahiere Klasse aus dem Dateipfad
    private func extractKlasseFromPath(fileURL: URL?) -> String {
        guard let fileURL = fileURL else { return "" }
        let components = fileURL.pathComponents
        // Pfad: .../Exams/{Klasse}/{Fach}/...
        if let examsIndex = components.firstIndex(of: "Exams"),
           examsIndex + 1 < components.count {
            return components[examsIndex + 1]
        }
        return ""
    }
    
    // Extrahiere Fach aus dem Dateipfad
    private func extractFachFromPath(fileURL: URL?) -> String {
        guard let fileURL = fileURL else { return "" }
        let components = fileURL.pathComponents
        // Pfad: .../Exams/{Klasse}/{Fach}/...
        if let examsIndex = components.firstIndex(of: "Exams"),
           examsIndex + 2 < components.count {
            let fachComponent = components[examsIndex + 2]
            // Entferne "Submissions" falls vorhanden (Lehrer-View)
            return fachComponent == "Submissions" ? "" : fachComponent
        }
        return ""
    }

    func updateUIView(_ uiView: PDFContainerView, context: Context) {}

    static func dismantleUIView(_ uiView: PDFContainerView, coordinator: Coordinator) {
        coordinator.saveDrawing()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        weak var containerView: PDFContainerView?
        var pdfName: String = ""
        var klasse: String = ""
        var fach: String = ""

        func saveDrawing() {
            guard let container = containerView else { return }
            // Nur speichern wenn nicht im Lehrer-Modus
            if !container.isTeacherView {
                PDFStorage.save(drawing: container.canvasView.drawing,
                               for: pdfName,
                               klasse: klasse,
                               fach: fach)
            }
        }
    }
}

// MARK: - UIKit Container

final class PDFContainerView: UIView {
    let pdfView = PDFView()
    let canvasView = PKCanvasView()

    private let pdfName: String
    private weak var coordinator: PDFViewRepresentable.Coordinator?

    private var toolPicker: PKToolPicker?
    private var scaleObs: NSObjectProtocol?

    private var fileURL: URL?
    let isTeacherView: Bool

    init(pdfName: String, fileURL: URL?, coordinator: PDFViewRepresentable.Coordinator, isTeacherView: Bool) {
        self.pdfName = pdfName
        self.fileURL = fileURL
        self.coordinator = coordinator
        self.isTeacherView = isTeacherView
        super.init(frame: .zero)

        coordinator.pdfName = pdfName

        setupPDFView()
        
        // Canvas nur für Schüler aktivieren
        if !isTeacherView {
            setupCanvasView()
            loadSavedDrawing()
        }
        
        observeScale()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: PDF einrichten

    private func setupPDFView() {
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.autoScales = true
        
        // Für Lehrer: Klarer Hintergrund damit PDF sichtbar ist
        if isTeacherView {
            pdfView.backgroundColor = .white
        } else {
            pdfView.backgroundColor = .systemGray6
        }

        let fileURLToLoad: URL
        if let fileURL = fileURL {
            fileURLToLoad = fileURL
        } else {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            fileURLToLoad = docs.appendingPathComponent(pdfName)
        }
        self.fileURL = fileURLToLoad

        print("=== setupPDFView: isTeacherView = \(isTeacherView) ===")
        print("=== setupPDFView: Trying to load: \(fileURLToLoad.path) ===")
        
        // Prüfe ob Datei existiert
        if FileManager.default.fileExists(atPath: fileURLToLoad.path) {
            print("=== setupPDFView: Datei existiert ===")
            
            if let doc = PDFDocument(url: fileURLToLoad) {
                let pageCount = doc.pageCount
                print("=== setupPDFView: PDF geladen mit \(pageCount) Seiten ===")
                
                // Teste erste Seite
                if let firstPage = doc.page(at: 0) {
                    let bounds = firstPage.bounds(for: .mediaBox)
                    print("=== setupPDFView: Erste Seite Größe: \(bounds.size) ===")
                }
                
                pdfView.document = doc
                
                // Wichtig: PDF neu rendern und anzeigen
                pdfView.goToFirstPage(nil)
                pdfView.setNeedsDisplay()
                pdfView.layoutDocumentView()
                
                // Force Layout nach kurzer Verzögerung
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.pdfView.scaleFactor = self.pdfView.scaleFactorForSizeToFit
                    self.pdfView.setNeedsDisplay()
                }
            } else {
                print("=== setupPDFView: PDF konnte nicht als PDFDocument geladen werden ===")
            }
        } else {
            print("=== setupPDFView: FEHLER - Datei existiert nicht! ===")
        }

        addSubview(pdfView)
        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: topAnchor),
            pdfView.bottomAnchor.constraint(equalTo: bottomAnchor),
            pdfView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    // MARK: Canvas einrichten

    private func setupCanvasView() {
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .pencilOnly
    }

    // MARK: View-Lifecycle

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let window else { return }

        // Canvas nur für Schüler
        if !isTeacherView {
            attachCanvas()

            if toolPicker == nil {
                toolPicker = PKToolPicker.shared(for: window)
            }
            showToolPicker()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Canvas nur für Schüler
        if !isTeacherView {
            attachCanvas()

            if window != nil {
                showToolPicker()
            }
        }
    }

    private func attachCanvas() {
        guard let documentView = pdfView.documentView else { return }

        if canvasView.superview !== documentView {
            canvasView.frame = documentView.bounds
            canvasView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            documentView.addSubview(canvasView)
        }
        canvasView.frame = documentView.bounds
    }

    private func showToolPicker() {
        guard let toolPicker else { return }

        toolPicker.addObserver(canvasView)

        DispatchQueue.main.async {
            self.canvasView.becomeFirstResponder()
            toolPicker.setVisible(true, forFirstResponder: self.canvasView)
        }
    }

    // MARK: Zoom-Beobachter

    private func observeScale() {
        scaleObs = NotificationCenter.default.addObserver(
            forName: .PDFViewScaleChanged,
            object: pdfView,
            queue: .main
        ) { [weak self] _ in
            self?.attachCanvas()
        }
    }

    // MARK: Speichern & Laden

    private func loadSavedDrawing() {
        // Extrahiere klasse/fach aus fileURL
        guard let fileURL = fileURL else { return }
        let components = fileURL.pathComponents
        
        var klasse = ""
        var fach = ""
        
        if let examsIndex = components.firstIndex(of: "Exams") {
            if examsIndex + 1 < components.count {
                klasse = components[examsIndex + 1]
            }
            if examsIndex + 2 < components.count {
                let fachComponent = components[examsIndex + 2]
                fach = fachComponent == "Submissions" ? "" : fachComponent
            }
        }
        
        if let saved = PDFStorage.load(for: pdfName, klasse: klasse, fach: fach) {
            canvasView.drawing = saved
        }
    }
    
    func saveDrawingToPDF() {
        guard let document = pdfView.document else {
            print("=== saveDrawingToPDF: Kein Dokument ===")
            return
        }
        
        let pageCount = document.pageCount
        guard pageCount > 0 else {
            print("=== saveDrawingToPDF: Keine Seiten ===")
            return
        }
        
        print("=== saveDrawingToPDF: Start mit \(pageCount) Seiten ===")
        
        // Erste Seite für Größe
        guard let firstPage = document.page(at: 0) else { return }
        let pageRect = firstPage.bounds(for: .mediaBox)
        
        // Erstelle neues PDF mit Zeichnungen
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let pdfData = renderer.pdfData { context in
            for i in 0..<pageCount {
                guard let page = document.page(at: i) else { continue }
                
                // Neue Seite beginnen
                context.beginPage()
                
                let ctx = context.cgContext
                
                // 1. Zeichne das Original-PDF
                ctx.saveGState()
                ctx.translateBy(x: 0, y: pageRect.height)
                ctx.scaleBy(x: 1, y: -1)
                if let cgPage = page.pageRef {
                    ctx.drawPDFPage(cgPage)
                }
                ctx.restoreGState()
                
                // 2. Zeichne die Canvas-Zeichnung für diese Seite
                let sliceY = CGFloat(i) * pageRect.height
                let sliceRect = CGRect(x: 0, y: sliceY,
                                      width: pageRect.width,
                                      height: pageRect.height)
                
                // WICHTIG: scale sollte UIScreen.main.scale sein
                let drawingImage = canvasView.drawing.image(from: sliceRect, scale: UIScreen.main.scale)
                drawingImage.draw(in: pageRect)
            }
        }
        
        // Speichere das neue PDF
        if let fileURL = fileURL {
            do {
                try pdfData.write(to: fileURL)
                print("=== saveDrawingToPDF: Erfolgreich gespeichert - \(pdfData.count) bytes ===")
                
                // Lade das aktualisierte PDF neu
                if let newDoc = PDFDocument(url: fileURL) {
                    pdfView.document = newDoc
                    print("=== saveDrawingToPDF: PDF neu geladen ===")
                }
            } catch {
                print("=== saveDrawingToPDF: Fehler beim Speichern: \(error) ===")
            }
        }
    }

    func addBlankPage(type: PageType) {
        let a4Size = CGSize(width: 595, height: 842) // A4 portrait in points

        let rendererFormat = UIGraphicsPDFRendererFormat()
        let rendererBounds = CGRect(origin: .zero, size: a4Size)
        let renderer = UIGraphicsPDFRenderer(bounds: rendererBounds, format: rendererFormat)

        let pdfData = renderer.pdfData { (context) in
            context.beginPage()
            
            // Zeichne je nach Typ
            switch type {
            case .blank:
                // Nichts zeichnen = leere Seite
                break
                
            case .lined:
                // Linierte Seite zeichnen
                let lineSpacing: CGFloat = 25 // Abstand zwischen Linien
                let startY: CGFloat = 50 // Start-Y Position
                let endY: CGFloat = a4Size.height - 50
                let lineColor = UIColor.lightGray
                
                context.cgContext.setStrokeColor(lineColor.cgColor)
                context.cgContext.setLineWidth(0.5)
                
                var currentY = startY
                while currentY <= endY {
                    context.cgContext.move(to: CGPoint(x: 50, y: currentY))
                    context.cgContext.addLine(to: CGPoint(x: a4Size.width - 50, y: currentY))
                    context.cgContext.strokePath()
                    currentY += lineSpacing
                }
                
            case .grid:
                // Karierte Seite zeichnen
                let gridSpacing: CGFloat = 20 // Größe der Kästchen
                let startX: CGFloat = 50
                let startY: CGFloat = 50
                let endX: CGFloat = a4Size.width - 70 // Mehr Margin rechts
                let endY: CGFloat = a4Size.height - 50
                let gridColor = UIColor.lightGray
                
                context.cgContext.setStrokeColor(gridColor.cgColor)
                context.cgContext.setLineWidth(0.5)
                
                // Vertikale Linien
                var currentX = startX
                while currentX <= endX {
                    context.cgContext.move(to: CGPoint(x: currentX, y: startY))
                    context.cgContext.addLine(to: CGPoint(x: currentX, y: endY))
                    context.cgContext.strokePath()
                    currentX += gridSpacing
                }
                
                // Horizontale Linien
                var currentY = startY
                while currentY <= endY {
                    context.cgContext.move(to: CGPoint(x: startX, y: currentY))
                    context.cgContext.addLine(to: CGPoint(x: endX, y: currentY))
                    context.cgContext.strokePath()
                    currentY += gridSpacing
                }
            }
        }

        guard let newPageDoc = PDFDocument(data: pdfData),
              let newPage = newPageDoc.page(at: 0) else {
            print("=== Failed to create PDF page ===")
            return
        }

        if let document = pdfView.document {
            let pageCount = document.pageCount
            document.insert(newPage, at: pageCount)
        } else {
            let newDoc = PDFDocument()
            newDoc.insert(newPage, at: 0)
            pdfView.document = newDoc
        }

        // Save updated PDF document
        if let fileURL = fileURL,
           let data = pdfView.document?.dataRepresentation() {
            do {
                try data.write(to: fileURL)
                print("=== PDF mit neuer Seite gespeichert: \(fileURL.path) ===")
                
                // WICHTIG: Canvas neu attachieren damit er über allen Seiten liegt
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.attachCanvas()
                }
            } catch {
                print("=== Fehler beim Speichern der PDF: \(error) ===")
            }
        }
    }

    deinit {
        if let scaleObs { NotificationCenter.default.removeObserver(scaleObs) }
        if !isTeacherView {
            if let toolPicker { toolPicker.removeObserver(canvasView) }
            coordinator?.saveDrawing()
        }
    }
}
