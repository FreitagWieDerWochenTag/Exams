// PDFViewerView.swift
// Zeigt ein PDF an mit einer Zeichenfläche darüber.
//
// ANSATZ:
// Der PKCanvasView liegt ALS SUBVIEW im documentView des PDFView.
// So scrollt/zoomt er automatisch mit dem PDF mit.
//
// Der PKToolPicker wird an den canvasView gebunden.
// Damit er sichtbar bleibt, muss der canvasView FirstResponder sein
// UND der ToolPicker muss als eigene Instanz (nicht shared) gehalten werden.

import SwiftUI
import PDFKit
import PencilKit

// MARK: - SwiftUI Wrapper

struct PDFViewerView: View {
    let pdfName: String

    var body: some View {
        PDFCanvas(pdfName: pdfName)
            .navigationTitle(pdfName)
            .navigationBarTitleDisplayMode(.inline)
            .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Brücke: SwiftUI ↔ UIKit

struct PDFCanvas: UIViewRepresentable {
    let pdfName: String

    func makeUIView(context: Context) -> PDFContainerView {
        PDFContainerView(pdfName: pdfName)
    }

    func updateUIView(_ uiView: PDFContainerView, context: Context) {}

    static func dismantleUIView(_ uiView: PDFContainerView, coordinator: ()) {
        uiView.saveDrawing()
    }
}

// MARK: - Container View

final class PDFContainerView: UIView {

    private let pdfView = PDFView()
    let canvasView = PKCanvasView()
    private let pdfName: String

    // ToolPicker muss ans UIWindow gebunden sein UND als Property gehalten werden.
    private var toolPicker: PKToolPicker?

    init(pdfName: String) {
        self.pdfName = pdfName
        super.init(frame: .zero)

        setupPDF()
        setupCanvas()
        loadSavedDrawing()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: PDF einrichten

    private func setupPDF() {
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.autoScales = true
        pdfView.backgroundColor = .systemGray6

        if let url = Bundle.main.url(forResource: pdfName, withExtension: "pdf") {
            pdfView.document = PDFDocument(url: url)
        }

        pdfView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pdfView)
        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: topAnchor),
            pdfView.bottomAnchor.constraint(equalTo: bottomAnchor),
            pdfView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    // MARK: Canvas einrichten

    private func setupCanvas() {
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .pencilOnly
        // Eigenes Scrollen AUS – das PDFView übernimmt Scrollen/Zoomen
        canvasView.isScrollEnabled = false
    }

    // MARK: View-Lifecycle

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let window else { return }

        attachCanvas()
        toolPicker = PKToolPicker.shared(for: window)
        showToolPicker()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        attachCanvas()
    }

    private func attachCanvas() {
        guard let documentView = pdfView.documentView else { return }

        if canvasView.superview != documentView {
            documentView.addSubview(canvasView)
        }
        canvasView.frame = documentView.bounds
    }

    /// ToolPicker anzeigen – die "Island" mit Stift/Radierer/Farben.
    private func showToolPicker() {
        guard let toolPicker else { return }

        toolPicker.addObserver(canvasView)

        // Nächster Runloop: SwiftUI hat manchmal den FirstResponder noch nicht bereit
        DispatchQueue.main.async {
            self.canvasView.becomeFirstResponder()
            toolPicker.setVisible(true, forFirstResponder: self.canvasView)
        }
    }

    // MARK: Speichern & Laden

    func saveDrawing() {
        PDFStorage.save(drawing: canvasView.drawing, for: pdfName)
    }

    private func loadSavedDrawing() {
        if let saved = PDFStorage.load(for: pdfName) {
            canvasView.drawing = saved
        }
    }
}
