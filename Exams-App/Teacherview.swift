// TeacherView.swift
// Lehrer-Ansicht: PDF aus der Dateien-App auswaehlen und an den RPi senden.

import SwiftUI
import UniformTypeIdentifiers

struct TeacherView: View {
    let group: String

    @State private var showFilePicker = false
    @State private var selectedFileName: String?
    @State private var selectedFileData: Data?
    @State private var uploadStatus: String?
    @State private var isUploading = false

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

            // PDF auswaehlen
            Button {
                showFilePicker = true
            } label: {
                HStack {
                    Image(systemName: "doc.badge.plus")
                    Text(selectedFileName ?? "PDF auswaehlen")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .foregroundStyle(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 40)

            // Senden-Button (nur sichtbar wenn ein PDF ausgewaehlt ist)
            if selectedFileData != nil {
                Button {
                    uploadPDF()
                } label: {
                    HStack {
                        if isUploading {
                            ProgressView()
                                .tint(.white)
                        }
                        Image(systemName: "paperplane.fill")
                        Text("An Schueler senden")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isUploading ? Color.gray : Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 40)
                .disabled(isUploading)
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
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.pdf],
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

            guard url.startAccessingSecurityScopedResource() else {
                uploadStatus = "Kein Zugriff auf die Datei"
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                selectedFileData = try Data(contentsOf: url)
                selectedFileName = url.lastPathComponent
                uploadStatus = nil
            } catch {
                uploadStatus = "Fehler beim Lesen: \(error.localizedDescription)"
            }

        case .failure(let error):
            uploadStatus = "\(error.localizedDescription)"
        }
    }

    // MARK: - Upload an RPi

    private func uploadPDF() {
        guard let data = selectedFileData,
              let name = selectedFileName else { return }

        isUploading = true
        uploadStatus = "Wird gesendet ..."

        // Prefer a completion-labeled API if that's the declared signature.
        // If your RPiService exposes an async version, use the Task-based branch below instead and remove this one.
        RPiService.shared.uploadTest(fileName: name, fileData: data, completion: { success in
            DispatchQueue.main.async {
                isUploading = false
                if success {
                    uploadStatus = "\(name) erfolgreich an Gruppe \(group) gesendet"
                } else {
                    uploadStatus = "Senden fehlgeschlagen. Ist der RPi erreichbar?"
                }
            }
        })
        /*
        // If RPiService exposes an async variant like:
        // func uploadTest(fileName: String, fileData: Data, group: String) async -> Bool
        // you can use this instead of the completion-based call above:
        Task {
            let success = await RPiService.shared.uploadTest(fileName: name, fileData: data, group: group)
            await MainActor.run {
                isUploading = false
                if success {
                    uploadStatus = "\(name) erfolgreich an Gruppe \(group) gesendet"
                } else {
                    uploadStatus = "Senden fehlgeschlagen. Ist der RPi erreichbar?"
                }
            }
        }
        */
    }
}

