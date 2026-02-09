// PDFStorage.swift
// Kümmert sich ums Speichern und Laden von Zeichnungen.
// Jede Zeichnung wird als Datei im Documents-Ordner der App abgelegt.

import Foundation
import PencilKit

struct PDFStorage {

    // Der Documents-Ordner – der einzige Ort, an dem deine App dauerhaft Daten speichern darf.
    // (Bundle ist read-only, Documents ist read-write)
    private static var documentsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Speichert eine Zeichnung als Datei.  Dateiname: "<pdfName>_drawing.data"
    static func save(drawing: PKDrawing, for pdfName: String) {
        let url = documentsDir.appendingPathComponent("\(pdfName)_drawing.data")
        do {
            let data = drawing.dataRepresentation()   // PKDrawing → Data (Bytes)
            try data.write(to: url, options: .atomic)  // .atomic = erst temp-Datei, dann umbenennen (sicherer)
        } catch {
            print("❌ Speichern fehlgeschlagen: \(error)")
        }
    }

    /// Lädt eine gespeicherte Zeichnung. Gibt nil zurück wenn noch nichts gespeichert wurde.
    static func load(for pdfName: String) -> PKDrawing? {
        let url = documentsDir.appendingPathComponent("\(pdfName)_drawing.data")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? PKDrawing(data: data)
    }
}
