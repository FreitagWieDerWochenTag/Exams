// ContentView.swift
// 1. Microsoft Login
// 2. Wenn Rolle bekannt -> automatisch zur entsprechenden Entry View
// 3. Wenn Rolle unbekannt und fertig geladen -> manuelle Auswahl

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var goToNext = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {

                Spacer()

                // App-Titel
                VStack(spacing: 8) {
                    // Logo hinzufügen (falls vorhanden in Assets)
                    // Wenn kein Logo vorhanden, zeige Icon
                    if let _ = UIImage(named: "AppLogo") {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                    } else {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)
                    }
                    Text("Exams")
                        .font(.largeTitle.bold())
                }

                if !auth.isSignedIn {
                    // --- Nicht eingeloggt ---
                    if auth.isBusy {
                        ProgressView("Anmeldung wird geprüft ...")
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
                    Text("Wähle deine Rolle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 16) {
                        Button { auth.setRoleManually(.teacher) } label: {
                            RoleButton(title: "Lehrer", icon: "person.fill", color: .blue)
                        }
                        Button { auth.setRoleManually(.student) } label: {
                            RoleButton(title: "Schüler", icon: "graduationcap.fill", color: .green)
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
                    goToNext = true
                }
            }
            .onChange(of: auth.isSignedIn) { _, signedIn in
                if signedIn && auth.role != .unknown {
                    goToNext = true
                }
            }
            .navigationDestination(isPresented: $goToNext) {
                if auth.role == .teacher {
                    TeacherClassSelectionView()
                        .environmentObject(auth)
                } else {
                    // Prüfe ob Schüler bereits eine Klasse gespeichert hat
                    if let savedKlasse = UserDefaults.standard.string(forKey: "studentKlasse"), !savedKlasse.isEmpty {
                        FachSelectionView(klasse: savedKlasse, isStudent: true)
                            .environmentObject(auth)
                    } else {
                        ClassSelectionView()
                            .environmentObject(auth)
                    }
                }
            }
        }
    }
}
