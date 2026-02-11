// PDFExporter.swift
// Nimmt ein Original-PDF und eine PKDrawing und "brennt" die Zeichnung
// auf jede PDF-Seite. Ergebnis: ein neues PDF mit Zeichnungen als Datei.

import Foundation
import PDFKit
import PencilKit

struct PDFExporter {

    /// Erstellt ein neues PDF mit der Zeichnung eingebrannt.
    /// - Returns: URL zur exportierten PDF-Datei, oder nil bei Fehler.
    static func export(pdfName: String, drawing: PKDrawing) -> URL? {

        // 1. Original-PDF aus Documents-Ordner laden (heruntergeladen vom Server)
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let originalURL = docs.appendingPathComponent(pdfName)

        guard let document = PDFDocument(url: originalURL) else {
            print("PDF \(pdfName) nicht gefunden in Documents")
            return nil
        }

        let pageCount = document.pageCount
        guard pageCount > 0 else { return nil }

        // 2. Erste Seite holen um die Seitengroesse zu bestimmen
        guard let firstPage = document.page(at: 0) else { return nil }
        let pageRect = firstPage.bounds(for: .mediaBox)

        // 3. PDF-Renderer erstellen
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        // 4. Jede Seite rendern
        let data = renderer.pdfData { context in
            for i in 0..<pageCount {
                guard let page = document.page(at: i) else { continue }

                context.beginPage()

                let ctx = context.cgContext

                // Koordinatensystem umdrehen (PDF: unten-links, UIKit: oben-links)
                ctx.saveGState()
                ctx.translateBy(x: 0, y: pageRect.height)
                ctx.scaleBy(x: 1, y: -1)

                ctx.drawPDFPage(page.pageRef!)

                ctx.restoreGState()

                // Zeichnung fuer diese Seite drueberzeichnen
                let sliceY = CGFloat(i) * pageRect.height
                let sliceRect = CGRect(x: 0, y: sliceY,
                                       width: pageRect.width, height: pageRect.height)

                let pageDrawingImage = drawing.image(from: sliceRect, scale: UIScreen.main.scale)
                pageDrawingImage.draw(in: pageRect)
            }
        }

        // 5. In eine temporaere Datei schreiben
        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(pdfName)_abgabe.pdf")

        do {
            try data.write(to: exportURL, options: .atomic)
            return exportURL
        } catch {
            print("Export fehlgeschlagen: \(error)")
            return nil
        }
    }
}
