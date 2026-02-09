// PDFViewerView.swift
// Zeigt ein PDF an und legt eine durchsichtige Zeichenfläche (PKCanvasView) darüber.
//
// ARCHITEKTUR (wichtig zu verstehen):
// SwiftUI kann kein PDFView direkt darstellen – PDFView ist ein UIKit-View.
// Deshalb brauchen wir UIViewRepresentable als "Brücke" zwischen SwiftUI und UIKit.
//
// Die Hierarchie ist:
//   SwiftUI: PDFViewerView  →  enthält PDFCanvas (UIViewRepresentable)
//   UIKit:   PDFContainerView  →  enthält PDFView + PKCanvasView

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
            .ignoresSafeArea(edges: .bottom)    // PDF soll bis ganz unten gehen
    }
}

// MARK: - Brücke: SwiftUI ↔ UIKit

/// UIViewRepresentable ist das Protokoll, das SwiftUI sagt:
/// "Ich manage einen UIKit-View für dich."
/// Du musst 2 Methoden implementieren: makeUIView und updateUIView.
struct PDFCanvas: UIViewRepresentable {
    let pdfName: String

    /// Wird EINMAL aufgerufen um den UIKit-View zu erstellen.
    func makeUIView(context: Context) -> PDFContainerView {
        PDFContainerView(pdfName: pdfName)
    }

    /// Wird aufgerufen wenn sich SwiftUI-State ändert.
    /// Wir brauchen hier nichts – unser View managed sich selbst.
    func updateUIView(_ uiView: PDFContainerView, context: Context) {}

    /// Wird aufgerufen wenn der View ENTFERNT wird (z.B. zurück navigieren).
    /// Perfekter Zeitpunkt zum Speichern!
    static func dismantleUIView(_ uiView: PDFContainerView, coordinator: ()) {
        uiView.saveDrawing()
    }
}

// MARK: - Der eigentliche UIKit-View

/// Enthält zwei Subviews übereinander:
///   1. PDFView    (unten) – zeigt das PDF
///   2. PKCanvasView (oben) – durchsichtige Zeichenfläche
final class PDFContainerView: UIView {

    private let pdfView = PDFView()
    private let canvasView = PKCanvasView()
    private let pdfName: String

    // Wir müssen den ToolPicker als Property halten, sonst wird er sofort freigegeben.
    private var toolPicker: PKToolPicker?

    // MARK: Init

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
        pdfView.displayMode = .singlePageContinuous   // Alle Seiten untereinander
        pdfView.displayDirection = .vertical
        pdfView.autoScales = true                      // Passt sich an Bildschirmbreite an
        pdfView.backgroundColor = .systemGray6

        // PDF aus dem Bundle laden
        if let url = Bundle.main.url(forResource: pdfName, withExtension: "pdf") {
            pdfView.document = PDFDocument(url: url)
        }

        // PDFView füllt den ganzen Container aus (Auto Layout)
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pdfView)
        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: topAnchor),
            pdfView.bottomAnchor.constraint(equalTo: bottomAnchor),
            pdfView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    // MARK: Zeichenfläche einrichten

    private func setupCanvas() {
        canvasView.backgroundColor = .clear     // Durchsichtig! Man sieht das PDF darunter.
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput    // Finger + Pencil können zeichnen
    }

    // MARK: View-Lifecycle

    /// Wird aufgerufen wenn unser View in ein Window eingefügt wird.
    /// Erst jetzt können wir den CanvasView an den PDFView "anhängen".
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }

        attachCanvas()
        showToolPicker()
    }

    /// Wird bei jedem Layout-Pass aufgerufen (z.B. Rotation, Zoom).
    /// Wir stellen sicher, dass der Canvas immer die richtige Größe hat.
    override func layoutSubviews() {
        super.layoutSubviews()
        attachCanvas()
    }

    /// Hängt den Canvas als Subview an den internen "documentView" des PDFView.
    /// Das ist der Trick: So scrollt und zoomt der Canvas MIT dem PDF.
    private func attachCanvas() {
        guard let documentView = pdfView.documentView else { return }

        if canvasView.superview != documentView {
            documentView.addSubview(canvasView)
        }

        // Canvas muss immer so groß wie das gesamte PDF-Dokument sein
        canvasView.frame = documentView.bounds
    }

    /// Zeigt die PencilKit Werkzeugleiste (Stift, Radierer, Farben, ...).
    private func showToolPicker() {
        guard let window else { return }

        if toolPicker == nil {
            toolPicker = PKToolPicker.shared(for: window)
        }

        toolPicker?.addObserver(canvasView)
        toolPicker?.setVisible(true, forFirstResponder: canvasView)
        canvasView.becomeFirstResponder()
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
