// FachSelectionView.swift
// Fachauswahl für Lehrer und Schüler (jedes Mal neu)

import SwiftUI

struct FachSelectionView: View {
    let klasse: String
    let isStudent: Bool
    
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var fach: String = ""
    @State private var showNext = false
    @State private var availableSubjects: [String] = []
    
    private var canContinue: Bool {
        !fach.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        VStack(spacing: 24) {
            
            Spacer()
            
            // User-Info
            VStack(spacing: 4) {
                Image(systemName: isStudent ? "graduationcap.fill" : "person.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(isStudent ? .green : .blue)
                Text("Klasse: \(klasse)")
                    .font(.title3.bold())
                Text(auth.userName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(isStudent ? "Schüler" : "Lehrer")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(isStudent ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                    .foregroundStyle(isStudent ? .green : .blue)
                    .clipShape(Capsule())
            }
            
            Text("Gib dein Fach ein")
                .foregroundStyle(.secondary)
            
            VStack(spacing: 12) {
                TextField("z.B. Mathe", text: $fach)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(true)
                    .keyboardType(.asciiCapable)
                    .submitLabel(.done)
                    .onSubmit {
                        if canContinue { showNext = true }
                    }
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                
                // Dropdown für existierende Fächer
                if !availableSubjects.isEmpty {
                    Menu {
                        ForEach(availableSubjects, id: \.self) { subject in
                            Button(subject) {
                                fach = subject
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "list.bullet")
                            Text("Existierendes Fach wählen")
                        }
                        .font(.subheadline)
                        .foregroundStyle(isStudent ? .green : .blue)
                    }
                }
            }
            .padding(.horizontal, 40)
            
            Button {
                showNext = true
            } label: {
                Text("Weiter")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canContinue ? (isStudent ? Color.green : Color.blue) : Color.gray.opacity(0.3))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 40)
            .disabled(!canContinue)
            
            Spacer()
        }
        .navigationTitle("Fach")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            // Zurück (links)
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
        .navigationDestination(isPresented: $showNext) {
            if isStudent {
                StudentView(klasse: klasse, fach: fach)
                    .environmentObject(auth)
            } else {
                TeacherView(klasse: klasse, fach: fach)
                    .environmentObject(auth)
            }
        }
        .onAppear {
            loadAvailableSubjects()
        }
    }
    
    private func loadAvailableSubjects() {
        RPiService.shared.fetchSubjects(klasse: klasse) { list in
            DispatchQueue.main.async {
                self.availableSubjects = list
            }
        }
    }
}
