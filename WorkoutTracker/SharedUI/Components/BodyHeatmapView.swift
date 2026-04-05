// ============================================================
// FILE: WorkoutTracker/Helpers/BodyHeatmapView.swift
// ============================================================

internal import SwiftUI

struct BodyHeatmapView: View {
    let muscleIntensities: [String: Int]
    let rawMuscleCounts: [String: Int]? // ✅ ДОБАВЛЕНО: Сырые данные для тултипов
    let isRecoveryMode: Bool
    let isCompactMode: Bool
    let userGender: String
    
    @State private var isFrontView = true
    @State private var selectedMuscleName: String? = nil
    
    let canvasWidth: CGFloat = 740
    let canvasHeight: CGFloat = 1450
    let backViewOffset: CGFloat = 740
    
    private static var cachedOffsets: [String: CGFloat] = [:]
    
    init(
        muscleIntensities: [String: Int] = [:],
        rawMuscleCounts: [String: Int]? = nil, // ✅ ДОБАВЛЕНО
        isRecoveryMode: Bool = false,
        isCompactMode: Bool = false,
        defaultToBack: Bool = false,
        userGender: String = "male"
    ) {
        self.muscleIntensities = muscleIntensities
        self.rawMuscleCounts = rawMuscleCounts
        self.isRecoveryMode = isRecoveryMode
        self.isCompactMode = isCompactMode
        self.userGender = userGender
        self._isFrontView = State(initialValue: !defaultToBack)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if !isCompactMode {
                Picker(LocalizedStringKey("View"), selection: $isFrontView) {
                    Text(LocalizedStringKey("Front")).tag(true)
                    Text(LocalizedStringKey("Back")).tag(false)
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])
                .onChange(of: isFrontView) { _, _ in
                    withAnimation { selectedMuscleName = nil }
                }
            }
            
            GeometryReader { geo in
                let scale = min(geo.size.width / canvasWidth, geo.size.height / canvasHeight)
                
                let currentMuscles: [MuscleGroup] = {
                    if userGender == "female" {
                        return isFrontView ? BodyData.frontMusclesFemale : BodyData.backMusclesFemale
                    } else {
                        return isFrontView ? BodyData.frontMuscles : BodyData.backMuscles
                    }
                }()
                
                let centeringOffset = getCenteringOffset(isFront: isFrontView)
                
                ZStack {
                    ZStack {
                        ForEach(currentMuscles) { muscle in
                            drawMuscle(muscle, centeringOffset: centeringOffset)
                        }
                    }
                    .drawingGroup() // Аппаратное ускорение Metal
                }
                .frame(width: canvasWidth, height: canvasHeight)
                .scaleEffect(scale)
                .frame(width: canvasWidth * scale, height: canvasHeight * scale)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(isCompactMode ? Color.white : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: isCompactMode ? 16 : 12))
                .overlay(alignment: .bottom) {
                    if let name = selectedMuscleName, !isCompactMode {
                        tooltipView(for: name)
                    }
                }
            }
            .frame(height: isCompactMode ? nil : 500)
            .background(
                Color(isCompactMode ? .clear : .secondarySystemBackground)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring()) {
                            selectedMuscleName = nil
                        }
                    }
            )
            .cornerRadius(isCompactMode ? 16 : 12)
        }
    }
    
    @ViewBuilder
    private func tooltipView(for name: String) -> some View {
        let slug = findSlug(forName: name)
        
        VStack(spacing: 4) {
            Text(LocalizedStringKey(name))
                .font(.headline)
                .foregroundColor(.white)
            
            if !isExceptionPart(slug) {
                if isRecoveryMode {
                    let rec = muscleIntensities[slug] ?? 100
                    Text(LocalizedStringKey("\(rec)% recovered"))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    // ✅ ИСПРАВЛЕНИЕ: Используем сырые данные для тултипа, если они есть
                    let displayCount = rawMuscleCounts?[slug] ?? muscleIntensities[slug] ?? 0
                    if displayCount > 0 {
                        Text(LocalizedStringKey("\(displayCount) sets")) // Изменили "exercises" на "sets" для точности
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.6))
        .cornerRadius(20)
        .padding(.bottom, 20)
        .transition(.scale.combined(with: .opacity))
        .allowsHitTesting(false)
    }
    
    private func getCenteringOffset(isFront: Bool) -> CGFloat {
        let key = "\(userGender)_\(isFront)"
        if let cached = Self.cachedOffsets[key] { return cached }
        
        let muscles = userGender == "female" ?
            (isFront ? BodyData.frontMusclesFemale : BodyData.backMusclesFemale) :
            (isFront ? BodyData.frontMuscles : BodyData.backMuscles)
            
        let offset = calculateCenteringOffset(for: muscles, isFront: isFront)
        Self.cachedOffsets[key] = offset
        return offset
    }
    
    func calculateCenteringOffset(for muscles: [MuscleGroup], isFront: Bool) -> CGFloat {
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
        return (canvasWidth / 2) - ((minX + maxX) / 2)
    }

    @ViewBuilder
    func drawMuscle(_ muscle: MuscleGroup, centeringOffset: CGFloat) -> some View {
        let rawPath = combinedPath(from: muscle.paths)
        let baseXOffset: CGFloat = isFrontView ? 0 : -backViewOffset
        var xOffset = baseXOffset + centeringOffset
        let finalXOffset = (isFrontView == false && muscle.slug == "head") ? xOffset + 37.0 : xOffset
        let finalPath = rawPath.offsetBy(dx: finalXOffset, dy: 0)
        let isSelected = selectedMuscleName == muscle.name
        
        Button {
            withAnimation(.spring()) {
                selectedMuscleName = muscle.name
            }
        } label: {
            ZStack {
                finalPath
                    .fill(Color.white.opacity(0.001)) // Хитбокс
                
                finalPath
                    .fill(colorForMuscle(muscle.slug, isSelected: isSelected), style: FillStyle(eoFill: false))
                    .overlay(
                        finalPath.stroke(
                            isSelected ? Color.blue : (isCompactMode ? Color.black.opacity(0.3) : Color.primary.opacity(0.15)),
                            lineWidth: isSelected ? 2.0 : (isCompactMode ? 1.5 : 1.0)
                        )
                    )
            }
        }
        .buttonStyle(.plain)
    }
    
    func colorForMuscle(_ slug: String, isSelected: Bool) -> Color {
        if isSelected { return Color.blue.opacity(0.8) }
        
        let emptyColor = isCompactMode ? Color.gray.opacity(0.2) : Color.primary.opacity(0.05)
        let hairColor = isCompactMode ? Color.black.opacity(0.8) : Color.primary.opacity(0.7)
        
        if slug == "hair" { return hairColor }
        if isExceptionPart(slug) { return emptyColor }
        
        if isRecoveryMode {
            let recovery = muscleIntensities[slug] ?? 100
            if recovery >= 100 { return emptyColor }
            else if recovery > 66 { return Color.red.opacity(0.35) }
            else if recovery > 33 { return Color.red.opacity(0.65) }
            else { return Color.red.opacity(1.0) }
        } else {
            let tension = muscleIntensities[slug] ?? 0
            if tension == 0 { return emptyColor }
            else {
                // ✅ ЗАЩИТА: Clamping opacity, чтобы никогда не выходило за рамки 0.0...1.0
                let calculatedOpacity = 0.3 + (0.7 * (Double(tension) / 100.0))
                let safeOpacity = min(1.0, max(0.0, calculatedOpacity))
                return Color.red.opacity(safeOpacity)
            }
        }
    }
    
    func combinedPath(from strings: [String]) -> Path {
        var result = Path()
        for str in strings { result.addPath(SVGParser.path(from: str)) }
        return result
    }
    
    func findSlug(forName name: String) -> String {
        let all = userGender == "female" ? (BodyData.frontMusclesFemale + BodyData.backMusclesFemale) : (BodyData.frontMuscles + BodyData.backMuscles)
        return all.first(where: { $0.name == name })?.slug ?? ""
    }
    
    func isExceptionPart(_ slug: String) -> Bool {
        return ["head", "face", "hands", "hand", "feet", "foot", "left-hand", "right-hand", "left-foot", "right-foot", "neck"].contains(slug)
    }
}
