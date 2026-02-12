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
    
    @State private var exportURL: URL?
    @State private var showExporter = false
    
    @State private var teacherPageImages: [UIImage] = []

    var body: some View {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let nestedFileURL = buildFileURL(docs: docs)

        ZStack {
            PDFViewRepresentable(pdfName: pdfName, fileURL: nestedFileURL, containerRef: $containerView, isTeacherView: isTeacherView)
                .opacity(isTeacherView && !teacherPageImages.isEmpty ? 0 : 1)

            if isTeacherView && !teacherPageImages.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(teacherPageImages.enumerated()), id: \.offset) { _, img in
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .shadow(radius: 1)
                                .padding(.horizontal)
                        }
                    }.padding(.vertical)
                }
            }
        }
        .onAppear {
            if isTeacherView {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    if let images = containerView?.renderDisplayImages() {
                        self.teacherPageImages = images
                        print("=== TeacherImageView: Rendered \(images.count) pages as images ===")
                    } else {
                        print("=== TeacherImageView: Failed to render images ===")
                    }
                }
            }
        }
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
                        Button { addBlankPage(type: .blank) } label: {
                            Label("Leere Seite", systemImage: "doc")
                        }
                        Button { addBlankPage(type: .lined) } label: {
                            Label("Linierte Seite", systemImage: "text.alignleft")
                        }
                        Button { addBlankPage(type: .grid) } label: {
                            Label("Karierte Seite", systemImage: "squareshape.split.3x3")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(isSubmitting)
                }
            }

            if isTeacherView {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exportCurrentPDF()
                    } label: {
                        Label("Abgabe exportieren", systemImage: "square.and.arrow.down")
                    }
                    .disabled(isSubmitting)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        reloadTeacher()
                    } label: {
                        Label("Neu laden", systemImage: "arrow.clockwise")
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
        .sheet(isPresented: $showExporter) {
            if let exportURL {
                ShareSheet(activityItems: [exportURL])
                    .ignoresSafeArea()
            }
        }
    }

    private func buildFileURL(docs: URL) -> URL {
        if isTeacherView {
            return docs.appendingPathComponent("Exams")
                .appendingPathComponent(klasse)
                .appendingPathComponent(fach)
                .appendingPathComponent("Submissions")
                .appendingPathComponent(pdfName)
        } else {
            return docs.appendingPathComponent("Exams")
                .appendingPathComponent(klasse)
                .appendingPathComponent(fach)
                .appendingPathComponent(pdfName)
        }
    }

    private func submitAndClose() {
        isSubmitting = true

        // Zeichnung ins PDF brennen
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
        print("=== Submit: Datei-Größe: \(data.count) Bytes, Pfad: \(fileURL.path) ===")

        let studentFilename = formatStudentFilename(studentName)

        RPiService.shared.submitTest(klasse: klasse,
                                     fach: fach,
                                     filename: pdfName,
                                     studentFilename: studentFilename,
                                     pdfData: data) { success in
            if success {
                UserDefaults.standard.set(true, forKey: "submitted_\(klasse)_\(fach)_\(pdfName)")
                PDFStorage.delete(for: pdfName, klasse: klasse, fach: fach)
            }

            submitSuccess = success
            showSubmitResult = true
            isSubmitting = false
        }
    }
    
    private func exportCurrentPDF() {
        // Versuche, die aktuell relevante Datei zu exportieren (je nach Ansicht)
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let urlToExport: URL
        if isTeacherView {
            urlToExport = docs.appendingPathComponent("Exams")
                .appendingPathComponent(klasse)
                .appendingPathComponent(fach)
                .appendingPathComponent("Submissions")
                .appendingPathComponent(pdfName)
        } else {
            urlToExport = docs.appendingPathComponent("Exams")
                .appendingPathComponent(klasse)
                .appendingPathComponent(fach)
                .appendingPathComponent(pdfName)
        }

        guard FileManager.default.fileExists(atPath: urlToExport.path) else {
            print("=== Export: Datei existiert nicht: \(urlToExport.path) ===")
            return
        }
        exportURL = urlToExport
        showExporter = true
    }
    
    private func reloadTeacher() {
        guard isTeacherView else { return }
        containerView?.reloadTeacherDocument()
    }

    private func addBlankPage(type: PageType) {
        containerView?.addBlankPage(type: type)
    }

    private func formatStudentFilename(_ name: String) -> String {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "Unbekannt.pdf" }

        var vorname = ""
        var nachname = ""

        if cleaned.contains(",") {
            let parts = cleaned.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count >= 2 {
                nachname = parts[0]
                vorname = parts[1]
            } else if parts.count == 1 {
                nachname = parts[0]
            }
        } else {
            let words = cleaned.split(separator: " ").map(String.init)
            if words.count >= 2 {
                vorname = words.dropLast().joined(separator: " ")
                nachname = words.last!
            } else if words.count == 1 {
                vorname = words[0]
            }
        }

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

    private func extractKlasseFromPath(fileURL: URL?) -> String {
        guard let fileURL = fileURL else { return "" }
        let components = fileURL.pathComponents
        if let examsIndex = components.firstIndex(of: "Exams"),
           examsIndex + 1 < components.count {
            return components[examsIndex + 1]
        }
        return ""
    }

    private func extractFachFromPath(fileURL: URL?) -> String {
        guard let fileURL = fileURL else { return "" }
        let components = fileURL.pathComponents
        if let examsIndex = components.firstIndex(of: "Exams"),
           examsIndex + 2 < components.count {
            let fachComponent = components[examsIndex + 2]
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

        // Wichtig: immer weiß für PDFKit-Transparenz-Fälle
        pdfView.backgroundColor = .white

        let fileURLToLoad: URL
        if let fileURL = fileURL {
            fileURLToLoad = fileURL
        } else {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            fileURLToLoad = docs.appendingPathComponent(pdfName)
        }
        self.fileURL = fileURLToLoad

        var urlToOpen = fileURLToLoad
        if isTeacherView {
            if let displayURL = prepareDisplayCopyIfNeeded(from: fileURLToLoad) {
                urlToOpen = displayURL
                print("=== setupPDFView: Using display copy at: \(displayURL.path) ===")
            } else {
                print("=== setupPDFView: Display copy not created, falling back to original ===")
            }
        }

        if FileManager.default.fileExists(atPath: urlToOpen.path),
           let doc = PDFDocument(url: urlToOpen) {
            pdfView.document = doc

            print("=== setupPDFView: Geladen: \(doc.pageCount) Seiten von \(urlToOpen.path) ===")

            if isTeacherView {
                if let first = doc.page(at: 0) {
                    let rect = first.bounds(for: .mediaBox)
                    let rotation = first.rotation
                    print("=== setupPDFView: First page rect: \(rect), rotation: \(rotation) ===")
                    print("=== setupPDFView: pageRef exists: \(first.pageRef != nil) ===")
                }
                // Anzeige-Flags härten
                pdfView.displaysPageBreaks = false
                pdfView.displaysAsBook = false
                
                if let docView = pdfView.documentView {
                    docView.layer.allowsEdgeAntialiasing = true
                    docView.layer.rasterizationScale = UIScreen.main.scale
                }
            }

            refreshTeacherDisplayIfNeeded(context: "setupPDFView")

            pdfView.backgroundColor = .white
            pdfView.documentView?.backgroundColor = .white
            pdfView.documentView?.isOpaque = true

            pdfView.goToFirstPage(nil)
            pdfView.layoutDocumentView()

            // Zoom-Jiggle erzwingen, um Redraw zu triggern
            if isTeacherView {
                let currentScale = pdfView.scaleFactor
                let minScale = pdfView.minScaleFactor
                let maxScale = pdfView.maxScaleFactor
                print("=== RefreshTeacherDisplay [setupPDFView] scales: current=\(currentScale) min=\(minScale) max=\(maxScale) ===")
                let jiggle = max(min(currentScale * 0.9999, maxScale), minScale)
                pdfView.scaleFactor = jiggle
                pdfView.scaleFactor = currentScale

                // Flags sicher setzen
                pdfView.displaysPageBreaks = false
                pdfView.displaysAsBook = false
                
                if let docView = pdfView.documentView {
                    docView.layer.allowsEdgeAntialiasing = true
                    docView.layer.rasterizationScale = UIScreen.main.scale
                }
            }

            print("=== setupPDFView: layoutDocumentView() done ===")
        } else {
            print("=== setupPDFView: FEHLER - Datei existiert nicht oder kann nicht geladen werden ===")
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

        if !isTeacherView {
            attachCanvas()
            if toolPicker == nil {
                toolPicker = PKToolPicker.shared(for: window)
            }
            showToolPicker()
        } else {
            // Lehrer: sicherstellen dass auch documentView weiß ist
            DispatchQueue.main.async { [weak self] in
                self?.pdfView.documentView?.backgroundColor = .white
                self?.refreshTeacherDisplayIfNeeded(context: "didMoveToWindow")
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if !isTeacherView {
            attachCanvas()
            if window != nil {
                showToolPicker()
            }
        } else {
            pdfView.documentView?.backgroundColor = .white
            refreshTeacherDisplayIfNeeded(context: "layoutSubviews")
        }
    }

    private func attachCanvas() {
        guard let documentView = pdfView.documentView else { return }

        // Hintergrund vom PDF documentView weiß halten (wichtig bei transparenten Seiten)
        documentView.backgroundColor = .white
        documentView.isOpaque = true
        documentView.bringSubviewToFront(canvasView)

        if canvasView.superview !== documentView {
            canvasView.frame = documentView.bounds
            canvasView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            documentView.addSubview(canvasView)
        }

        canvasView.frame = documentView.bounds

        // 🔥 KRITISCH: Canvas immer nach vorne
        documentView.bringSubviewToFront(canvasView)
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
        guard let fileURL = fileURL else { return }
        let components = fileURL.pathComponents

        var klasse = ""
        var fach = ""

        if let examsIndex = components.firstIndex(of: "Exams") {
            if examsIndex + 1 < components.count { klasse = components[examsIndex + 1] }
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

        // Render jede Seite mit ihren eigenen Bounds
        let format = UIGraphicsPDFRendererFormat()
        var combinedData = Data()

        for i in 0..<pageCount {
            guard let page = document.page(at: i) else { continue }
            let pageRect = page.bounds(for: .mediaBox)
            let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
            let pageData = renderer.pdfData { context in
                context.beginPage()
                let ctx = context.cgContext

                // Hintergrund Weiß füllen (wichtig bei transparenten Seiten)
                ctx.setFillColor(UIColor.white.cgColor)
                ctx.fill(pageRect)

                // 1) Original PDF-Seite zeichnen
                ctx.saveGState()
                ctx.translateBy(x: 0, y: pageRect.height)
                ctx.scaleBy(x: 1, y: -1)
                if let cgPage = page.pageRef {
                    ctx.drawPDFPage(cgPage)
                }
                ctx.restoreGState()

                // 2) Zeichnung für diese Seite
                // Versuche, einen Slice basierend auf der angenommenen Seitenhöhe zu nehmen.
                // Falls das leer wirkt, fallback: skaliere die gesamte Zeichnung auf die Seite.
                let assumedPageHeight = pageRect.height
                let sliceY = CGFloat(i) * assumedPageHeight
                let sliceRect = CGRect(x: 0, y: sliceY, width: pageRect.width, height: pageRect.height)

                let scale = max(UIScreen.main.scale, 1.0)
                let drawingImage = canvasView.drawing.image(from: sliceRect, scale: scale)

                if drawingImage.size.width > 1, drawingImage.size.height > 1 {
                    // Normalfall: Slice gezeichnet
                    drawingImage.draw(in: pageRect)
                } else {
                    // Fallback: komplette Zeichnung proportional auf Seite zeichnen
                    let fullImage = canvasView.drawing.image(from: CGRect(origin: .zero, size: canvasView.bounds.size), scale: scale)
                    if fullImage.size.width > 1, fullImage.size.height > 1 {
                        // Inhalt proportional einpassen
                        let imgSize = fullImage.size
                        let sx = pageRect.width / imgSize.width
                        let sy = pageRect.height / imgSize.height
                        let s = min(sx, sy)
                        let drawSize = CGSize(width: imgSize.width * s, height: imgSize.height * s)
                        let drawOrigin = CGPoint(x: pageRect.midX - drawSize.width/2, y: pageRect.midY - drawSize.height/2)
                        let drawRect = CGRect(origin: drawOrigin, size: drawSize)
                        fullImage.draw(in: drawRect)
                    }
                }
            }
            combinedData.append(pageData)
        }

        // Schreibe zusammengeführtes PDF an fileURL und lade neu in PDFView
        if let fileURL = fileURL {
            do {
                try combinedData.write(to: fileURL)
                if let newDoc = PDFDocument(url: fileURL) {
                    print("=== saveDrawingToPDF: Gespeichert: \(newDoc.pageCount) Seiten, URL: \(fileURL.path) ===")
                    pdfView.document = newDoc
                    pdfView.goToFirstPage(nil)
                    pdfView.layoutDocumentView()
                } else {
                    print("=== saveDrawingToPDF: Konnte gespeichertes Dokument nicht neu laden ===")
                }
                // Canvas sicher wieder oben drüber
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.attachCanvas()
                }
            } catch {
                print("=== saveDrawingToPDF: Fehler beim Speichern: \(error) ===")
            }
        } else {
            print("=== saveDrawingToPDF: Keine fileURL vorhanden ===")
        }
    }

    func addBlankPage(type: PageType) {
        let a4Size = CGSize(width: 595, height: 842) // A4 portrait in points

        let rendererBounds = CGRect(origin: .zero, size: a4Size)
        let renderer = UIGraphicsPDFRenderer(bounds: rendererBounds)

        let pdfData = renderer.pdfData { context in
            context.beginPage()

            // 🔥 KRITISCH: Hintergrund IMMER weiß füllen (sonst transparent -> schwarz)
            context.cgContext.setFillColor(UIColor.white.cgColor)
            context.cgContext.fill(rendererBounds)

            switch type {
            case .blank:
                break

            case .lined:
                let lineSpacing: CGFloat = 25
                let startY: CGFloat = 50
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
                let gridSpacing: CGFloat = 20
                let startX: CGFloat = 50
                let startY: CGFloat = 50
                let endX: CGFloat = a4Size.width - 70
                let endY: CGFloat = a4Size.height - 50
                let gridColor = UIColor.lightGray

                context.cgContext.setStrokeColor(gridColor.cgColor)
                context.cgContext.setLineWidth(0.5)

                var currentX = startX
                while currentX <= endX {
                    context.cgContext.move(to: CGPoint(x: currentX, y: startY))
                    context.cgContext.addLine(to: CGPoint(x: currentX, y: endY))
                    context.cgContext.strokePath()
                    currentX += gridSpacing
                }

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
            document.insert(newPage, at: document.pageCount)
        } else {
            let newDoc = PDFDocument()
            newDoc.insert(newPage, at: 0)
            pdfView.document = newDoc
        }

        // Speichern
        if let fileURL = fileURL, let data = pdfView.document?.dataRepresentation() {
            do {
                try data.write(to: fileURL)
                // 🔥 Nach Insert: Canvas wieder sicher nach vorne
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.attachCanvas()
                }
            } catch {
                print("=== Fehler beim Speichern der PDF: \(error) ===")
            }
        }
    }
    
    func reloadTeacherDocument() {
        guard isTeacherView else { return }
        guard let currentURL = self.fileURL else {
            print("=== reloadTeacherDocument: Keine fileURL vorhanden ===")
            return
        }
        print("=== reloadTeacherDocument: Start mit URL: \(currentURL.path) ===")

        var urlToOpen = currentURL
        if let displayURL = prepareDisplayCopyIfNeeded(from: currentURL) {
            urlToOpen = displayURL
            print("=== reloadTeacherDocument: Using display copy at: \(displayURL.path) ===")
        }

        guard FileManager.default.fileExists(atPath: urlToOpen.path) else {
            print("=== reloadTeacherDocument: Datei existiert nicht: \(urlToOpen.path) ===")
            return
        }
        guard let doc = PDFDocument(url: urlToOpen) else {
            print("=== reloadTeacherDocument: Konnte Dokument nicht laden ===")
            return
        }

        pdfView.document = doc
        pdfView.goToFirstPage(nil)
        pdfView.layoutDocumentView()
        refreshTeacherDisplayIfNeeded(context: "reloadTeacherDocument")
    }

    deinit {
        if let scaleObs { NotificationCenter.default.removeObserver(scaleObs) }
        if !isTeacherView {
            if let toolPicker { toolPicker.removeObserver(canvasView) }
            coordinator?.saveDrawing()
        }
    }
    
    // MARK: - Helper to refresh teacher display
    
    private func refreshTeacherDisplayIfNeeded(context: String) {
        guard isTeacherView else { return }
        print("=== RefreshTeacherDisplay [\(context)] ===")

        // Sicherstellen, dass Hintergründe korrekt gesetzt sind
        pdfView.backgroundColor = .white
        pdfView.documentView?.backgroundColor = .white
        pdfView.documentView?.isOpaque = true

        // Re-Layout forcieren
        let oldAutoScales = pdfView.autoScales
        pdfView.autoScales = false
        pdfView.autoScales = oldAutoScales

        pdfView.goToFirstPage(nil)
        pdfView.layoutDocumentView()

        // Zoom-Jiggle erzwingen, um Redraw zu triggern
        let currentScale = pdfView.scaleFactor
        let minScale = pdfView.minScaleFactor
        let maxScale = pdfView.maxScaleFactor
        print("=== RefreshTeacherDisplay [\(context)] scales: current=\(currentScale) min=\(minScale) max=\(maxScale) ===")
        let jiggle = max(min(currentScale * 0.9999, maxScale), minScale)
        pdfView.scaleFactor = jiggle
        pdfView.scaleFactor = currentScale

        // Flags sicher setzen
        pdfView.displaysPageBreaks = false
        pdfView.displaysAsBook = false
        
        if let docView = pdfView.documentView {
            docView.layer.allowsEdgeAntialiasing = true
            docView.layer.rasterizationScale = UIScreen.main.scale
        }

        // Kurz verzögert nochmals die wichtigen Eigenschaften setzen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            print("=== RefreshTeacherDisplay [\(context)] delayed apply ===")
            self.pdfView.backgroundColor = .white
            self.pdfView.documentView?.backgroundColor = .white
            self.pdfView.documentView?.isOpaque = true

            // Flags erneut sicher setzen
            self.pdfView.displaysPageBreaks = false
            self.pdfView.displaysAsBook = false
            
            if let docView = self.pdfView.documentView {
                docView.layer.allowsEdgeAntialiasing = true
                docView.layer.rasterizationScale = UIScreen.main.scale
            }

            // Zweiter Zoom-Jiggle nach Delay
            let current = self.pdfView.scaleFactor
            let jiggle2 = max(min(current * 0.9999, self.pdfView.maxScaleFactor), self.pdfView.minScaleFactor)
            self.pdfView.scaleFactor = jiggle2
            self.pdfView.scaleFactor = current

            self.pdfView.layoutDocumentView()
        }
    }

    // MARK: - Helper to create flattened display copy for teacher view
    
    private func prepareDisplayCopyIfNeeded(from originalURL: URL) -> URL? {
        // Erzeuge eine flache Anzeige-Kopie nur in der Lehreransicht
        guard isTeacherView else { return nil }
        guard let originalDoc = PDFDocument(url: originalURL) else {
            print("=== prepareDisplayCopy: Konnte Original nicht laden ===")
            return nil
        }
        let pageCount = originalDoc.pageCount
        guard pageCount > 0 else {
            print("=== prepareDisplayCopy: Keine Seiten ===")
            return nil
        }

        // Zielpfad: .../Submissions/.display/<name>.display.pdf
        let originalDir = originalURL.deletingLastPathComponent()
        let displayDir = originalDir.appendingPathComponent(".display", isDirectory: true)
        do { try FileManager.default.createDirectory(at: displayDir, withIntermediateDirectories: true) } catch {
            print("=== prepareDisplayCopy: Konnte display-Verzeichnis nicht anlegen: \(error) ===")
        }
        let baseName = originalURL.deletingPathExtension().lastPathComponent
        let displayURL = displayDir.appendingPathComponent("\(baseName).display.pdf")

        // Rendern
        var combinedData = Data()
        for i in 0..<pageCount {
            guard let page = originalDoc.page(at: i) else { continue }
            let pageRect = page.bounds(for: .mediaBox)
            let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
            let pageData = renderer.pdfData { context in
                context.beginPage()
                let ctx = context.cgContext
                ctx.setFillColor(UIColor.white.cgColor)
                ctx.fill(pageRect)
                ctx.saveGState()
                ctx.translateBy(x: 0, y: pageRect.height)
                ctx.scaleBy(x: 1, y: -1)
                if let cgPage = page.pageRef {
                    ctx.drawPDFPage(cgPage)
                }
                ctx.restoreGState()
            }
            combinedData.append(pageData)
        }

        do {
            try combinedData.write(to: displayURL)
            print("=== prepareDisplayCopy: Display-PDF gespeichert: \(displayURL.path) ===")
            return displayURL
        } catch {
            print("=== prepareDisplayCopy: Fehler beim Speichern: \(error) ===")
            return nil
        }
    }
    
    // MARK: - New method to render display PDF pages into images for teacher view
    
    func renderDisplayImages() -> [UIImage]? {
        // Nur Lehreransicht nutzt dies
        guard isTeacherView else { return nil }
        // Nutze bevorzugt die Display-Kopie, ansonsten aktuelle URL
        guard let baseURL = self.fileURL else { return nil }
        let urlToOpen = prepareDisplayCopyIfNeeded(from: baseURL) ?? baseURL
        guard let doc = PDFDocument(url: urlToOpen) else { return nil }

        var images: [UIImage] = []
        let pageCount = doc.pageCount
        for i in 0..<pageCount {
            guard let page = doc.page(at: i) else { continue }
            let rect = page.bounds(for: .mediaBox)
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = UIScreen.main.scale
            let renderer = UIGraphicsImageRenderer(size: rect.size, format: format)
            let image = renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: rect.size))
                let cg = ctx.cgContext
                cg.saveGState()
                cg.translateBy(x: 0, y: rect.height)
                cg.scaleBy(x: 1, y: -1)
                if let cgPage = page.pageRef {
                    cg.drawPDFPage(cgPage)
                }
                cg.restoreGState()
            }
            images.append(image)
        }
        return images
    }
}
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

