// TeacherView.swift
// Lehrer-Ansicht: PDF aus der Dateien-App auswählen und hochladen.

import SwiftUI
import UniformTypeIdentifiers

struct TeacherView: View {
    let klasse: String
    let fach: String

    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showFilePicker = false
    @State private var selectedFileName: String?
    @State private var selectedFileData: Data?
    @State private var uploadStatus: String?
    @State private var isUploading = false
    
    @State private var showSubmissions = false

    var body: some View {
        VStack(spacing: 32) {

            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "person.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.blue)
                Text("Klasse: \(klasse)")
                    .font(.title2.bold())
                Text("Fach: \(fach)")
                    .font(.title3)
                    .foregroundStyle(.secondary)
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
                        Text("An Schüler senden")
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
            
            // Abgaben anzeigen Button
            Button {
                showSubmissions = true
            } label: {
                HStack {
                    Image(systemName: "tray.full.fill")
                    Text("Abgaben anzeigen")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange.opacity(0.1))
                .foregroundStyle(.orange)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 40)

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
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Zurück")
                    }
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    auth.signOut()
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
        .navigationDestination(isPresented: $showSubmissions) {
            SubmissionsListView(klasse: klasse, fach: fach)
                .environmentObject(auth)
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

        RPiService.shared.uploadTest(klasse: klasse,
                                     fach: fach,
                                     fileName: name,
                                     fileData: data) { success in
            DispatchQueue.main.async {
                isUploading = false
                uploadStatus = success
                    ? "\(name) erfolgreich gesendet"
                    : "Senden fehlgeschlagen"
            }
        }
    }
}
