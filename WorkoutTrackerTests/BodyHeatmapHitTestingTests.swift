import Testing
import SwiftUI
@testable import WorkoutTracker

@Suite("Body Heatmap Hit Testing Tests")
struct BodyHeatmapHitTestingTests {

    private let compactScale: CGFloat = 340.0 / 1450.0
    private let nonInteractiveSlugs: Set<String> = ["hair", "head", "hands", "feet", "ankles", "knees"]

    private func computeCenteringOffset(isFront: Bool, muscles: [MuscleGroup]) -> CGFloat {
        let baseXOffset: CGFloat = isFront ? 0 : -740.0
        var minX: CGFloat = .infinity
        var maxX: CGFloat = -.infinity
        for muscle in muscles {
            if muscle.slug == "hair" || muscle.slug == "head" { continue }
            for p in muscle.paths {
                let bounds = SVGParser.path(from: p).boundingRect
                if bounds.isEmpty { continue }
                minX = min(minX, bounds.minX + baseXOffset)
                maxX = max(maxX, bounds.maxX + baseXOffset)
            }
        }
        guard minX < maxX else { return 0 }
        let contentCenter = (minX + maxX) / 2.0
        return (740.0 / 2.0) - contentCenter
    }

    private func subpathBounds(for muscle: MuscleGroup, isFront: Bool, centeringOffset: CGFloat) -> [CGRect] {
        let baseXOffset: CGFloat = isFront ? 0 : -740.0
        let xOffset = baseXOffset + centeringOffset
        return muscle.paths.compactMap { raw in
            let bounds = SVGParser.path(from: raw).offsetBy(dx: xOffset, dy: 0).boundingRect
            return bounds.isEmpty ? nil : bounds
        }
    }

    @Test("Forearm gaps and slight finger offsets reliably hit forearm at compact Overview scale")
    func testForearmGapAndFingerOffsetHitsForearm() {
        let configs: [(Bool, [MuscleGroup])] = [
            (true, BodyData.frontMuscles),
            (false, BodyData.backMuscles),
            (true, BodyData.frontMusclesFemale),
            (false, BodyData.backMusclesFemale)
        ]

        for (isFront, muscles) in configs {
            let offset = computeCenteringOffset(isFront: isFront, muscles: muscles)
            guard let forearm = muscles.first(where: { $0.slug == "forearm" }) else {
                Issue.record("Missing forearm muscle group for isFront=\(isFront)")
                continue
            }

            let leftSubpaths = subpathBounds(for: forearm, isFront: isFront, centeringOffset: offset)
                .filter { $0.midX < 370.0 }
            #expect(!leftSubpaths.isEmpty)

            // Center of each individual forearm strip
            for rect in leftSubpaths {
                let pt = CGPoint(x: rect.midX, y: rect.midY)
                let hit = BodyAnatomyHitTester.hitTest(
                    point: pt,
                    muscles: muscles,
                    isFront: isFront,
                    centeringOffset: offset,
                    scale: compactScale
                )
                #expect(hit?.slug == "forearm", "Expected forearm at subpath center \(pt) (isFront=\(isFront)), got \(hit?.slug ?? "nil")")
            }

            // Inter-strip gap + outer 8pt finger wobble (~34 canvas units) on the forearm
            if leftSubpaths.count >= 2 {
                let first = leftSubpaths[0]
                let second = leftSubpaths[1]
                let gapMid = CGPoint(x: (first.midX + second.midX) / 2.0, y: (first.midY + second.midY) / 2.0)
                let hitGap = BodyAnatomyHitTester.hitTest(
                    point: gapMid,
                    muscles: muscles,
                    isFront: isFront,
                    centeringOffset: offset,
                    scale: compactScale
                )
                #expect(hitGap?.slug == "forearm", "Expected forearm in inter-strip gap \(gapMid) (isFront=\(isFront)), got \(hitGap?.slug ?? "nil")")
            }

            if let outerLeft = leftSubpaths.min(by: { $0.minX < $1.minX }) {
                let wobblePt = CGPoint(x: outerLeft.minX - 24.0, y: outerLeft.midY)
                let hitWobble = BodyAnatomyHitTester.hitTest(
                    point: wobblePt,
                    muscles: muscles,
                    isFront: isFront,
                    centeringOffset: offset,
                    scale: compactScale
                )
                #expect(hitWobble?.slug == "forearm", "Expected forearm near outer edge \(wobblePt) (isFront=\(isFront)), got \(hitWobble?.slug ?? "nil")")
            }
        }
    }

    private func interiorPoint(in rawSVG: String, xOffset: CGFloat) -> CGPoint? {
        let path = SVGParser.path(from: rawSVG).offsetBy(dx: xOffset, dy: 0)
        let bounds = path.boundingRect
        guard !bounds.isEmpty else { return nil }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        if path.contains(center) { return center }
        for row in 1...7 {
            let y = bounds.minY + bounds.height * CGFloat(row) / 8.0
            for col in 1...7 {
                let x = bounds.minX + bounds.width * CGFloat(col) / 8.0
                let pt = CGPoint(x: x, y: y)
                if path.contains(pt) { return pt }
            }
        }
        return center
    }

    @Test("All leg muscles remain tappable across strips and outer/inner gaps at compact Overview scale")
    func testLegMusclesReliablySelectableAtCompactScale() {
        let frontLegSlugs = ["quadriceps", "adductors", "tibialis", "calves"]
        let backLegSlugs = ["gluteal", "hamstring", "adductors", "calves"]

        let configs: [(Bool, [MuscleGroup], [String])] = [
            (true, BodyData.frontMuscles, frontLegSlugs),
            (false, BodyData.backMuscles, backLegSlugs),
            (true, BodyData.frontMusclesFemale, frontLegSlugs),
            (false, BodyData.backMusclesFemale, backLegSlugs)
        ]

        for (isFront, muscles, targetSlugs) in configs {
            let offset = computeCenteringOffset(isFront: isFront, muscles: muscles)
            let baseXOffset: CGFloat = isFront ? 0 : -740.0
            let xOffset = baseXOffset + offset

            for slug in targetSlugs {
                guard let muscle = muscles.first(where: { $0.slug == slug }) else {
                    Issue.record("Missing \(slug) for isFront=\(isFront)")
                    continue
                }

                let leftPaths = muscle.paths.compactMap { raw -> (raw: String, bounds: CGRect)? in
                    let b = SVGParser.path(from: raw).offsetBy(dx: xOffset, dy: 0).boundingRect
                    return (!b.isEmpty && b.midX < 370.0) ? (raw, b) : nil
                }
                #expect(!leftPaths.isEmpty)

                // Every individual belly/strip of the leg muscle is selectable on tap
                for entry in leftPaths {
                    guard let pt = interiorPoint(in: entry.raw, xOffset: xOffset) else { continue }
                    let hit = BodyAnatomyHitTester.hitTest(
                        point: pt,
                        muscles: muscles,
                        isFront: isFront,
                        centeringOffset: offset,
                        scale: compactScale
                    )
                    #expect(hit?.slug == slug, "Expected \(slug) at interior \(pt) (isFront=\(isFront)), got \(hit?.slug ?? "nil")")
                }

                // Medial muscles (adductors) allow finger tolerance into the gap between thighs (+X toward 370);
                // outer leg muscles allow lateral finger tolerance into empty canvas (-X).
                if slug == "adductors", let medial = leftPaths.max(by: { $0.bounds.maxX < $1.bounds.maxX }) {
                    let gapTap = CGPoint(x: medial.bounds.maxX + 14.0, y: medial.bounds.midY)
                    let hit = BodyAnatomyHitTester.hitTest(
                        point: gapTap,
                        muscles: muscles,
                        isFront: isFront,
                        centeringOffset: offset,
                        scale: compactScale
                    )
                    #expect(hit?.slug == slug, "Expected adductors in medial thigh gap \(gapTap) (isFront=\(isFront)), got \(hit?.slug ?? "nil")")
                } else if (slug == "quadriceps" || slug == "hamstring" || slug == "gluteal"),
                          let outer = leftPaths.min(by: { $0.bounds.minX < $1.bounds.minX }) {
                    let edgeTap = CGPoint(x: outer.bounds.minX - 24.0, y: outer.bounds.midY)
                    let hit = BodyAnatomyHitTester.hitTest(
                        point: edgeTap,
                        muscles: muscles,
                        isFront: isFront,
                        centeringOffset: offset,
                        scale: compactScale
                    )
                    #expect(hit?.slug == slug, "Expected \(slug) on outer finger tap \(edgeTap) (isFront=\(isFront)), got \(hit?.slug ?? "nil")")
                }
            }
        }
    }

    @Test("Every interactive muscle group can be selected and decorative parts never steal taps")
    func testInteractiveMusclesAndExclusions() {
        let configs: [(Bool, [MuscleGroup])] = [
            (true, BodyData.frontMuscles),
            (false, BodyData.backMuscles),
            (true, BodyData.frontMusclesFemale),
            (false, BodyData.backMusclesFemale)
        ]

        for (isFront, muscles) in configs {
            let offset = computeCenteringOffset(isFront: isFront, muscles: muscles)
            let interactive = muscles.filter { !nonInteractiveSlugs.contains($0.slug) }

            for muscle in interactive {
                let rects = subpathBounds(for: muscle, isFront: isFront, centeringOffset: offset)
                let matchedAtAnySubpath = rects.contains { rect in
                    let hit = BodyAnatomyHitTester.hitTest(
                        point: CGPoint(x: rect.midX, y: rect.midY),
                        muscles: muscles,
                        isFront: isFront,
                        centeringOffset: offset,
                        scale: compactScale
                    )
                    return hit?.slug == muscle.slug
                }
                #expect(matchedAtAnySubpath, "Could not select \(muscle.slug) anywhere on isFront=\(isFront)")
            }

            // Head, hair, knees, hands, ankles, feet must never be returned as selected muscles
            for ignored in muscles where nonInteractiveSlugs.contains(ignored.slug) {
                for rect in subpathBounds(for: ignored, isFront: isFront, centeringOffset: offset) {
                    let hit = BodyAnatomyHitTester.hitTest(
                        point: CGPoint(x: rect.midX, y: rect.midY),
                        muscles: muscles,
                        isFront: isFront,
                        centeringOffset: offset,
                        scale: compactScale
                    )
                    #expect(!nonInteractiveSlugs.contains(hit?.slug ?? ""), "Ignored shape \(hit?.slug ?? "") should never be selectable")
                }
            }

            // Empty corners far outside body clear selection
            let cornerHit = BodyAnatomyHitTester.hitTest(
                point: CGPoint(x: 20, y: 20),
                muscles: muscles,
                isFront: isFront,
                centeringOffset: offset,
                scale: compactScale
            )
            #expect(cornerHit == nil)
        }
    }
}
