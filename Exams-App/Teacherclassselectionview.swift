// TeacherClassSelectionView.swift
// Klassenauswahl für Lehrer (jedes Mal neu)

import SwiftUI

struct TeacherClassSelectionView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var klasse: String = ""
    @State private var showNext = false
    @State private var availableClasses: [String] = []
    @State private var showDropdown = false
    
    private var canContinue: Bool {
        !klasse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        VStack(spacing: 24) {
            
            Spacer()
            
            // User-Info
            VStack(spacing: 4) {
                Image(systemName: "person.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.blue)
                Text(auth.userName)
                    .font(.title3.bold())
                Text(auth.userEmail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Lehrer")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
            }
            
            Text("Gib die Klasse ein")
                .foregroundStyle(.secondary)
            
            VStack(spacing: 12) {
                TextField("z.B. 5BHIT", text: $klasse)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled(true)
                    .keyboardType(.asciiCapable)
                    .submitLabel(.done)
                    .onSubmit {
                        if canContinue { showNext = true }
                    }
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                
                // Dropdown für existierende Klassen
                if !availableClasses.isEmpty {
                    Menu {
                        ForEach(availableClasses, id: \.self) { className in
                            Button(className) {
                                klasse = className
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "list.bullet")
                            Text("Existierende Klasse wählen")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.blue)
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
                    .background(canContinue ? Color.blue : Color.gray.opacity(0.3))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 40)
            .disabled(!canContinue)
            
            Spacer()
        }
        .navigationTitle("Klasse")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            // Abmelden (links) - komplett ausloggen
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .destructive) {
                    auth.signOut()
                    // Keine dismiss() - signOut setzt isSignedIn = false
                    // ContentView navigiert automatisch zurück
                } label: {
                    Text("Abmelden")
                }
            }
        }
        .navigationDestination(isPresented: $showNext) {
            FachSelectionView(klasse: klasse, isStudent: false)
                .environmentObject(auth)
        }
        .onAppear {
            loadAvailableClasses()
        }
    }
    
    private func loadAvailableClasses() {
        RPiService.shared.fetchClasses { list in
            DispatchQueue.main.async {
                self.availableClasses = list
            }
        }
    }
}
