// PDFListView.swift
// Laedt die PDF-Liste vom RPi-Server und zeigt sie an.

import SwiftUI

struct PDFListView: View {
    @Binding var selectedPDF: String?
    @State private var pdfs: [TestFile] = []
    @State private var isLoading = true

    var body: some View {
        List {
            if isLoading {
                ProgressView("Lade Pruefungen ...")
            } else {
                ForEach(pdfs, id: \.filename) { pdf in
                    Button {
                        loadPDF(pdf.filename)
                    } label: {
                        Label(pdf.filename, systemImage: "doc.fill")
                            .font(.headline)
                            .padding(.vertical, 6)
                    }
                }
            }
        }
        .navigationTitle("Pruefungen")
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
