// GroupEntryView.swift
// Eingabe der Schule / Gruppe.
// Zeigt nach dem Login den eingeloggten User an.
// Je nach Rolle geht es danach zur Lehrer- oder Schueler-Ansicht.

import SwiftUI

struct GroupEntryView: View {
    let role: UserRole

    @EnvironmentObject var auth: AuthViewModel
    @State private var groupName: String = ""
    @State private var navigateToNext = false

    private var canContinue: Bool {
        !groupName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 32) {

            Spacer()

            // User-Info (nach Login sichtbar)
            if auth.isSignedIn {
                VStack(spacing: 4) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.green)
                    Text(auth.userName)
                        .font(.title3.bold())
                    Text(auth.userEmail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Rolle: \(auth.role.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Icon + Titel
            VStack(spacing: 8) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 40))
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
            Button {
                navigateToNext = true
            } label: {
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
        .navigationTitle(role == .teacher ? "Lehrer" : "Schueler")
        .navigationDestination(isPresented: $navigateToNext) {
            let group = groupName.trimmingCharacters(in: .whitespaces)
            if role == .teacher {
                TeacherView(group: group)
            } else {
                StudentView(group: group)
            }
        }
    }
}
