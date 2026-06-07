import StoreKit
internal import SwiftUI

@MainActor
final class AppReviewManager {
    static let shared = AppReviewManager()
    
    // Apple ID for the App Store (replace with actual when published)
    static let appStoreID = "6774895106"
    
    private init() {}
    
    /// Requests a review using SKStoreReviewController if appropriate.
    /// Apple limits this to 3 times per 365 days.
    static func requestAppStoreReview() {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            return
        }
        SKStoreReviewController.requestReview(in: scene)
    }
    
    /// Opens the App Store directly to the review page.
    static func openAppStoreReview() {
        let urlString = "https://apps.apple.com/app/id\(appStoreID)?action=write-review"
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}
