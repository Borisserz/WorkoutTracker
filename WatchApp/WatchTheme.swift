// ============================================================
// FILE: WatchApp/Theme/WatchTheme.swift
// ============================================================
internal import SwiftUI

struct WatchTheme {
    static let background = Color.black
    static let surface = Color(white: 0.12)
    static let surfaceVariant = Color(white: 0.18)
    
    static let cyan = Color(red: 0.0, green: 0.8, blue: 1.0)
    static let purple = Color(red: 0.6, green: 0.2, blue: 1.0)
    static let green = Color.green
    static let red = Color.red
    static let orange = Color.orange
    
    static let primaryGradient = LinearGradient(
        colors: [cyan, .blue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// RPE Helper matching your iOS Logic
struct WatchRPEHelper {
    static func getDescription(for rpe: Int) -> String {
        switch rpe {
        case 1...4: return "Could easily do 5+ more reps"
        case 5...6: return "Could do 4 more reps"
        case 7: return "Could do 3 more reps"
        case 8: return "Could do 2 more reps"
        case 9: return "Could do 1 more rep"
        case 10: return "Absolute failure. 0 reps in reserve"
        default: return "Moderate Effort"
        }
    }
    
    static func getColor(for rpe: Int) -> Color {
        switch rpe {
        case 1...4: return .green
        case 5...7: return .orange
        case 8...10: return .red
        default: return .blue
        }
    }
}
