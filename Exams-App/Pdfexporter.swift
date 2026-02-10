// PDFExporter.swift
// Nimmt ein Original-PDF und eine PKDrawing und "brennt" die Zeichnung
// auf jede PDF-Seite. Ergebnis: ein neues PDF mit Zeichnungen als Datei.
//
// WIE ES FUNKTIONIERT:
// 1. Für jede Seite des PDFs einen "Grafik-Kontext" öffnen (wie ein Maler eine Leinwand)
// 2. Die originale PDF-Seite darauf zeichnen
// 3. Die PencilKit-Zeichnung darauf zeichnen (nur den Teil, der auf dieser Seite liegt)
// 4. Kontext schließen → fertige PDF-Datei
//
// NEUES KONZEPT: UIGraphicsPDFRenderer
// Das ist Apples API um PDFs zu ERSTELLEN (nicht anzuzeigen).
// Man öffnet einen Kontext, zeichnet rein (wie auf ein Canvas), und bekommt Data zurück.

import Foundation
import PDFKit
import PencilKit

struct PDFExporter {

    /// Erstellt ein neues PDF mit der Zeichnung eingebrannt.
    /// - Returns: URL zur exportierten PDF-Datei, oder nil bei Fehler.
    static func export(pdfName: String, drawing: PKDrawing) -> URL? {

        // 1. Original-PDF laden
        guard let originalURL = Bundle.main.url(forResource: pdfName, withExtension: "pdf"),
              let document = PDFDocument(url: originalURL) else {
            print("❌ PDF \(pdfName) nicht gefunden")
            return nil
        }

        let pageCount = document.pageCount
        guard pageCount > 0 else { return nil }

        // 2. Erste Seite holen um die Seitengröße zu bestimmen
        guard let firstPage = document.page(at: 0) else { return nil }
        let pageRect = firstPage.bounds(for: .mediaBox)

        // 3. PDF-Renderer erstellen
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        // 4. Jede Seite rendern
        let data = renderer.pdfData { context in
            for i in 0..<pageCount {
                guard let page = document.page(at: i) else { continue }

                // Neue PDF-Seite beginnen
                context.beginPage()

                let ctx = context.cgContext

                // PDF-Koordinatensystem: Ursprung unten-links (wie Mathe).
                // UIKit-Koordinatensystem: Ursprung oben-links.
                // Wir müssen das Koordinatensystem umdrehen.
                ctx.saveGState()
                ctx.translateBy(x: 0, y: pageRect.height)
                ctx.scaleBy(x: 1, y: -1)

                // Originale PDF-Seite zeichnen
                ctx.drawPDFPage(page.pageRef!)

                ctx.restoreGState()

                // Zeichnung für diese Seite drüberzeichnen
                // Wir schneiden den passenden Streifen aus dem Gesamtbild aus.
                let sliceY = CGFloat(i) * pageRect.height
                let sliceRect = CGRect(x: 0, y: sliceY,
                                       width: pageRect.width, height: pageRect.height)

                // Nur den relevanten Teil der Zeichnung für diese Seite holen
                let pageDrawingImage = drawing.image(from: sliceRect, scale: UIScreen.main.scale)
                pageDrawingImage.draw(in: pageRect)
            }
        }

        // 6. In eine temporäre Datei schreiben
        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(pdfName)_abgabe.pdf")

        do {
            try data.write(to: exportURL, options: .atomic)
            return exportURL
        } catch {
            print("❌ Export fehlgeschlagen: \(error)")
            return nil
        }
    }
}
