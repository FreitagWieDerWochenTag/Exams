import SwiftUI
import PDFKit
import PencilKit

// MARK: - SwiftUI View

struct PDFViewerView: View {
    let group: String
    let pdfName: String

    @State private var containerView: PDFContainerView?
    @Environment(\.dismiss) private var dismiss

    @State private var showExitConfirm = false
    @State private var isSubmitting = false
    @State private var showSubmitResult = false
    @State private var submitSuccess = false

    var body: some View {
        PDFViewRepresentable(pdfName: pdfName, containerRef: $containerView)
            .navigationTitle(pdfName)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)

            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showExitConfirm = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("Test beenden")
                        }
                    }
                    .disabled(isSubmitting)
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

    private func submitAndClose() {
        isSubmitting = true

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = docs.appendingPathComponent(pdfName)

        guard let data = try? Data(contentsOf: fileURL) else {
            submitSuccess = false
            showSubmitResult = true
            isSubmitting = false
            return
        }

        RPiService.shared.submitTest(group: group,
                                     filename: pdfName,
                                     pdfData: data) { success in
            submitSuccess = success
            showSubmitResult = true
            isSubmitting = false
        }
    }
}

// MARK: - Bruecke: SwiftUI <-> UIKit

struct PDFViewRepresentable: UIViewRepresentable {
    let pdfName: String
    @Binding var containerRef: PDFContainerView?

    func makeUIView(context: Context) -> PDFContainerView {
        let v = PDFContainerView(pdfName: pdfName, coordinator: context.coordinator)
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

    init(pdfName: String, coordinator: PDFViewRepresentable.Coordinator) {
        self.pdfName = pdfName
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

        // PDF aus Documents-Ordner laden (heruntergeladen vom Server)
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = docs.appendingPathComponent(pdfName)

        if let doc = PDFDocument(url: fileURL) {
            pdfView.document = doc
            print("=== PDF geladen: \(fileURL.path) ===")
        } else {
            print("=== PDF nicht gefunden: \(fileURL.path) ===")
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

    deinit {
        if let scaleObs { NotificationCenter.default.removeObserver(scaleObs) }
        if let toolPicker { toolPicker.removeObserver(canvasView) }
        coordinator?.saveDrawing()
    }
}
