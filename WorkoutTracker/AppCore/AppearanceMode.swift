internal import SwiftUI

/// OLED Pastel redesign is dark-only. Light/System options were left in Settings
/// but every redesigned surface forces `.dark`, so we lock appearance honestly.
enum AppearanceMode {
    static let lockedRawValue = "dark"
    static let userDefaultsKey = Constants.UserDefaultsKeys.appearanceMode.rawValue

    /// Normalize any stored preference to the only supported mode.
    static func resolved(_ raw: String?) -> String {
        lockedRawValue
    }

    static var preferredColorScheme: ColorScheme { .dark }

    /// Keep AppStorage in sync so Settings and root stay consistent.
    static func enforceLockedModeInUserDefaults(
        defaults: UserDefaults = .standard
    ) {
        if defaults.string(forKey: userDefaultsKey) != lockedRawValue {
            defaults.set(lockedRawValue, forKey: userDefaultsKey)
        }
    }
}
