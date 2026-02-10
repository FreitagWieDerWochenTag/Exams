// ExamsApp.swift
// Einstiegspunkt – wie int main() in C.
// Erstellt das AuthViewModel und gibt es als EnvironmentObject an alle Views weiter.

import SwiftUI

@main
struct ExamsApp: App {
    @StateObject private var auth = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
        }
    }
}
