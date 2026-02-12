import SwiftUI

struct StudentView: View {
    let klasse: String
    let fach: String

    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var availableTest: String? = nil
    @State private var startedTest = false
    @State private var isLoading = true
    @State private var refreshTimer: Timer?

    var body: some View {
        VStack(spacing: 32) {

            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.green)
                Text("Klasse: \(klasse)")
                    .font(.title2.bold())
                Text("Fach: \(fach)")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            if isLoading {
                ProgressView("Prüfung wird geladen ...")
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
                    Text("Kein Test verfügbar")
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
        .navigationTitle("Schüler")
        .toolbar {
            // Zurück-Button
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Zurück")
                    }
                }
            }
        }
        .onAppear {
            loadAvailableTest()
            // Alle 5 Sekunden nach neuen Tests suchen
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                loadAvailableTest()
            }
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
        .navigationDestination(isPresented: $startedTest) {
            if let testName = availableTest {
                PDFViewerView(klasse: klasse, fach: fach, pdfName: testName, studentName: auth.userName)
            }
        }
    }

    private func loadAvailableTest() {
        RPiService.shared.fetchTests(klasse: klasse, fach: fach) { list in
            DispatchQueue.main.async {
                // Filter: Zeige nur Tests die noch nicht abgegeben wurden
                let unsubmittedTests = list.filter { test in
                    let key = "submitted_\(self.klasse)_\(self.fach)_\(test.filename)"
                    return !UserDefaults.standard.bool(forKey: key)
                }
                
                self.availableTest = unsubmittedTests.first?.filename
                self.isLoading = false
            }
        }
    }

    private func startTest() {
        guard let testName = availableTest else { return }

        RPiService.shared.downloadTest(klasse: klasse, fach: fach, filename: testName) { url in
            DispatchQueue.main.async {
                if url != nil {
                    startedTest = true
                }
            }
        }
    }
}
