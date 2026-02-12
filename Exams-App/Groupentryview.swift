// GroupEntryView.swift
// Zeigt User-Info, Gruppen-Eingabe.
// Oben links: Abmelden (zurueck zum Login)
// Oben rechts: Demo-Wechsel Lehrer/Schueler

import SwiftUI

struct GroupEntryView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var groupCode: String = ""
    @State private var showNext = false

    private var isTeacher: Bool { auth.role == .teacher }

    private var canContinue: Bool {
        !groupCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 24) {

            Spacer()

            // User-Info
            VStack(spacing: 4) {
                Image(systemName: isTeacher ? "person.fill" : "graduationcap.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(isTeacher ? .blue : .green)
                Text(auth.userName)
                    .font(.title3.bold())
                Text(auth.userEmail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(isTeacher ? "Lehrer" : "Schueler")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(isTeacher ? Color.blue.opacity(0.1) : Color.green.opacity(0.1))
                    .foregroundStyle(isTeacher ? .blue : .green)
                    .clipShape(Capsule())
            }

            Text("Gib deine Gruppe ein")
                .foregroundStyle(.secondary)

            TextField("z.B. 4AHITS", text: $groupCode)
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
        .navigationTitle("Gruppe")
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
            // Demo: Rolle wechseln (rechts)
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    auth.setRoleManually(isTeacher ? .student : .teacher)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text(isTeacher ? "Schueler" : "Lehrer")
                            .font(.subheadline)
                    }
                }
            }
        }
        .navigationDestination(isPresented: $showNext) {
            if isTeacher {
                TeacherView(group: groupCode)
                    .environmentObject(auth)
            } else {
                StudentView(group: groupCode)
                    .environmentObject(auth)
            }
        }
    }
}
