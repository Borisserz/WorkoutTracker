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
    @State private var selectedMuscleName: String? = nil
    
    @Environment(ThemeManager.self) private var themeManager
    
    let canvasWidth: CGFloat = 740
    let canvasHeight: CGFloat = 1450
    let backViewOffset: CGFloat = 740
    
    // ✅ ДОБАВЛЕНЫ "calves" (Икры) ДЛЯ ВИДА СЗАДИ
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
        countLabel: String = "sets"
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
                    withAnimation { selectedMuscleName = nil }
                }
            }
            
            GeometryReader { geo in
                let scale = min(geo.size.width / canvasWidth, geo.size.height / canvasHeight)
                let currentMuscles = getMuscles(isFront: activeIsFront)
                let centeringOffset = getCenteringOffset(isFront: activeIsFront, muscles: currentMuscles)
                let tagsToShow = activeIsFront ? frontTags : backTags
                
                ZStack {
                    // 1. ОТРИСОВКА СИЛУЭТА (На него можно нажимать)
                    ZStack {
                        ForEach(currentMuscles) { muscle in
                            drawGhostMuscle(muscle, centeringOffset: centeringOffset)
                        }
                    }
                    .drawingGroup()
                    
                    // 2. ОТРИСОВКА ИНТЕРАКТИВНЫХ ПЛАШЕК
                    if isRecoveryMode {
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
                
                // 3. ВСПЛЫВАЮЩАЯ НАДПИСЬ СНИЗУ (для мышц без плашек)
                .overlay(alignment: .bottom) {
                    if let name = selectedMuscleName {
                        Text(LocalizedStringKey(name))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(activeIsFront ? Color.blue.opacity(0.8) : Color.red.opacity(0.8))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                            .shadow(color: (activeIsFront ? Color.blue : Color.red).opacity(0.6), radius: 10, y: 5)
                            .padding(.bottom, 60) // ✅ ПОДНЯЛИ ВЫШЕ, чтобы не резалась краем экрана
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .frame(height: isCompactMode ? nil : 500)
            .background(Color.clear)
        }
        // Сбрасываем выделение при перевороте модели
        .onChange(of: activeIsFront) { _, _ in
            withAnimation(.spring()) { selectedMuscleName = nil }
        }
    }
    
    // MARK: - Рендеринг Силуэта мышц (С нажатием)
    func drawGhostMuscle(_ muscle: MuscleGroup, centeringOffset: CGFloat) -> some View {
          let rawPath = combinedPath(from: muscle.paths)
          let baseXOffset: CGFloat = activeIsFront ? 0 : -backViewOffset
          let xOffset = baseXOffset + centeringOffset
          let finalXOffset = (activeIsFront == false && muscle.slug == "head") ? xOffset + 37.0 : xOffset
          let finalPath = rawPath.offsetBy(dx: finalXOffset, dy: 0)
          
          let isSelected = selectedMuscleName == muscle.name
          let themeColor = activeIsFront ? Color.blue : Color.red
          
          let intensity = muscleIntensities[muscle.slug]
          var fillColor: Color = Color.white.opacity(0.12) // Базовый серый цвет
          
          if let val = intensity {
              if isRecoveryMode {
                  // РЕЖИМ ВОССТАНОВЛЕНИЯ (100 = Свежая, 0 = Убита)
                  if val >= 95 {
                      // Мышца полностью восстановлена -> оставляем серый цвет
                      fillColor = Color.white.opacity(0.12)
                  } else {
                      // Вычисляем процент усталости (чем меньше val, тем больше усталость)
                      let fatigue = 100.0 - Double(val)
                      // Чем больше усталость, тем плотнее и ярче красный цвет (от 0.2 до 0.9)
                      let redOpacity = 0.2 + (0.7 * (fatigue / 100.0))
                      fillColor = Color.red.opacity(redOpacity)
                  }
              } else {
                  // РЕЖИМ НАГРУЗКИ / ТРЕНИРОВКИ (LIVE TENSION) (0 = Отдыхает, 100 = Памп)
                  if val > 0 {
                      let opacity = min(1.0, max(0.3, Double(val) / 100.0))
                      fillColor = themeColor.opacity(opacity)
                  }
              }
          }
          
          // Если пользователь тапнул на мышцу — подсвечиваем её ярко синим/красным
          if isSelected {
              fillColor = themeColor.opacity(0.8)
          }
          
          return Button {
              let generator = UISelectionFeedbackGenerator()
              generator.selectionChanged()
              withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                  selectedMuscleName = isSelected ? nil : muscle.name
              }
          } label: {
              ZStack {
                  finalPath.fill(fillColor)
                  
                  if isSelected {
                      finalPath.stroke(themeColor, lineWidth: 3.0)
                          .shadow(color: themeColor.opacity(0.8), radius: 10)
                  } else {
                      // Контур мышц
                      finalPath.stroke(Color(red: 0.13, green: 0.13, blue: 0.15), lineWidth: 1.5)
                  }
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
        
        // ✅ ЖЕСТКИЙ РАЗНОС ПЛАШЕК В СТОРОНЫ (Чтобы тело было видно на 100%)
        if activeIsFront {
            if muscle.slug == "chest" { centerX -= 220; centerY -= 20 }         // Грудь левее
            if muscle.slug == "deltoids" { centerX += 220; centerY -= 50 }      // Плечи справа
            if muscle.slug == "biceps" { centerX += 300; centerY += 60 }        // Бицепс правее
            if muscle.slug == "abs" { centerX -= 180; centerY += 90 }           // Пресс левее
            if muscle.slug == "quadriceps" { centerX += 190; centerY += 190 }   // Квадры правее
        } else {
            if muscle.slug == "upper-back" { centerX -= 240; centerY -= 20 }    // Верх спины левее
            if muscle.slug == "deltoids" { centerX += 220; centerY -= 50 }      // Плечи справа
            if muscle.slug == "triceps" { centerX += 230; centerY += 130 }      // Трицепс правее и НИЖЕ
            if muscle.slug == "lower-back" { centerX -= 200; centerY += 100 }   // Поясница левее
            if muscle.slug == "hamstring" { centerX += 230; centerY += 180 }    // Бицепс бедра правее
            if muscle.slug == "calves" { centerX -= 200; centerY += 190 }       // Икры слева в самом низу
        }
        
        let isSelected = selectedMuscleName == muscle.name
        let themeColor = activeIsFront ? Color.blue : Color.red
        
        return InteractiveMuscleTag(
            name: muscle.name,
            scale: scale,
            centerX: centerX,
            centerY: centerY,
            isSelected: isSelected,
            themeColor: themeColor
        ) {
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedMuscleName = isSelected ? nil : muscle.name
            }
        }
    }
    
    // MARK: - Математика и Хелперы
    
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
    
    func findSlug(forName name: String) -> String {
        let all = userGender == "female" ? (BodyData.frontMusclesFemale + BodyData.backMusclesFemale) : (BodyData.frontMuscles + BodyData.backMuscles)
        return all.first(where: { $0.name == name })?.slug ?? ""
    }
    
    func isExceptionPart(_ slug: String) -> Bool {
        return ["head", "face", "hands", "hand", "feet", "foot", "left-hand", "right-hand", "left-foot", "right-foot", "neck"].contains(slug)
    }
}

// MARK: - ИЗОЛИРОВАННАЯ ПЛАШКА ДЛЯ БЕСКОНЕЧНОЙ АНИМАЦИИ
struct InteractiveMuscleTag: View {
    let name: String
    let scale: CGFloat
    let centerX: CGFloat
    let centerY: CGFloat
    let isSelected: Bool
    let themeColor: Color
    let action: () -> Void
    
    @State private var isFloating = false
    
    var body: some View {
        let floatOffset = isFloating ? CGFloat(-5) : CGFloat(5)
        let delay = Double(name.count) * 0.15 // У каждой плашки свой рассинхрон
        
        Text(LocalizedStringKey(name))
            // ✅ УМЕНЬШЕНЫ РАЗМЕР ШРИФТА И ПАДДИНГИ ДЛЯ АККУРАТНОСТИ
            .font(.system(size: 15 / scale, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 16 / scale)
            .padding(.vertical, 8 / scale)
            .background(isSelected ? themeColor : Color.white.opacity(0.1))
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isSelected ? Color.clear : Color.white.opacity(0.3), lineWidth: 2 / scale)
            )
            .shadow(color: isSelected ? themeColor.opacity(0.8) : .black.opacity(0.3), radius: isSelected ? 15 / scale : 5 / scale, x: 0, y: 5 / scale)
            .position(x: centerX, y: centerY)
            .offset(y: floatOffset)
            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(delay), value: isFloating)
            .onTapGesture { action() }
            .onAppear {
                isFloating = true
            }
    }
}
