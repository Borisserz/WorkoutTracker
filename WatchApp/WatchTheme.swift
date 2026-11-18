

internal import SwiftUI

struct WatchTheme {
    static let background = Color.black
    static let cardBackground = Color(white: 0.15) 
    static let buttonGray = Color(white: 0.25)     

    static let cyan = Color(red: 0.2, green: 0.8, blue: 0.9) 
    static let green = Color(red: 0.2, green: 0.85, blue: 0.3) 
    static let blue = Color(red: 0.0, green: 0.5, blue: 1.0) 
    static let red = Color(red: 0.9, green: 0.2, blue: 0.2) 
}

struct WatchRPEHelper {
    static func getDescription(for rpe: Int) -> String {
        switch rpe {
        case 1...4: return String(localized: "Could easily do 5+ more reps")
        case 5...6: return String(localized: "Could do 4 more reps")
        case 7: return String(localized: "Could've done 3 more reps")
        case 8: return String(localized: "Could've done 2 more reps")
        case 9: return String(localized: "Could've done 1 more rep")
        case 10: return String(localized: "Absolute failure. 0 reps in reserve.")
        default: return ""
        }
    }
}
