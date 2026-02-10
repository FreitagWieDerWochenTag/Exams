// TeacherView.swift
// Lehrer-Ansicht: PDF aus der Dateien-App auswählen und an die Gruppe senden.
//
// NEUES KONZEPT: .fileImporter
// Das ist ein SwiftUI-Modifier, der den System-Datei-Picker öffnet.
// Er gibt uns eine URL zur ausgewählten Datei zurück.
// Wir müssen "startAccessingSecurityScopedResource()" aufrufen,
// weil die Datei außerhalb unserer Sandbox liegt (Sicherheit!).

import SwiftUI
import UniformTypeIdentifiers

struct TeacherView: View {
    let group: String

    @State private var showFilePicker = false
    @State private var selectedFileName: String?
    @State private var selectedFileData: Data?
    @State private var uploadStatus: String?

    var body: some View {
        VStack(spacing: 32) {

            Spacer()

            // Gruppen-Info
            VStack(spacing: 8) {
                Image(systemName: "person.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.blue)
                Text("Gruppe: \(group)")
                    .font(.title2.bold())
            }

            // PDF auswählen
            Button {
                showFilePicker = true
            } label: {
                HStack {
                    Image(systemName: "doc.badge.plus")
                    Text(selectedFileName ?? "PDF auswählen")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .foregroundStyle(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 40)

            // Senden-Button (nur sichtbar wenn ein PDF ausgewählt ist)
            if selectedFileData != nil {
                Button {
                    uploadPDF()
                } label: {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("An Schüler senden")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 40)
            }

            // Status-Meldung
            if let status = uploadStatus {
                Text(status)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Spacer()
        }
        .navigationTitle("Lehrer")
        // System-Datei-Picker für PDFs
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.pdf],      // Nur PDFs erlauben
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
    }

    // MARK: - Datei verarbeiten

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Security Scope: Wir müssen "um Erlaubnis fragen" um auf die Datei zuzugreifen,
            // weil sie außerhalb unserer App-Sandbox liegt.
            guard url.startAccessingSecurityScopedResource() else {
                uploadStatus = "❌ Kein Zugriff auf die Datei"
                return
            }
            // defer = wird IMMER am Ende des Blocks ausgeführt (wie finally in Java/C#)
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                selectedFileData = try Data(contentsOf: url)
                selectedFileName = url.lastPathComponent
                uploadStatus = nil
            } catch {
                uploadStatus = "❌ Fehler beim Lesen: \(error.localizedDescription)"
            }

        case .failure(let error):
            uploadStatus = "❌ \(error.localizedDescription)"
        }
    }

    // MARK: - Upload (Platzhalter für RPi-Kommunikation)

    private func uploadPDF() {
        // TODO: Hier kommt später der HTTP POST an den Raspberry Pi.
        // Für jetzt nur eine Bestätigung.
        uploadStatus = "✅ \(selectedFileName ?? "PDF") bereit zum Senden an Gruppe \(group)"
    }
}
