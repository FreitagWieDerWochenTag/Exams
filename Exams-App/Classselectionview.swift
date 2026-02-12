// ClassSelectionView.swift
// Einmalige Klassenauswahl für Schüler (wird gespeichert)

import SwiftUI

struct ClassSelectionView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var klasse: String = ""
    @State private var showNext = false
    
    private var canContinue: Bool {
        !klasse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        VStack(spacing: 24) {
            
            Spacer()
            
            // User-Info
            VStack(spacing: 4) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.green)
                Text(auth.userName)
                    .font(.title3.bold())
                Text(auth.userEmail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Schüler")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
            }
            
            Text("Gib deine Klasse ein")
                .foregroundStyle(.secondary)
            
            TextField("z.B. 5BHIT", text: $klasse)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled(true)
                .keyboardType(.asciiCapable)
                .submitLabel(.done)
                .onSubmit {
                    if canContinue {
                        saveClassAndContinue()
                    }
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 40)
            
            Button {
                saveClassAndContinue()
            } label: {
                Text("Weiter")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canContinue ? Color.green : Color.gray.opacity(0.3))
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
            // Abmelden (links)
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .destructive) {
                    auth.signOut()
                    dismiss()
                } label: {
                    Text("Abmelden")
                }
            }
        }
        .navigationDestination(isPresented: $showNext) {
            FachSelectionView(klasse: klasse, isStudent: true)
                .environmentObject(auth)
        }
    }
    
    private func saveClassAndContinue() {
        guard canContinue else { return }
        // Klasse speichern für Schüler
        UserDefaults.standard.set(klasse, forKey: "studentKlasse")
        showNext = true
    }
}
