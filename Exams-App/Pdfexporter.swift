import Foundation
import PDFKit
import PencilKit
import UIKit

struct PDFExporter {

    static func export(pdfName: String, drawing: PKDrawing) -> URL? {

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let originalURL = docs.appendingPathComponent(pdfName)

        guard let document = PDFDocument(url: originalURL) else {
            print("PDF \(pdfName) nicht gefunden in Documents")
            return nil
        }

        let pageCount = document.pageCount
        guard pageCount > 0 else { return nil }

        guard let firstPage = document.page(at: 0) else { return nil }
        let pageRect = firstPage.bounds(for: .mediaBox)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            for i in 0..<pageCount {
                guard let page = document.page(at: i) else { continue }

                context.beginPage()
                let ctx = context.cgContext

                // 🔥 Immer Weiß füllen, bevor irgendwas gezeichnet wird
                ctx.setFillColor(UIColor.white.cgColor)
                ctx.fill(pageRect)

                // PDF-Seite zeichnen (flipped)
                ctx.saveGState()
                ctx.translateBy(x: 0, y: pageRect.height)
                ctx.scaleBy(x: 1, y: -1)
                if let pageRef = page.pageRef {
                    ctx.drawPDFPage(pageRef)
                }
                ctx.restoreGState()

                // Zeichnung drauf (UIKit coords)
                let sliceY = CGFloat(i) * pageRect.height
                let sliceRect = CGRect(x: 0, y: sliceY, width: pageRect.width, height: pageRect.height)

                let pageDrawingImage = drawing.image(from: sliceRect, scale: UIScreen.main.scale)
                pageDrawingImage.draw(in: pageRect)
            }
        }

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
