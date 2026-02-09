// ContentView.swift
// Die "Wurzel" der App-Oberfläche.
//
// Auf dem iPad nutzen wir NavigationSplitView:
//   Links (Sidebar) = PDF-Liste
//   Rechts (Detail)  = der ausgewählte PDF-Viewer

import SwiftUI

struct ContentView: View {

    // Der Name des aktuell ausgewählten PDFs. nil = noch nichts ausgewählt.
    @State private var selectedPDF: String?

    var body: some View {
        NavigationSplitView {
            // --- Linke Seite: PDF-Liste ---
            PDFListView(selectedPDF: $selectedPDF)
        } detail: {
            // --- Rechte Seite: PDF-Viewer oder Platzhalter ---
            if let pdfName = selectedPDF {
                PDFViewerView(pdfName: pdfName)
                    // .id() erzwingt, dass SwiftUI den View komplett neu erstellt
                    // wenn sich pdfName ändert. Dadurch wird dismantleUIView aufgerufen
                    // (= Zeichnung wird gespeichert) bevor der neue View erscheint.
                    .id(pdfName)
            } else {
                ContentUnavailableView("Kein PDF ausgewählt",
                                       systemImage: "doc.text",
                                       description: Text("Wähle links ein PDF aus."))
            }
        }
    }
}
