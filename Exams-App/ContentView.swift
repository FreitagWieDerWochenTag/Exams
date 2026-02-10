import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {

                Text("Exams")
                    .font(.largeTitle.bold())

                if !auth.isSignedIn {
                    Button("Mit Microsoft anmelden") {
                        Task { await auth.signIn() }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    switch auth.role {
                    case .teacher:
                        NavigationLink("Weiter als Lehrer") {
                            GroupEntryView(role: .teacher)
                        }
                        .buttonStyle(.borderedProminent)

                    case .student:
                        NavigationLink("Weiter als Schüler") {
                            GroupEntryView(role: .student)
                        }
                        .buttonStyle(.borderedProminent)

                    case .unknown:
                        Text("Rolle konnte nicht automatisch erkannt werden")

                        Button("Ich bin Lehrer") {
                            auth.setRoleManually(.teacher)
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Ich bin Schüler") {
                            auth.setRoleManually(.student)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                if let error = auth.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
            .padding()
            .onAppear {
                auth.configure()
            }
        }
    }
}
