// SubmissionsListView.swift
// Zeigt die Liste der Schülerabgaben für eine bestimmte Klasse/Fach/Test

import SwiftUI

struct Submission: Identifiable, Decodable {
    let id = UUID()
    let filename: String
    
    enum CodingKeys: String, CodingKey {
        case filename
    }
}

struct SubmissionsListView: View {
    let klasse: String
    let fach: String
    
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var submissions: [Submission] = []
    @State private var isLoading = true
    @State private var selectedSubmission: String?
    @State private var showPDF = false
    @State private var availableTests: [TestFile] = []
    @State private var selectedTest: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Test-Auswahl Header
            if !availableTests.isEmpty {
                VStack(spacing: 12) {
                    Text("Test auswählen:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Picker("Test", selection: $selectedTest) {
                        ForEach(availableTests, id: \.filename) { test in
                            Text(test.filename).tag(test.filename)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedTest) { _, _ in
                        loadSubmissions()
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            
            // Abgaben Liste
            if isLoading {
                ProgressView("Lade Abgaben ...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if submissions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)
                    Text("Keine Abgaben vorhanden")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    if selectedTest.isEmpty {
                        Text("Wähle einen Test aus")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(submissions) { submission in
                        Button {
                            loadSubmission(submission.filename)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "doc.fill")
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(submission.filename.replacingOccurrences(of: ".pdf", with: ""))
                                        .font(.headline)
                                    Text("Abgabe")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle("Abgaben")
        .navigationBarTitleDisplayMode(.inline)
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
        }
        .onAppear {
            loadAvailableTests()
        }
        .navigationDestination(isPresented: $showPDF) {
            if let filename = selectedSubmission {
                PDFViewerView(klasse: klasse, fach: fach, pdfName: filename, studentName: "", isTeacherView: true)
            }
        }
    }
    
    private func loadAvailableTests() {
        isLoading = true
        RPiService.shared.fetchTests(klasse: klasse, fach: fach) { list in
            DispatchQueue.main.async {
                self.availableTests = list
                if let first = list.first {
                    self.selectedTest = first.filename
                    self.loadSubmissions()
                } else {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadSubmissions() {
        guard !selectedTest.isEmpty else {
            submissions = []
            isLoading = false
            return
        }
        
        isLoading = true
        
        // Entferne .pdf Extension für die API
        let testBaseName = selectedTest.replacingOccurrences(of: ".pdf", with: "")
        
        RPiService.shared.fetchSubmissions(klasse: klasse, fach: fach, testName: testBaseName) { list in
            DispatchQueue.main.async {
                self.submissions = list
                self.isLoading = false
            }
        }
    }
    
    private func loadSubmission(_ filename: String) {
        // Entferne .pdf Extension für die API
        let testBaseName = selectedTest.replacingOccurrences(of: ".pdf", with: "")
        
        RPiService.shared.downloadSubmission(klasse: klasse,
                                            fach: fach,
                                            testName: testBaseName,
                                            filename: filename) { url in
            DispatchQueue.main.async {
                if url != nil {
                    selectedSubmission = filename
                    showPDF = true
                }
            }
        }
    }
}
