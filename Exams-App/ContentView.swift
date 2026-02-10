// ContentView.swift
// Startbildschirm:
// 1. Erst Microsoft Login
// 2. Dann Rolle waehlen (Lehrer / Schueler)

import SwiftUI

/// Die zwei Rollen in der App.
enum UserRole {
    case teacher
    case student
}

struct ContentView: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {

                Spacer()

                // App-Titel
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                    Text("Exams")
                        .font(.largeTitle.bold())
                }

                if !auth.isSignedIn {
                    // --- Noch nicht eingeloggt ---
                    Text("Melde dich mit deinem Schulkonto an.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button {
                        Task { await auth.signIn() }
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.key.fill")
                            Text("Mit Microsoft anmelden")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 40)

                } else {
                    // --- Eingeloggt: Rolle waehlen ---
                    Text("Waehle deine Rolle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 16) {
                        NavigationLink(destination: GroupEntryView(role: .teacher)) {
                            RoleButton(title: "Lehrer", icon: "person.fill", color: .blue)
                        }

                        NavigationLink(destination: GroupEntryView(role: .student)) {
                            RoleButton(title: "Schueler", icon: "graduationcap.fill", color: .green)
                        }
                    }
                    .padding(.horizontal, 40)
                }

                // Fehlermeldung
                if let error = auth.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .padding(.horizontal)
                }

                Spacer()
                Spacer()
            }
            .navigationBarHidden(true)
            .onAppear {
                auth.configure()
            }
        }
    }
}

// MARK: - Wiederverwendbarer Button

struct RoleButton: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
            Text(title)
                .font(.title3.bold())
            Spacer()
            Image(systemName: "chevron.right")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.1))
        .foregroundStyle(color)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
