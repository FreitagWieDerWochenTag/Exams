// TeacherView.swift
// Lehrer-Ansicht: PDF aus der Dateien-App auswaehlen und hochladen.

import SwiftUI
import UniformTypeIdentifiers

struct TeacherView: View {
    let group: String

    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showFilePicker = false
    @State private var selectedFileName: String?
    @State private var selectedFileData: Data?
    @State private var uploadStatus: String?
    @State private var isUploading = false

    var body: some View {
        VStack(spacing: 32) {

            Spacer()

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

            // Senden-Button
            if selectedFileData != nil {
                Button {
                    uploadPDF()
                } label: {
                    HStack {
                        if isUploading {
                            ProgressView().tint(.white)
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

            if let status = uploadStatus {
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Spacer()
        }
        .navigationTitle("Lehrer")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .destructive) {
                    auth.signOut()
                    dismiss()
                } label: {
                    Text("Abmelden")
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
    }

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
                uploadStatus = "Fehler: \(error.localizedDescription)"
            }

        case .failure(let error):
            uploadStatus = "Fehler: \(error.localizedDescription)"
        }
    }

    private func uploadPDF() {
        guard let data = selectedFileData,
              let name = selectedFileName else { return }

        isUploading = true
        uploadStatus = "Wird gesendet ..."

        RPiService.shared.uploadTest(fileName: name, fileData: data) { success in
            DispatchQueue.main.async {
                isUploading = false
                uploadStatus = success
                    ? "\(name) erfolgreich gesendet"
                    : "Senden fehlgeschlagen"
            }
        }
    }
}
