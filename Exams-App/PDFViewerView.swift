// PDFViewerView.swift
// Zeigt ein PDF an mit einer Zeichenflaeche (PKCanvasView) darueber.
// Oben rechts gibt es einen "Abgeben"-Button der das PDF mit Zeichnungen exportiert.
//
// Architektur:
//   SwiftUI:  PDFViewerView  ->  PDFViewRepresentable (Bruecke)
//   UIKit:    PDFContainerView  ->  PDFView + PKCanvasView

import SwiftUI
import PDFKit
import PencilKit

// MARK: - SwiftUI View

struct PDFViewerView: View {
    let pdfName: String

    // Referenz auf den UIKit-Container, damit wir an die Zeichnung kommen
    @State private var containerView: PDFContainerView?
    @State private var exportedURL: URL?
    @State private var showShareSheet = false

    var body: some View {
        PDFViewRepresentable(pdfName: pdfName, containerRef: $containerView)
            .navigationTitle(pdfName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exportAndShare()
                    } label: {
                        Label("Abgeben", systemImage: "paperplane.fill")
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportedURL {
                    ShareSheet(url: url)
                }
            }
    }

    private func exportAndShare() {
        guard let container = containerView else { return }
        let drawing = container.canvasView.drawing

        if let url = PDFExporter.export(pdfName: pdfName, drawing: drawing) {
            exportedURL = url
            showShareSheet = true
        }
    }
}

// MARK: - Share Sheet

/// Zeigt den System-Dialog zum Teilen/Speichern (AirDrop, Mail, Dateien, ...).
/// Wir nutzen UIActivityViewController direkt als UIKit-Controller,
/// weil SwiftUI's ShareLink mit temporaeren Dateien nicht gut funktioniert.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        // Die URL muss als NSURL uebergeben werden, damit der Share-Sheet
        // sie als Datei erkennt und Vorschau/AirDrop/Speichern anbietet.
        let controller = UIActivityViewController(
            activityItems: [url as NSURL],
            applicationActivities: nil
        )
        // Auf dem iPad muss der Popover-Anchor gesetzt werden,
        // sonst crasht die App. sourceView wird spaeter automatisch gesetzt.
        controller.popoverPresentationController?.permittedArrowDirections = .any
        return controller
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
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

        if let url = Bundle.main.url(forResource: pdfName, withExtension: "pdf"),
           let doc = PDFDocument(url: url) {
            pdfView.document = doc
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
        canvasView.drawingPolicy = .pencilOnly   // Nur Apple Pencil zeichnet, Finger scrollen
    }

    // MARK: View-Lifecycle

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let window else { return }

        attachCanvas()

        // ToolPicker ans aktuelle Window binden
        if toolPicker == nil {
            toolPicker = PKToolPicker.shared(for: window)
        }
        showToolPicker()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        attachCanvas()

        // Falls SwiftUI/Rotation den FirstResponder "klaut": ToolPicker wieder zeigen
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

        // Naechster Runloop: SwiftUI hat manchmal den FirstResponder noch nicht bereit
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
