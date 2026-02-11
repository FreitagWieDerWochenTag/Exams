import SwiftUI

struct StudentView: View {
    let group: String

    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var availableTest: String? = nil
    @State private var startedTest = false
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 32) {

            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.green)
                Text("Gruppe: \(group)")
                    .font(.title2.bold())
            }

            if isLoading {
                ProgressView("Pruefung wird geladen ...")
                    .padding()
            } else if let testName = availableTest {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading) {
                            Text(testName)
                                .font(.headline)
                            Text("Bereit")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    Button {
                        startTest()
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Test starten")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, 40)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Kein Test verfuegbar")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Warte auf deinen Lehrer.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
            Spacer()
        }
        .navigationTitle("Schueler")
        .toolbar {
            
        }
        .onAppear { loadAvailableTest() }
        .navigationDestination(isPresented: $startedTest) {
            if let testName = availableTest {
                PDFViewerView(group: group, pdfName: testName)
            }
        }
    }

    private func loadAvailableTest() {
        RPiService.shared.fetchTests(group: group) { list in
            DispatchQueue.main.async {
                self.availableTest = list.first?.filename
                self.isLoading = false
            }
        }
    }

    private func startTest() {
        guard let testName = availableTest else { return }

        RPiService.shared.downloadTest(group: group, filename: testName) { url in
            DispatchQueue.main.async {
                if url != nil {
                    startedTest = true
                }
            }
        }
    }
}
