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

    // Simuliert ob ein Test verfügbar ist.
    // Wird später durch einen echten Server-Check ersetzt.
    @State private var availableTest: String? = "Leo_RPi"

    // Wenn true, navigieren wir zum PDF-Viewer.
    @State private var startedTest = false

    var body: some View {
        VStack(spacing: 32) {

            Spacer()

            // Gruppen-Info
            VStack(spacing: 8) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.green)
                Text("Gruppe: \(group)")
                    .font(.title2.bold())
            }

            // Test-Status
            if let testName = availableTest {

                // Test ist verfügbar
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

                    // "Test starten" Button
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
                // Kein Test verfügbar
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
        // Programmatische Navigation: wenn startedTest true wird → navigiere zum PDFViewer
        .navigationDestination(isPresented: $startedTest) {
            // TODO: Hier später den echten PDF-Namen vom Server verwenden.
            // Für jetzt nehmen wir den Test-Namen als PDF-Name.
            PDFViewerView(pdfName: availableTest ?? "")
        }
    }

    // MARK: - Test starten

    private func startTest() {
        // TODO: Hier später AAC-Modus aktivieren
        // UIAccessibility.requestGuidedAccessSession(...)

        // Navigation zum PDF-Viewer auslösen
        startedTest = true
    }
}
