import Testing
@testable import WorkoutTracker
import Foundation

@Suite("App Review Manager")
struct AppReviewManagerTests {

    @Test("Product page URL has no write-review action")
    func productPageURL() {
        let id = AppReviewManager.appStoreID
        let product = "https://apps.apple.com/app/id\(id)"
        let review = "https://apps.apple.com/app/id\(id)?action=write-review"
        #expect(!product.contains("write-review"))
        #expect(review.contains("write-review"))
        #expect(product.hasSuffix(id))
    }
}
