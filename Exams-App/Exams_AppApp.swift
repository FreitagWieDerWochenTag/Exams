// Exams_AppApp.swift
// Einstiegspunkt der App.
// Erstellt das AuthViewModel und gibt es als EnvironmentObject an alle Views.

import SwiftUI

@main
struct Exams_AppApp: App {
    @StateObject private var auth = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
        }
    }
}
