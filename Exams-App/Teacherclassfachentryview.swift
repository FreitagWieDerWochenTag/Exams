// TeacherClassFachEntryView.swift
// Lehrer geben jedes Mal Klasse und Fach ein (da sie mehrere Klassen haben)

import SwiftUI

struct TeacherClassFachEntryView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var klasse: String = ""
    @State private var fach: String = ""
    @State private var showNext = false
    
    private var canContinue: Bool {
        !klasse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !fach.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            
            Text("Gib die Klasse und das Fach ein")
                .foregroundStyle(.secondary)
            
            VStack(spacing: 16) {
                TextField("z.B. 5BHIT", text: $klasse)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled(true)
                    .keyboardType(.asciiCapable)
                    .submitLabel(.next)
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                
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
        .navigationTitle("Klasse & Fach")
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
            TeacherView(klasse: klasse, fach: fach)
                .environmentObject(auth)
        }
    }
}
