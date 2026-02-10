// StudentView.swift
// Schüler-Ansicht: Zeigt verfügbare Tests. "Test starten" öffnet den PDF-Viewer.
//
// ABLAUF:
// 1. Schüler sieht "Test verfügbar" (wird später vom RPi geladen)
// 2. Schüler drückt "Test starten"
// 3. PDF wird angezeigt (+ später AAC-Modus)
//
// NEUES KONZEPT: NavigationPath / navigationDestination
// Statt NavigationLink (der sofort navigiert) nutzen wir programmatische Navigation.
// Das gibt uns Kontrolle: Wir können VOR der Navigation noch Dinge tun (z.B. AAC starten).
import SwiftUI

struct StudentView: View {

    let group: String

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

                ProgressView("Prüfung wird geladen …")
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
        .onAppear {
            loadAvailableTest()
        }
        .navigationDestination(isPresented: $startedTest) {
            if let testName = availableTest {
                PDFViewerView(pdfName: testName)
            }
        }
    }

    // MARK: - Server

    private func loadAvailableTest() {
        RPiService.shared.fetchTests { list in
            DispatchQueue.main.async {
                self.availableTest = list.first?.filename
                self.isLoading = false
            }
        }
    }


    private func startTest() {
        guard let testName = availableTest else { return }

        RPiService.shared.downloadTest(filename: testName) { url in
            DispatchQueue.main.async {
                if url != nil {
                    startedTest = true
                }
            }
        }
    }
}
