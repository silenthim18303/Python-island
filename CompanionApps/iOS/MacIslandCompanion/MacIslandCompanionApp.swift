//
//  MacIslandCompanionApp.swift
//  MacIslandCompanion
//
//  Created by GeminiMortal on 2026/6/8.
//

import SwiftUI

@main
struct MacIslandCompanionApp: App {
    @StateObject private var connectionManager = ConnectionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectionManager)
        }
    }
}
