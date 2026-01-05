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
            Picker("View", selection: $isFrontView) {
                Text("Front").tag(true)
                Text("Back").tag(false)
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
                
                ZStack {
                    // Сначала рисуем все мышцы
                    ForEach(currentMuscles) { muscle in
                        drawMuscle(muscle)
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
                                Text("\(count) exercises")
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
    
    @ViewBuilder
    func drawMuscle(_ muscle: MuscleGroup) -> some View {
        let rawPath = combinedPath(from: muscle.paths)
        
        // Специальные смещения для центрирования женского тела
        let femaleFrontOffset: CGFloat = 25   // Передняя часть смещена влево, нужно сдвинуть вправо
        let femaleBackOffset: CGFloat = -10    // Задняя часть смещена вправо, нужно дополнительно сдвинуть влево
        
        let baseXOffset: CGFloat = isFrontView ? 0 : -backViewOffset
        let genderOffset: CGFloat = (userGender == "female") ? (isFrontView ? femaleFrontOffset : femaleBackOffset) : 0
        
        var xOffset = baseXOffset + genderOffset
        let finalXOffset = (isFrontView == false && muscle.slug == "head") ? xOffset + 37 : xOffset
        
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
                    print("Tapped: \(muscle.name) (slug: \(muscle.slug))")
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
