import Foundation
import UIKit

enum SisterAppStoreOpener {
    /// Resolves deep link vs App Store. `canOpenScheme` is injectable for unit tests.
    static func preferredURL(for app: SisterApp, canOpenScheme: Bool) -> URL? {
        if canOpenScheme,
           let scheme = app.urlScheme,
           let url = URL(string: scheme) {
            return url
        }
        return SisterAppsCatalog.appStoreURL(for: app)
    }

    @MainActor
    static func open(_ app: SisterApp) {
        let canOpen: Bool
        if let scheme = app.urlScheme, let url = URL(string: scheme) {
            canOpen = UIApplication.shared.canOpenURL(url)
        } else {
            canOpen = false
        }
        guard let url = preferredURL(for: app, canOpenScheme: canOpen) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
