// ContentView.swift
// 1. Microsoft Login
// 2. Wenn Rolle bekannt -> automatisch zur GroupEntryView
// 3. Wenn Rolle unbekannt und fertig geladen -> manuelle Auswahl

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var goToGroup = false

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
                    // --- Nicht eingeloggt ---
                    if auth.isBusy {
                        ProgressView("Anmeldung wird geprueft ...")
                    } else {
                        Text("Melde dich mit deinem Schulkonto an.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        // Microsoft-Style Login Button
                        Button {
                            Task { await auth.signIn() }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "globe")
                                    .font(.title3)
                                Text("Mit Microsoft anmelden")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .foregroundStyle(.black)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                        }
                        .padding(.horizontal, 40)
                    }

                } else if auth.isBusy {
                    // --- Eingeloggt, Rolle wird geladen ---
                    ProgressView("Rolle wird erkannt ...")

                } else if auth.role == .unknown {
                    // --- Rolle konnte nicht erkannt werden ---
                    Text("Waehle deine Rolle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 16) {
                        Button { auth.setRoleManually(.teacher) } label: {
                            RoleButton(title: "Lehrer", icon: "person.fill", color: .blue)
                        }
                        Button { auth.setRoleManually(.student) } label: {
                            RoleButton(title: "Schueler", icon: "graduationcap.fill", color: .green)
                        }
                    }
                    .padding(.horizontal, 40)
                }

                if let error = auth.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .padding(.horizontal)
                }

                Spacer()
                Spacer()
            }
            .navigationBarBackButtonHidden(true)
            .onAppear {
                auth.configure()
            }
            .onChange(of: auth.role) { _, newRole in
                if auth.isSignedIn && newRole != .unknown {
                    goToGroup = true
                }
            }
            .onChange(of: auth.isSignedIn) { _, signedIn in
                if signedIn && auth.role != .unknown {
                    goToGroup = true
                }
            }
            .navigationDestination(isPresented: $goToGroup) {
                GroupEntryView()
                    .environmentObject(auth)
            }
        }
    }
}
