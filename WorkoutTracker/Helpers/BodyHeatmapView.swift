internal import SwiftUI

struct BodyHeatmapView: View {
    // ИЗМЕНЕНИЕ 1: Вместо Set принимаем Словарь (Мышца -> Количество повторений)
    var muscleIntensities: [String: Int]
    
    @AppStorage("userGender") private var userGender = "male"
    @State private var isFrontView = true
    @State private var selectedMuscleName: String? = nil
    
    let canvasWidth: CGFloat = 740
    let canvasHeight: CGFloat = 1450
    let backViewOffset: CGFloat = 740
    
    // ИЗМЕНЕНИЕ 2: Обновленный инициализатор
    init(muscleIntensities: [String: Int] = [:]) {
        self.muscleIntensities = muscleIntensities
    }
    
    var body: some View {
        VStack {
            Picker(LocalizedStringKey("View"), selection: $isFrontView) {
                Text(LocalizedStringKey("Front")).tag(true)
                Text(LocalizedStringKey("Back")).tag(false)
            }
            .pickerStyle(.segmented)
            .padding()
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
                        // Показываем еще и интенсивность
                        let count = muscleIntensities[name.lowercased()] ?? muscleIntensities[findSlug(forName: name)] ?? 0
                        
                        VStack(spacing: 4) {
                            Text(LocalizedStringKey(name))
                                .font(.headline)
                            if count > 0 {
                                Text(LocalizedStringKey("\(count) exercises"))
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(20)
                        .padding(.bottom, 20)
                        .transition(.scale.combined(with: .opacity))
                        
                    }
                }
            }
            .frame(height: 500)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)

        }
    }
    
    // Вычисляет автоматическое смещение для центрирования тела
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
    
   
    // --- ИЗМЕНЕНИЕ 3: ГРАДАЦИЯ ЦВЕТА ---
    func colorForMuscle(_ slug: String, isSelected: Bool) -> Color {
        if isSelected { return Color.blue.opacity(0.8) }
        if slug == "hair" { return .black.opacity(0.8) }
        
        // Получаем количество упражнений на эту мышцу
        let count = muscleIntensities[slug] ?? 0
        
        // Логика градации
        switch count {
        case 0:
            return Color.gray.opacity(0.3) // Неактивна
        case 1:
            return Color.red.opacity(0.35) // 1 упражнение (Слабо)
        case 2:
            return Color.red.opacity(0.65) // 2 упражнения (Средне)
        default:
            return Color.red.opacity(1.0)  // 3+ упражнений (Ярко/Максимум)
        }
    }
    
    func combinedPath(from strings: [String]) -> Path {
        var result = Path()
        for str in strings {
            result.addPath(SVGParser.path(from: str))
        }
        return result
    }
    
    // Вспомогательная для поиска слага по имени (для отображения текста)
    func findSlug(forName name: String) -> String {
        let all: [MuscleGroup]
        if userGender == "female" {
            all = BodyData.frontMusclesFemale + BodyData.backMusclesFemale
        } else {
            all = BodyData.frontMuscles + BodyData.backMuscles
        }
        return all.first(where: { $0.name == name })?.slug ?? ""
    }
}
