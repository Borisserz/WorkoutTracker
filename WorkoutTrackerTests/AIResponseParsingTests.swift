import XCTest
@testable import WorkoutTracker

final class AIResponseParsingTests: XCTestCase {

    func testExtractJSON_stripsMarkdownFences() throws {
        let raw = """
        ```json
        {"decision":"approved","reason":"ok"}
        ```
        """
        let cleaned = AIResponseParsing.extractJSONObject(from: raw)
        let data = try XCTUnwrap(cleaned.data(using: .utf8))
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(obj?["decision"] as? String, "approved")
    }

    func testExtractJSON_takesObjectWhenWrappedInProse() throws {
        let raw = """
        Sure! Here you go:
        {"weeklyScore":88,"title":"Strong","topHighlight":"Volume up","weakPointAlert":"Legs","coachAdvice":"Keep going","coachMood":"fire"}
        Hope that helps!
        """
        let cleaned = AIResponseParsing.extractJSONObject(from: raw)
        let data = try XCTUnwrap(cleaned.data(using: .utf8))
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(obj?["weeklyScore"] as? Int, 88)
        XCTAssertEqual(obj?["coachMood"] as? String, "fire")
    }

    func testIntent_explicitWorkoutPhrases() {
        XCTAssertTrue(AIIntentClassifier.wantsWorkoutPlan("Build me a push day"))
        XCTAssertTrue(AIIntentClassifier.wantsWorkoutPlan("Сгенерируй тренировку на грудь"))
        XCTAssertTrue(AIIntentClassifier.wantsWorkoutPlan("Create a 5-day program"))
        XCTAssertFalse(AIIntentClassifier.wantsWorkoutPlan("How deep should I squat?"))
        XCTAssertFalse(AIIntentClassifier.wantsWorkoutPlan("Привет"))
    }
}
