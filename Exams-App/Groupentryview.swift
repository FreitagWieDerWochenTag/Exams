// GroupEntryView.swift
// Eingabe der Schule / Gruppe.
// Je nach Rolle geht es danach zur Lehrer- oder Schüler-Ansicht.
//
// NEUES KONZEPT: @State + TextField
// @State speichert den aktuellen Textinhalt.
// Das "$" vor groupName (= $groupName) ist ein "Binding":
// Es gibt dem TextField eine REFERENZ auf die Variable,
// damit es den Text direkt ändern kann (wie ein Pointer in C).

import SwiftUI

struct GroupEntryView: View {
    let role: UserRole

    @State private var groupName: String = ""

    /// Button ist nur aktiv wenn ein Gruppenname eingegeben wurde.
    private var canContinue: Bool {
        !groupName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 32) {

            Spacer()

            // Icon + Titel
            VStack(spacing: 8) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.blue)
                Text("Schule / Gruppe")
                    .font(.title2.bold())
                Text("Gib den Namen deiner Gruppe ein.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Textfeld
            TextField("z.B. HTL-3AHIT", text: $groupName)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
                .padding(.horizontal, 40)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)

            // Weiter-Button
            NavigationLink(destination: destinationView) {
                Text("Weiter")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canContinue ? Color.blue : Color.gray.opacity(0.3))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!canContinue)
            .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
        .navigationTitle(role == .teacher ? "Lehrer" : "Schüler")
    }

    /// Je nach Rolle die richtige nächste Seite.
    /// @ViewBuilder erlaubt uns, verschiedene View-Typen zurückzugeben.
    @ViewBuilder
    private var destinationView: some View {
        let group = groupName.trimmingCharacters(in: .whitespaces)
        if role == .teacher {
            TeacherView(group: group)
        } else {
            StudentView(group: group)
        }
    }
}
