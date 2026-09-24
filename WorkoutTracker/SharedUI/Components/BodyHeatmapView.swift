

internal import SwiftUI

struct BodyHeatmapView: View {
    let muscleIntensities: [String: Int]
    let rawMuscleCounts: [String: Int]?
    let isRecoveryMode: Bool
    let isCompactMode: Bool
    let defaultToBack: Bool
    let userGender: String
    let countLabel: String
    let showLabels: Bool
    var selectedMuscleSlug: String? = nil
    var onMuscleTapped: ((MuscleGroup, Int) -> Void)? = nil

    @State private var isFrontViewLocal = true
    @State private var selectedMuscle: MuscleGroup? = nil
    @State private var animatedIntensities: [String: Int] = [:]

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) var colorScheme
    let canvasWidth: CGFloat = 740
    let canvasHeight: CGFloat = 1450
    let backViewOffset: CGFloat = 740

    private let frontTags = ["chest", "deltoids", "biceps", "abs", "quadriceps"]
    private let backTags = ["upper-back", "deltoids", "triceps", "lower-back", "hamstring", "calves"]

    private static var cachedOffsets: [String: CGFloat] = [:]

    init(
        muscleIntensities: [String: Int] = [:],
        rawMuscleCounts: [String: Int]? = nil,
        isRecoveryMode: Bool = false,
        isCompactMode: Bool = false,
        defaultToBack: Bool = false,
        userGender: String = "male",
        countLabel: String = "ex.",
        showLabels: Bool = true,
        selectedMuscleSlug: String? = nil,
        onMuscleTapped: ((MuscleGroup, Int) -> Void)? = nil
    ) {
        self.muscleIntensities = muscleIntensities
        self.rawMuscleCounts = rawMuscleCounts
        self.isRecoveryMode = isRecoveryMode
        self.isCompactMode = isCompactMode
        self.defaultToBack = defaultToBack
        self.userGender = userGender
        self.countLabel = countLabel
        self.showLabels = showLabels
        self.selectedMuscleSlug = selectedMuscleSlug
        self.onMuscleTapped = onMuscleTapped
    }

    private var activeIsFront: Bool {
        isCompactMode ? !defaultToBack : isFrontViewLocal
    }
    var body: some View {
        VStack(spacing: 0) {
            if !isCompactMode {
                Picker(LocalizedStringKey("View"), selection: $isFrontViewLocal) {
                    Text(LocalizedStringKey("Front")).tag(true)
                    Text(LocalizedStringKey("Back")).tag(false)
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])
                .onChange(of: isFrontViewLocal) { _, _ in
                    withAnimation { selectedMuscle = nil }
                }
            }

            GeometryReader { geo in
                let scale = min(geo.size.width / canvasWidth, geo.size.height / canvasHeight)
                let currentMuscles = getMuscles(isFront: activeIsFront)
                let centeringOffset = getCenteringOffset(isFront: activeIsFront, muscles: currentMuscles)
                let tagsToShow = activeIsFront ? frontTags : backTags

                ZStack {
                    // Silhouette vector paths with direct path-level hit-testing
                    ZStack {
                        ForEach(currentMuscles) { muscle in
                            drawGhostMuscle(muscle, centeringOffset: centeringOffset)
                        }
                    }

                    if showLabels {
                        ForEach(currentMuscles.filter { tagsToShow.contains($0.slug) }) { muscle in
                            drawMuscleTag(muscle, centeringOffset: centeringOffset, scale: scale)
                        }
                    }
                }
                .frame(width: canvasWidth, height: canvasHeight)
                .scaleEffect(scale)
                .frame(width: canvasWidth * scale, height: canvasHeight * scale)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
                .overlay(alignment: .bottom) {
                    if let muscle = selectedMuscle, !isCompactMode {
                        let locName = NSLocalizedString(muscle.name, comment: "")
                        let badgeColor = activeIsFront ? Color.blue : Color.red

                        Group {
                            if isRecoveryMode {
                                let percent = muscleIntensities[muscle.slug] ?? 100
                                Text("\(locName): \(percent)% restored")
                            } else {
                                let count = rawMuscleCounts?[muscle.slug] ?? 0
                                let locLabel = NSLocalizedString(countLabel, comment: "")
                                Text("\(locName): \(count) \(locLabel)")
                            }
                        }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(badgeColor.opacity(0.9))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                        .shadow(color: badgeColor.opacity(0.6), radius: 10, y: 5)
                        .padding(.bottom, 60)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .frame(height: isCompactMode ? nil : 500)
            .background(Color.clear)
        }
        .onChange(of: activeIsFront) { _, _ in
            withAnimation(.spring()) { selectedMuscle = nil }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                animatedIntensities = muscleIntensities
            }
        }
        .onChange(of: muscleIntensities) { _, newValues in
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedIntensities = newValues
            }
        }
    }

    func drawGhostMuscle(_ muscle: MuscleGroup, centeringOffset: CGFloat) -> some View {
        let rawPath = combinedPath(from: muscle.paths)
        let baseXOffset: CGFloat = activeIsFront ? 0 : -backViewOffset
        let xOffset = baseXOffset + centeringOffset
        let finalXOffset = (activeIsFront == false && muscle.slug == "head") ? xOffset + 37.0 : xOffset
        let finalPath = rawPath.offsetBy(dx: finalXOffset, dy: 0)

        let isSelected = (selectedMuscle?.id == muscle.id) || (selectedMuscleSlug == muscle.slug)
        let themeColor = activeIsFront ? Color.blue : Color.red

        let intensity = animatedIntensities[muscle.slug]

        var fillColor: Color = colorScheme == .dark ? Color.white.opacity(0.12) : Color.gray.opacity(0.15)

        if let val = intensity {
            if isRecoveryMode {
                if val >= 80 {
                    fillColor = PastelTheme.pastelSage.opacity(0.85)
                } else if val >= 55 {
                    fillColor = PastelTheme.pastelAmber.opacity(0.85)
                } else {
                    fillColor = PastelTheme.pastelPeach.opacity(0.85)
                }
            } else {
                if val > 0 {
                    let opacity = min(1.0, max(0.3, Double(val) / 100.0))
                    fillColor = themeColor.opacity(opacity)
                }
            }
        }

        if isSelected {
            fillColor = isRecoveryMode ? PastelTheme.pastelOat.opacity(0.9) : themeColor.opacity(0.6)
        }

        let strokeColor = colorScheme == .dark ? Color(red: 0.16, green: 0.17, blue: 0.20) : Color.gray.opacity(0.3)

        return ZStack {
            finalPath.fill(fillColor)
            finalPath.stroke(isSelected ? PastelTheme.pastelOat : strokeColor, lineWidth: isSelected ? 2.5 : 1.2)
        }
        .contentShape(finalPath)
        .onTapGesture {
            selectMuscle(muscle)
        }
    }

    func drawMuscleTag(_ muscle: MuscleGroup, centeringOffset: CGFloat, scale: CGFloat) -> some View {
        let rawPath = combinedPath(from: muscle.paths)
        let baseXOffset: CGFloat = activeIsFront ? 0 : -backViewOffset
        let xOffset = baseXOffset + centeringOffset
        let finalXOffset = (activeIsFront == false && muscle.slug == "head") ? xOffset + 37.0 : xOffset
        let finalPath = rawPath.offsetBy(dx: finalXOffset, dy: 0)

        let bounds = finalPath.boundingRect
        var centerX = bounds.midX
        var centerY = bounds.midY

        if activeIsFront {
            if muscle.slug == "chest" { centerX -= 140; centerY -= 10 }
            if muscle.slug == "deltoids" { centerX += 145; centerY -= 30 }
            if muscle.slug == "biceps" { centerX += 150; centerY += 40 }
            if muscle.slug == "abs" { centerX -= 130; centerY += 60 }
            if muscle.slug == "quadriceps" { centerX += 135; centerY += 120 }
        } else {
            if muscle.slug == "upper-back" { centerX -= 140; centerY -= 10 }
            if muscle.slug == "deltoids" { centerX += 145; centerY -= 30 }
            if muscle.slug == "triceps" { centerX += 150; centerY += 50 }
            if muscle.slug == "lower-back" { centerX -= 130; centerY += 70 }
            if muscle.slug == "hamstring" { centerX += 135; centerY += 130 }
            if muscle.slug == "calves" { centerX -= 130; centerY += 150 }
        }

        let isSelected = (selectedMuscle?.id == muscle.id) || (selectedMuscleSlug == muscle.slug)
        let themeColor = activeIsFront ? Color.blue : Color.red
        let percent = isRecoveryMode ? (animatedIntensities[muscle.slug] ?? 100) : nil

        return InteractiveMuscleTag(
            name: muscle.name,
            percentage: percent, 
            scale: scale,
            centerX: centerX,
            centerY: centerY,
            isSelected: isSelected,
            themeColor: themeColor
        ) {
            selectMuscle(muscle)
        }
    }

    private func selectMuscle(_ muscle: MuscleGroup) {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()

        let isCurrentlySelected = (selectedMuscle?.id == muscle.id) || (selectedMuscleSlug == muscle.slug)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedMuscle = isCurrentlySelected ? nil : muscle
        }

        let currentVal = animatedIntensities[muscle.slug] ?? 100
        onMuscleTapped?(muscle, currentVal)
    }

    private func getMuscles(isFront: Bool) -> [MuscleGroup] {
        if userGender == "female" {
            return isFront ? BodyData.frontMusclesFemale : BodyData.backMusclesFemale
        } else {
            return isFront ? BodyData.frontMuscles : BodyData.backMuscles
        }
    }

    private func getCenteringOffset(isFront: Bool, muscles: [MuscleGroup]) -> CGFloat {
        let key = "\(userGender)_\(isFront)"
        if let cached = Self.cachedOffsets[key] { return cached }

        var minX: CGFloat = .greatestFiniteMagnitude
        var maxX: CGFloat = -.greatestFiniteMagnitude

        for muscle in muscles {
            let path = combinedPath(from: muscle.paths)
            let boundingBox = path.boundingRect
            guard !boundingBox.isNull && !boundingBox.isEmpty else { continue }

            let baseOffset = isFront ? 0 : -backViewOffset
            let headOffset: CGFloat = (!isFront && muscle.slug == "head") ? 37.0 : 0.0
            let adjustedMinX = boundingBox.minX + baseOffset + headOffset
            let adjustedMaxX = boundingBox.maxX + baseOffset + headOffset

            minX = min(minX, adjustedMinX)
            maxX = max(maxX, adjustedMaxX)
        }

        guard minX != .greatestFiniteMagnitude && maxX != -.greatestFiniteMagnitude else { return 0 }
        let offset = (canvasWidth / 2) - ((minX + maxX) / 2)
        Self.cachedOffsets[key] = offset
        return offset
    }

    func combinedPath(from strings: [String]) -> Path {
        var result = Path()
        for str in strings { result.addPath(SVGParser.path(from: str)) }
        return result
    }
}

struct InteractiveMuscleTag: View {
    let name: String
    let percentage: Int?
    let scale: CGFloat
    let centerX: CGFloat
    let centerY: CGFloat
    let isSelected: Bool
    let themeColor: Color
    let action: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let pct = percentage ?? 100
        let indicatorColor: Color = pct >= 80 ? PastelTheme.pastelSage : (pct >= 55 ? PastelTheme.pastelAmber : PastelTheme.pastelPeach)

        Button {
            action()
        } label: {
            HStack(spacing: 4 / scale) {
                Circle()
                    .fill(indicatorColor)
                    .frame(width: 5 / scale, height: 5 / scale)

                Text(LocalizedStringKey(name))
                    .font(.system(size: 11 / scale, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? PastelTheme.textOnOat : (colorScheme == .dark ? Color.white.opacity(0.85) : Color.black.opacity(0.85)))

                Text("\(pct)%")
                    .font(.system(size: 11 / scale, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? PastelTheme.textOnOat : indicatorColor)
            }
            .padding(.horizontal, 9 / scale)
            .padding(.vertical, 5 / scale)
            .background(isSelected ? PastelTheme.pastelOat : (colorScheme == .dark ? Color(red: 0.11, green: 0.12, blue: 0.14).opacity(0.92) : Color.white.opacity(0.92)))
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isSelected ? PastelTheme.pastelOat : (colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.1)), lineWidth: 1 / scale)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 3 / scale, y: 2 / scale)
        }
        .buttonStyle(.plain)
        .position(x: centerX, y: centerY)
    }
}
