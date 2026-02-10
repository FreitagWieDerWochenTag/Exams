// ContentView.swift
// Startbildschirm: Lehrer oder Schüler auswählen.
//
// NEUES KONZEPT: enum
// Ein enum ist wie ein "Aufzählungstyp" in C, aber mächtiger.
// Hier definieren wir die zwei Rollen, die ein Nutzer haben kann.

import SwiftUI

/// Die zwei Rollen in der App.
enum UserRole {
    case teacher
    case student
}

struct ContentView: View {

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
                    Text("Wähle deine Rolle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Zwei große Buttons
                VStack(spacing: 16) {
                    NavigationLink(destination: GroupEntryView(role: .teacher)) {
                        RoleButton(title: "Lehrer", icon: "person.fill", color: .blue)
                    }

                    NavigationLink(destination: GroupEntryView(role: .student)) {
                        RoleButton(title: "Schüler", icon: "graduationcap.fill", color: .green)
                    }
                }
                .padding(.horizontal, 40)

                Spacer()
                Spacer()
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Wiederverwendbarer Button

/// Ein großer, abgerundeter Button für die Rollenauswahl.
/// Das ist eine eigene View – in SwiftUI extrahiert man UI-Teile gerne in kleine Bausteine.
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
