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

        PDFViewRepresentable(pdfName: pdfName, fileURL: nestedFileURL, containerRef: $containerView)
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
                Button("Abbrechen", role: .cancel) {}
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
            }
            
            submitSuccess = success
            showSubmitResult = true
            isSubmitting = false
        }
    }

    private func addBlankPage(type: PageType) {
        containerView?.addBlankPage(type: type)
    }

    /// "Max Mustermann" -> "Mustermann_Max.pdf"
    /// "Mustermann, Max" -> "Mustermann_Max.pdf"
    private func formatStudentFilename(_ name: String) -> String {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "Unbekannt.pdf" }

        let parts: [String]
        if cleaned.contains(",") {
            // "Mustermann, Max" -> ["Mustermann", "Max"]
            parts = cleaned.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        } else {
            // "Max Mustermann" -> ["Mustermann", "Max"]
            let words = cleaned.split(separator: " ").map(String.init)
            if words.count >= 2 {
                let vorname = words.dropLast().joined(separator: " ")
                let nachname = words.last!
                parts = [nachname, vorname]
            } else {
                parts = words
            }
        }

        let filename = parts.joined(separator: "_")
            .replacingOccurrences(of: " ", with: "_")
        return filename + ".pdf"
    }
}

// MARK: - Brücke: SwiftUI <-> UIKit

struct PDFViewRepresentable: UIViewRepresentable {
    let pdfName: String
    let fileURL: URL?
    @Binding var containerRef: PDFContainerView?

    func makeUIView(context: Context) -> PDFContainerView {
        let v = PDFContainerView(pdfName: pdfName, fileURL: fileURL, coordinator: context.coordinator)
        context.coordinator.containerView = v
        DispatchQueue.main.async { containerRef = v }
        return v
    }

    func updateUIView(_ uiView: PDFContainerView, context: Context) {}

    static func dismantleUIView(_ uiView: PDFContainerView, coordinator: Coordinator) {
        coordinator.saveDrawing()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        weak var containerView: PDFContainerView?
        var pdfName: String = ""

        func saveDrawing() {
            guard let container = containerView else { return }
            PDFStorage.save(drawing: container.canvasView.drawing, for: pdfName)
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

    init(pdfName: String, fileURL: URL?, coordinator: PDFViewRepresentable.Coordinator) {
        self.pdfName = pdfName
        self.fileURL = fileURL
        self.coordinator = coordinator
        super.init(frame: .zero)

        coordinator.pdfName = pdfName

        setupPDFView()
        setupCanvasView()
        loadSavedDrawing()
        observeScale()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: PDF einrichten

    private func setupPDFView() {
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.autoScales = true
        pdfView.backgroundColor = .systemGray6

        let fileURLToLoad: URL
        if let fileURL = fileURL {
            fileURLToLoad = fileURL
        } else {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            fileURLToLoad = docs.appendingPathComponent(pdfName)
        }
        self.fileURL = fileURLToLoad

        if let doc = PDFDocument(url: fileURLToLoad) {
            pdfView.document = doc
            print("=== PDF geladen: \(fileURLToLoad.path) ===")
        } else {
            print("=== PDF nicht gefunden: \(fileURLToLoad.path) ===")
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

        attachCanvas()

        if toolPicker == nil {
            toolPicker = PKToolPicker.shared(for: window)
        }
        showToolPicker()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        attachCanvas()

        if window != nil {
            showToolPicker()
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
        if let saved = PDFStorage.load(for: pdfName) {
            canvasView.drawing = saved
        }
    }
    
    func saveDrawingToPDF() {
        // Zeichnung in die PDF einbrennen
        guard let document = pdfView.document else { return }
        
        let pageCount = document.pageCount
        guard pageCount > 0 else { return }
        
        // Für jede Seite die Zeichnung hinzufügen
        for i in 0..<pageCount {
            guard let page = document.page(at: i) else { continue }
            let pageRect = page.bounds(for: .mediaBox)
            
            // Zeichnung für diese Seite extrahieren
            let sliceY = CGFloat(i) * pageRect.height
            let sliceRect = CGRect(x: 0, y: sliceY, width: pageRect.width, height: pageRect.height)
            let drawingImage = canvasView.drawing.image(from: sliceRect, scale: UIScreen.main.scale)
            
            // Neue Seite mit Zeichnung erstellen
            let renderer = UIGraphicsImageRenderer(size: pageRect.size)
            let imageWithDrawing = renderer.image { context in
                // Erst das PDF
                context.cgContext.saveGState()
                context.cgContext.translateBy(x: 0, y: pageRect.height)
                context.cgContext.scaleBy(x: 1, y: -1)
                if let cgPage = page.pageRef {
                    context.cgContext.drawPDFPage(cgPage)
                }
                context.cgContext.restoreGState()
                
                // Dann die Zeichnung
                drawingImage.draw(in: pageRect)
            }
            
            // Konvertiere zu PDF-Seite
            if let pdfPage = PDFPage(image: imageWithDrawing) {
                document.removePage(at: i)
                document.insert(pdfPage, at: i)
            }
        }
        
        // Speichere das aktualisierte PDF
        if let fileURL = fileURL, let data = document.dataRepresentation() {
            try? data.write(to: fileURL)
            print("=== PDF mit Zeichnungen gespeichert ===")
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
                let endX: CGFloat = a4Size.width - 50
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
            } catch {
                print("=== Fehler beim Speichern der PDF: \(error) ===")
            }
        }
    }

    deinit {
        if let scaleObs { NotificationCenter.default.removeObserver(scaleObs) }
        if let toolPicker { toolPicker.removeObserver(canvasView) }
        coordinator?.saveDrawing()
    }
}
