import XCTest

final class LocalizationCatalogTests: XCTestCase {

    func testActiveEnglishKeysHaveShippedLocales() throws {
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("WorkoutTracker/Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(root["strings"] as? [String: Any])
        let shipped = ["de", "es", "fr", "it", "pt-PT", "ru"]

        var gaps: [String] = []
        for (key, raw) in strings {
            guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            guard let entry = raw as? [String: Any] else { continue }
            if entry["extractionState"] as? String == "stale" { continue }
            if key.unicodeScalars.contains(where: { (0x0400...0x04FF).contains($0.value) }) { continue }

            let locs = entry["localizations"] as? [String: Any] ?? [:]
            var missing: [String] = []
            for lang in shipped {
                let langEntry = locs[lang] as? [String: Any]
                let unit = langEntry?["stringUnit"] as? [String: Any]
                let value = unit?["value"] as? String
                if value == nil || value?.isEmpty == true {
                    missing.append(lang)
                }
            }
            if !missing.isEmpty {
                gaps.append("\(missing.joined(separator: ",")) | \(key)")
            }
        }

        gaps.sort()
        if !gaps.isEmpty {
            XCTFail("Missing translations (\(gaps.count)):\n\(gaps.prefix(8).joined(separator: "\n"))")
        }
    }
}
