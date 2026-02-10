// PDFListView.swift
// Zeigt eine Liste aller PDF-Dateien, die im App-Bundle liegen.
// Die Auswahl wird über ein @Binding an ContentView zurückgegeben,
// damit NavigationSplitView weiß, welches PDF rechts angezeigt werden soll.
import SwiftUI

struct PDFListView: View {

    @Binding var selectedPDF: String?
    @State private var pdfs: [TestFile] = []
    @State private var isLoading = true

    var body: some View {
        List {
            if isLoading {
                ProgressView("Lade Prüfungen …")
            } else {
                ForEach(pdfs, id: \.filename) { pdf in
                    Button {
                        loadPDF(pdf.filename)
                    } label: {
                        Text(pdf.filename)
                    }
                }
            }
        }
        .navigationTitle("Prüfungen")
        .onAppear {
            loadList()
        }
    }

    private func loadList() {
        RPiService.shared.fetchTests { list in
            DispatchQueue.main.async {
                pdfs = list
                isLoading = false
            }
        }
    }

    private func loadPDF(_ filename: String) {
        RPiService.shared.downloadTest(filename: filename) { url in
            DispatchQueue.main.async {
                if url != nil {
                    selectedPDF = filename
                }
            }
        }
    }
}
