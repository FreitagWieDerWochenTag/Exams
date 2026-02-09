// PDFListView.swift
// Zeigt eine Liste aller PDF-Dateien, die im App-Bundle liegen.
// Die Auswahl wird über ein @Binding an ContentView zurückgegeben,
// damit NavigationSplitView weiß, welches PDF rechts angezeigt werden soll.

import SwiftUI

struct PDFListView: View {

    // @Binding = diese Variable "gehört" jemand anderem (hier: ContentView).
    // Änderungen hier werden automatisch auch dort sichtbar.
    // Vergleichbar mit einer Referenz/Pointer in C.
    @Binding var selectedPDF: String?

    @State private var pdfNames: [String] = []

    var body: some View {

        // List mit selection: tippt man auf einen Eintrag, wird selectedPDF gesetzt.
        List(pdfNames, id: \.self, selection: $selectedPDF) { name in
            Label(name, systemImage: "doc.fill")
                .font(.headline)
                .padding(.vertical, 6)
        }
        .navigationTitle("Exams")
        .task {
            pdfNames = loadPDFNames()
        }
    }

    /// Sucht alle .pdf Dateien im App-Bundle und gibt deren Namen zurück (ohne .pdf Endung).
    private func loadPDFNames() -> [String] {
        guard let path = Bundle.main.resourcePath else { return [] }
        let allFiles = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []

        return allFiles
            .filter { $0.lowercased().hasSuffix(".pdf") }
            .map { String($0.dropLast(4)) }
            .sorted()
    }
}
