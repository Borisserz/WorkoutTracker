

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
                        if let sel = selectedMuscle ?? (selectedMuscleSlug != nil ? currentMuscles.first(where: { $0.slug == selectedMuscleSlug }) : nil) {
                            drawMuscleTag(sel, centeringOffset: centeringOffset, scale: scale)
                                .transition(.scale(scale: 0.85).combined(with: .opacity))
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
            switch muscle.slug {
            case "chest": centerX -= 115; centerY -= 10
            case "deltoids": centerX += 120; centerY -= 25
            case "biceps": centerX += 125; centerY += 30
            case "abs": centerX -= 105; centerY += 40
            case "quadriceps": centerX += 110; centerY += 85
            default:
                centerX += (centerX > canvasWidth / 2 ? 100 : -100)
            }
        } else {
            switch muscle.slug {
            case "upper-back": centerX -= 115; centerY -= 10
            case "deltoids": centerX += 120; centerY -= 25
            case "triceps": centerX += 125; centerY += 35
            case "lower-back": centerX -= 105; centerY += 50
            case "gluteal": centerX += 110; centerY += 70
            case "hamstring": centerX += 110; centerY += 95
            case "calves": centerX -= 105; centerY += 115
            default:
                centerX += (centerX > canvasWidth / 2 ? 100 : -100)
            }
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
            HStack(spacing: 3 / scale) {
                Circle()
                    .fill(indicatorColor)
                    .frame(width: 4 / scale, height: 4 / scale)

                Text(LocalizedStringKey(name))
                    .font(.system(size: 9 / scale, weight: .semibold, design: .rounded))
                    .foregroundStyle(PastelTheme.textOnOat)

                Text("\(pct)%")
                    .font(.system(size: 9 / scale, weight: .bold, design: .rounded))
                    .foregroundStyle(PastelTheme.textOnOat)
            }
            .padding(.horizontal, 7 / scale)
            .padding(.vertical, 3.5 / scale)
            .background(PastelTheme.pastelOat)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.8 / scale)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 3 / scale, y: 1.5 / scale)
        }
        .buttonStyle(.plain)
        .position(x: centerX, y: centerY)
    }
}
