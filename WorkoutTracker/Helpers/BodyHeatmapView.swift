internal import SwiftUI

struct BodyHeatmapView: View {
    var muscleIntensities: [String: Int]
    var isRecoveryMode: Bool // Режим отображения восстановления
    
    @AppStorage("userGender") private var userGender = "male"
    @State private var isFrontView = true
    @State private var selectedMuscleName: String? = nil
    
    let canvasWidth: CGFloat = 740
    let canvasHeight: CGFloat = 1450
    let backViewOffset: CGFloat = 740
    
    init(
        muscleIntensities: [String: Int] = [:],
        isRecoveryMode: Bool = false
    ) {
        self.muscleIntensities = muscleIntensities
        self.isRecoveryMode = isRecoveryMode
    }
    
    var body: some View {
        VStack {
            Picker(LocalizedStringKey("View"), selection: $isFrontView) {
                Text(LocalizedStringKey("Front")).tag(true)
                Text(LocalizedStringKey("Back")).tag(false)
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])
            .onChange(of: isFrontView) { _ in
                withAnimation { selectedMuscleName = nil }
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
                
                // Вычисляем автоматическое смещение для центрирования
                let centeringOffset = calculateCenteringOffset(for: currentMuscles, isFront: isFrontView)
                
                ZStack {
                    // Сначала рисуем все мышцы
                    ForEach(currentMuscles) { muscle in
                        drawMuscle(muscle, centeringOffset: centeringOffset)
                    }
                }
                .frame(width: canvasWidth, height: canvasHeight)
                .scaleEffect(scale)
                .frame(width: canvasWidth * scale, height: canvasHeight * scale)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Плашка с именем
                .overlay(alignment: .bottom) {
                    if let name = selectedMuscleName {
                        let slug = findSlug(forName: name)
                        let count = muscleIntensities[name.lowercased()] ?? muscleIntensities[slug]
                        
                        VStack(spacing: 4) {
                            Text(LocalizedStringKey(name))
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            // Не показываем проценты или количество для исключений (голова, кисти, стопы и т.д.)
                            if !isExceptionPart(slug) {
                                if isRecoveryMode {
                                    // Режим восстановления
                                    let rec = count ?? 100
                                    Text(LocalizedStringKey("\(rec)% recovered"))
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                } else {
                                    // Режим интенсивности тренировки
                                    if let c = count, c > 0 {
                                        Text(LocalizedStringKey("\(c) exercises"))
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
                    }
                }
            }
            .frame(height: 500)
            // Обрабатываем нажатие на фон для сброса выделения
            .background(
                Color(UIColor.secondarySystemBackground)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring()) {
                            selectedMuscleName = nil
                        }
                    }
            )
            .cornerRadius(12)
        }
    }
    
    // Вычисляет смещение для центрирования тела
    func calculateCenteringOffset(for muscles: [MuscleGroup], isFront: Bool) -> CGFloat {
        var minX: CGFloat = .greatestFiniteMagnitude
        var maxX: CGFloat = -.greatestFiniteMagnitude
        
        // Вычисляем bounding box всех мышц
        for muscle in muscles {
            let path = combinedPath(from: muscle.paths)
            let cgPath = path.cgPath
            let boundingBox = cgPath.boundingBox
            
            // Пропускаем пустые пути
            guard !boundingBox.isNull && !boundingBox.isEmpty else { continue }
            
            // Учитываем смещение для заднего вида
            let baseOffset = isFront ? 0 : -backViewOffset
            
            // Учитываем специальное смещение для головы на заднем виде при вычислении bounding box
            // Это нужно для правильного центрирования всего тела
            let headOffset: CGFloat = (!isFront && muscle.slug == "head") ? 37.0 : 0.0
            
            let adjustedMinX = boundingBox.minX + baseOffset + headOffset
            let adjustedMaxX = boundingBox.maxX + baseOffset + headOffset
            
            minX = min(minX, adjustedMinX)
            maxX = max(maxX, adjustedMaxX)
        }
        
        // Если не нашли ни одной мышцы, возвращаем 0
        guard minX != .greatestFiniteMagnitude && maxX != -.greatestFiniteMagnitude else {
            return 0
        }
        
        // Вычисляем центр всех мышц
        let bodyCenterX = (minX + maxX) / 2
        
        // Вычисляем центр canvas
        let canvasCenterX = canvasWidth / 2
        
        // Возвращаем смещение, необходимое для центрирования
        return canvasCenterX - bodyCenterX
    }
    
    @ViewBuilder
    func drawMuscle(_ muscle: MuscleGroup, centeringOffset: CGFloat) -> some View {
        let rawPath = combinedPath(from: muscle.paths)
        
        let baseXOffset: CGFloat = isFrontView ? 0 : -backViewOffset
        var xOffset = baseXOffset + centeringOffset
        
        // Специальное смещение для головы на заднем виде (если нужно)
        let finalXOffset = (isFrontView == false && muscle.slug == "head") ? xOffset + 37.0 : xOffset
        
        let finalPath = rawPath.offsetBy(dx: finalXOffset, dy: 0)
        let isSelected = selectedMuscleName == muscle.name
        
        finalPath
            .fill(colorForMuscle(muscle.slug, isSelected: isSelected), style: FillStyle(eoFill: false))
            .overlay(
                finalPath.stroke(isSelected ? Color.blue : Color.black.opacity(0.15), lineWidth: isSelected ? 2.5 : 1.5)
            )
            .contentShape(Path(finalPath.cgPath))
            .onTapGesture {
                withAnimation(.spring()) {
                    selectedMuscleName = muscle.name
                }
            }
    }
    
    func colorForMuscle(_ slug: String, isSelected: Bool) -> Color {
        if isSelected { return Color.blue.opacity(0.8) }
        if slug == "hair" { return .black.opacity(0.8) }
        
        if isExceptionPart(slug) {
            // Для лица, кистей и т.п. используем базовый цвет без нагрузки
            return Color.gray.opacity(0.3)
        }
        
        if isRecoveryMode {
            let value = muscleIntensities[slug]
            // Если нет данных, считаем что мышца свежая (100%)
            let recovery = value ?? 100
            
            // Используем ту же цветовую гамму, что и в тренировках (градации красного)
            if recovery >= 100 {
                return Color.gray.opacity(0.3)
            } else if recovery > 66 {
                return Color.red.opacity(0.35)
            } else if recovery > 33 {
                return Color.red.opacity(0.65)
            } else {
                return Color.red.opacity(1.0)
            }
            
        } else {
            let count = muscleIntensities[slug] ?? 0
            switch count {
            case 0: return Color.gray.opacity(0.3)
            case 1: return Color.red.opacity(0.35)
            case 2: return Color.red.opacity(0.65)
            default: return Color.red.opacity(1.0)
            }
        }
    }
    
    func combinedPath(from strings: [String]) -> Path {
        var result = Path()
        for str in strings {
            result.addPath(SVGParser.path(from: str))
        }
        return result
    }
    
    // Вспомогательная для поиска слага по имени 
    func findSlug(forName name: String) -> String {
        let all: [MuscleGroup]
        if userGender == "female" {
            all = BodyData.frontMusclesFemale + BodyData.backMusclesFemale
        } else {
            all = BodyData.frontMuscles + BodyData.backMuscles
        }
        return all.first(where: { $0.name == name })?.slug ?? ""
    }
    
    // Определяем части тела, для которых не нужно показывать данные восстановления/нагрузки
    func isExceptionPart(_ slug: String) -> Bool {
        let exceptions: Set<String> = [
            "head", "face", "hands", "hand", "feet", "foot",
            "left-hand", "right-hand", "left-foot", "right-foot", "neck"
        ]
        return exceptions.contains(slug)
    }
}
