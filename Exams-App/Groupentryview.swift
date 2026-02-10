import SwiftUI

struct GroupEntryView: View {
    let role: AppRole

    @State private var groupName: String = ""

    var body: some View {
        VStack(spacing: 20) {

            Text(role == .teacher ? "Lehrerbereich" : "Schülerbereich")
                .font(.title.bold())

            TextField("Gruppenname eingeben", text: $groupName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            if role == .teacher {
                Button("Gruppe erstellen") {
                    // TODO: Gruppe erstellen
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Gruppe beitreten") {
                    // TODO: Gruppe beitreten
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .padding()
    }
}
