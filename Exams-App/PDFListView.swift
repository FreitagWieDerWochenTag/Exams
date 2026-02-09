// PDFListView.swift
// Zeigt eine Liste aller PDF-Dateien, die im App-Bundle liegen.
// Tippt man auf eine, navigiert man zur PDFViewerView.

import SwiftUI

struct PDFListView: View {

    // @State = eine Variable, die sich ändern kann und die UI automatisch aktualisiert.
    // Vergleichbar mit einem "Observable" – wenn sich pdfNames ändert, wird die Liste neu gezeichnet.
    @State private var pdfNames: [String] = []

    var body: some View {

        // List = eine scrollbare Liste (wie UITableView in UIKit)
        List(pdfNames, id: \.self) { name in

            // NavigationLink = ein Tap navigiert zur Zielseite
            NavigationLink(destination: PDFViewerView(pdfName: name)) {
                Label(name, systemImage: "doc.fill")
                    .font(.headline)
                    .padding(.vertical, 6)
            }
        }
        .navigationTitle("Exams")
        // .task wird einmal ausgeführt wenn die View erscheint (wie viewDidLoad)
        .task {
            pdfNames = loadPDFNames()
        }
    }

    /// Sucht alle .pdf Dateien im App-Bundle und gibt deren Namen zurück (ohne .pdf Endung).
    private func loadPDFNames() -> [String] {
        // Bundle.main = der Ordner, in dem deine App liegt (mit allen Ressourcen)
        guard let path = Bundle.main.resourcePath else { return [] }

        // Alle Dateien im Bundle-Ordner auflisten
        let allFiles = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []

        // Nur .pdf Dateien behalten, die Endung abschneiden, sortieren
        return allFiles
            .filter { $0.lowercased().hasSuffix(".pdf") }
            .map { String($0.dropLast(4)) }           // "Mathe.pdf" → "Mathe"
            .sorted()
    }
}
