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

    /// Speichert eine Zeichnung als Datei mit klasse/fach Kontext
    static func save(drawing: PKDrawing, for pdfName: String, klasse: String, fach: String) {
        let folder = documentsDir
            .appendingPathComponent("Exams")
            .appendingPathComponent(klasse)
            .appendingPathComponent(fach)
            .appendingPathComponent("Drawings")
        
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        
        let url = folder.appendingPathComponent("\(pdfName)_drawing.data")
        do {
            let data = drawing.dataRepresentation()
            try data.write(to: url, options: .atomic)
            print("=== Zeichnung gespeichert: \(url.path) ===")
        } catch {
            print("=== Speichern fehlgeschlagen: \(error) ===")
        }
    }

    /// Lädt eine gespeicherte Zeichnung mit klasse/fach Kontext
    static func load(for pdfName: String, klasse: String, fach: String) -> PKDrawing? {
        let folder = documentsDir
            .appendingPathComponent("Exams")
            .appendingPathComponent(klasse)
            .appendingPathComponent(fach)
            .appendingPathComponent("Drawings")
        
        let url = folder.appendingPathComponent("\(pdfName)_drawing.data")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? PKDrawing(data: data)
    }
    
    // Legacy-Methoden für Abwärtskompatibilität
    static func save(drawing: PKDrawing, for pdfName: String) {
        let url = documentsDir.appendingPathComponent("\(pdfName)_drawing.data")
        do {
            let data = drawing.dataRepresentation()
            try data.write(to: url, options: .atomic)
        } catch {
            print("=== Speichern fehlgeschlagen: \(error) ===")
        }
    }

    static func load(for pdfName: String) -> PKDrawing? {
        let url = documentsDir.appendingPathComponent("\(pdfName)_drawing.data")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? PKDrawing(data: data)
    }
    
    /// Löscht eine gespeicherte Zeichnung mit klasse/fach Kontext
    static func delete(for pdfName: String, klasse: String, fach: String) {
        let folder = documentsDir
            .appendingPathComponent("Exams")
            .appendingPathComponent(klasse)
            .appendingPathComponent(fach)
            .appendingPathComponent("Drawings")
        let url = folder.appendingPathComponent("\(pdfName)_drawing.data")
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
                print("=== Zeichnung gelöscht: \(url.path) ===")
            } else {
                // Nichts zu löschen
                print("=== Keine Zeichnung zum Löschen gefunden: \(url.path) ===")
            }
        } catch {
            print("=== Löschen fehlgeschlagen: \(error) ===")
        }
    }
}
