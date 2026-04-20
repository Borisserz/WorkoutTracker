// ============================================================
// FILE: WorkoutTracker/SharedUI/Components/BodyHeatmapView.swift
// ============================================================

internal import SwiftUI

struct BodyHeatmapView: View {
    let muscleIntensities: [String: Int]
    let rawMuscleCounts: [String: Int]?
    let isRecoveryMode: Bool
    let isCompactMode: Bool
    let defaultToBack: Bool
    let userGender: String
    let countLabel: String
    
    @State private var isFrontViewLocal = true
    @State private var selectedMuscle: MuscleGroup? = nil
    
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
        countLabel: String = "упр."
    ) {
        self.muscleIntensities = muscleIntensities
        self.rawMuscleCounts = rawMuscleCounts
        self.isRecoveryMode = isRecoveryMode
        self.isCompactMode = isCompactMode
        self.defaultToBack = defaultToBack
        self.userGender = userGender
        self.countLabel = countLabel
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
                    // 1. ОТРИСОВКА СИЛУЭТА
                    ZStack {
                        ForEach(currentMuscles) { muscle in
                            drawGhostMuscle(muscle, centeringOffset: centeringOffset)
                        }
                    }
                    .drawingGroup()
                    
                    // 2. ОТРИСОВКА ПЛАШЕК В РЕЖИМЕ ОТДЫХА ИЛИ ТРЕНИРОВКИ
                    ForEach(currentMuscles.filter { tagsToShow.contains($0.slug) }) { muscle in
                        drawMuscleTag(muscle, centeringOffset: centeringOffset, scale: scale)
                    }
                }
                .frame(width: canvasWidth, height: canvasHeight)
                .scaleEffect(scale)
                .frame(width: canvasWidth * scale, height: canvasHeight * scale)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
                
                // 3. ВСПЛЫВАЮЩАЯ НАДПИСЬ СНИЗУ С ПРОЦЕНТОМ ИЛИ УПРАЖНЕНИЯМИ
                .overlay(alignment: .bottom) {
                    if let muscle = selectedMuscle {
                        let locName = NSLocalizedString(muscle.name, comment: "")
                        let badgeColor = activeIsFront ? Color.blue : Color.red
                        
                        Group {
                            if isRecoveryMode {
                                let percent = muscleIntensities[muscle.slug] ?? 100
                                Text("\(locName): \(percent)% восстановлено")
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
    }
    
    // MARK: - Рендеринг Силуэта мышц
    func drawGhostMuscle(_ muscle: MuscleGroup, centeringOffset: CGFloat) -> some View {
        let rawPath = combinedPath(from: muscle.paths)
        let baseXOffset: CGFloat = activeIsFront ? 0 : -backViewOffset
        let xOffset = baseXOffset + centeringOffset
        let finalXOffset = (activeIsFront == false && muscle.slug == "head") ? xOffset + 37.0 : xOffset
        let finalPath = rawPath.offsetBy(dx: finalXOffset, dy: 0)
        
        let isSelected = selectedMuscle?.id == muscle.id
        let themeColor = activeIsFront ? Color.blue : Color.red
        
        let intensity = muscleIntensities[muscle.slug]
        
        // Цвет по умолчанию
        var fillColor: Color = colorScheme == .dark ? Color.white.opacity(0.12) : Color.gray.opacity(0.15)
        
        if let val = intensity {
            if isRecoveryMode {
                if val >= 95 {
                    fillColor = colorScheme == .dark ? Color.white.opacity(0.12) : Color.gray.opacity(0.15)
                } else {
                    let fatigue = 100.0 - Double(val)
                    let redOpacity = colorScheme == .dark ? (0.2 + (0.7 * (fatigue / 100.0))) : (0.1 + (0.5 * (fatigue / 100.0)))
                    fillColor = Color.red.opacity(redOpacity)
                }
            } else {
                if val > 0 {
                    let opacity = min(1.0, max(0.3, Double(val) / 100.0))
                    fillColor = themeColor.opacity(opacity)
                }
            }
        }
        
        // Подсветка при выделении
        if isSelected {
            fillColor = themeColor.opacity(0.6)
        }
           
        return Button {
            selectMuscle(muscle)
        } label: {
            ZStack {
                finalPath.fill(fillColor)
                let strokeColor = colorScheme == .dark ? Color(red: 0.13, green: 0.13, blue: 0.15) : Color.gray.opacity(0.3)
                finalPath.stroke(isSelected ? .white : strokeColor, lineWidth: isSelected ? 2 : 1.5)
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Рендеринг Плашек
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
            if muscle.slug == "chest" { centerX -= 220; centerY -= 20 }
            if muscle.slug == "deltoids" { centerX += 220; centerY -= 50 }
            if muscle.slug == "biceps" { centerX += 300; centerY += 60 }
            if muscle.slug == "abs" { centerX -= 180; centerY += 90 }
            if muscle.slug == "quadriceps" { centerX += 190; centerY += 190 }
        } else {
            if muscle.slug == "upper-back" { centerX -= 240; centerY -= 20 }
            if muscle.slug == "deltoids" { centerX += 220; centerY -= 50 }
            if muscle.slug == "triceps" { centerX += 230; centerY += 130 }
            if muscle.slug == "lower-back" { centerX -= 200; centerY += 100 }
            if muscle.slug == "hamstring" { centerX += 230; centerY += 180 }
            if muscle.slug == "calves" { centerX -= 200; centerY += 190 }
        }
        
        let isSelected = selectedMuscle?.id == muscle.id
        let themeColor = activeIsFront ? Color.blue : Color.red
        let percent = isRecoveryMode ? (muscleIntensities[muscle.slug] ?? 100) : nil
        
        return InteractiveMuscleTag(
            name: muscle.name,
            percentage: percent, // Передаем процент
            scale: scale,
            centerX: centerX,
            centerY: centerY,
            isSelected: isSelected,
            themeColor: themeColor
        ) {
            selectMuscle(muscle)
        }
    }
    
    // Общая функция выделения мышцы с авто-скрытием
    private func selectMuscle(_ muscle: MuscleGroup) {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        
        let isSelected = selectedMuscle?.id == muscle.id
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedMuscle = isSelected ? nil : muscle
        }
        
        if !isSelected {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { if selectedMuscle?.id == muscle.id { selectedMuscle = nil } }
            }
        }
    }
    
    // MARK: - Математика
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

// Плашка над мышцей
struct InteractiveMuscleTag: View {
    let name: String
    let percentage: Int?
    let scale: CGFloat
    let centerX: CGFloat
    let centerY: CGFloat
    let isSelected: Bool
    let themeColor: Color
    let action: () -> Void
    
    @State private var isFloating = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        let floatOffset = isFloating ? CGFloat(-5) : CGFloat(5)
        let delay = Double(name.count) * 0.15
        
        HStack(spacing: 4) {
            Text(LocalizedStringKey(name))
            // Показываем % на плашке, если она выделена
            if let pct = percentage, isSelected {
                Text("\(pct)%")
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .font(.system(size: 15 / scale, weight: .bold, design: .rounded))
        .foregroundColor(isSelected ? .white : (colorScheme == .dark ? .white : .black.opacity(0.8)))
        .padding(.horizontal, 16 / scale)
        .padding(.vertical, 8 / scale)
        .background(isSelected ? themeColor : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.15)))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(isSelected ? Color.clear : (colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.4)), lineWidth: 2 / scale))
        .shadow(color: isSelected ? themeColor.opacity(0.8) : .black.opacity(0.1), radius: isSelected ? 15 / scale : 5 / scale, x: 0, y: 5 / scale)
        .position(x: centerX, y: centerY)
        .offset(y: floatOffset)
        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(delay), value: isFloating)
        .onTapGesture { action() }
        .onAppear { isFloating = true }
    }
}
