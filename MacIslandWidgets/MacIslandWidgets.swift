//
//  MacIslandWidgets.swift
//  MacIslandWidgets
//
//  Created by GeminiMortal on 2026/6/6.
//

import WidgetKit
import SwiftUI

// MARK: - Widget Bundle

@main
struct MacIslandWidgets: WidgetBundle {
    var body: some Widget {
        WeatherWidget()
        MusicWidget()
        TimerWidget()
    }
}
