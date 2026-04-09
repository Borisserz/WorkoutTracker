internal import SwiftUI

struct GeneratedWorkoutResultView: View {
    @Bindable var vm: SmartGeneratorViewModel
    @Environment(UnitsManager.self) var unitsManager
    
    // Передаем DTO!
    var onStart: ([ExerciseDTO]) -> Void
    
    private var muscleDistribution: [(String, Double)] {
            // ✅ БЕЗОПАСНОЕ извлечение .count
            let totalSets = Double(vm.generatedExercises.map { ($0.setsList ?? []).count }.reduce(0, +))
            guard totalSets > 0 else { return [] }
            var counts: [String: Double] = [:]
            // ✅ БЕЗОПАСНОЕ извлечение .count в цикле
            for ex in vm.generatedExercises { counts[ex.muscleGroup, default: 0] += Double((ex.setsList ?? []).count) }
            return counts.map { ($0.key, ($0.value / totalSets) * 100.0) }.sorted { $0.1 > $1.1 }
        }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Инфографика (БЕЗ грязного блюра, чистый фон)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Workout Focus").font(.headline).foregroundColor(.secondary)
                        
                        VStack(spacing: 12) {
                            ForEach(muscleDistribution, id: \.0) { item in
                                HStack {
                                    Text(LocalizedStringKey(item.0)).font(.subheadline).fontWeight(.semibold).frame(width: 80, alignment: .leading)
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(Color.gray.opacity(0.2))
                                            Capsule().fill(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
                                                .frame(width: geo.size.width * CGFloat(item.1 / 100.0))
                                        }
                                    }.frame(height: 8)
                                    Text("\(Int(item.1))%").font(.caption).bold().frame(width: 40, alignment: .trailing)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(24)
                    .padding(.horizontal)
                    
                    // Список упражнений
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Exercises").font(.title3).bold().padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            ForEach(vm.generatedExercises, id: \.name) { ex in
                                HStack(spacing: 16) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12).fill(Color.cyan.opacity(0.15)).frame(width: 50, height: 50)
                                        Image(systemName: ex.type == .strength ? "dumbbell.fill" : "figure.run").foregroundColor(.cyan)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(LocalizationHelper.shared.translateName(ex.name)).font(.headline)
                                        Text(LocalizedStringKey(ex.muscleGroup)).font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    
                                    // Умное форматирование в зависимости от типа
                                    VStack(alignment: .trailing, spacing: 4) {
                                                                        // ✅ ИСПРАВЛЕНО: Безопасное извлечение подходов и повторений
                                                                        let safeSets = ex.setsList ?? []
                                                                        let reps = safeSets.first?.reps ?? 10
                                                                        let weight = safeSets.first?.weight ?? 0.0
                                                                        
                                                                        if ex.type == .strength {
                                                                            Text("\(safeSets.count)x\(reps)")
                                                                                .font(.subheadline).bold()
                                                                            
                                                                            if weight > 0 {
                                                                                let conv = unitsManager.convertFromKilograms(weight)
                                                                                Text("\(Int(conv)) \(unitsManager.weightUnitString())")
                                                                                    .font(.caption).foregroundColor(.cyan)
                                                                            }
                                                                        } else {
                                                                            // Если кардио/время
                                                                            let timeSec = safeSets.first?.time ?? 0
                                                                            Text("\(timeSec / 60) min")
                                                                                .font(.subheadline).bold()
                                                                        }
                                                                    }
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(16)
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical, 24)
                .padding(.bottom, 120)
            }
            
            VStack {
                Spacer()
                Button {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    onStart(vm.generatedExercises) // Отдаем DTO обратно
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "bolt.fill").font(.title2)
                        Text("START WORKOUT").font(.title3).bold().tracking(1.5)
                    }
                    .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 20)
                    .background(Color.blue)
                    .clipShape(Capsule())
                    .shadow(color: .blue.opacity(0.5), radius: 20, x: 0, y: 10)
                    .padding(.horizontal, 24)
                }
            }
            .padding(.bottom, 16)
            // ✅ ИСПРАВЛЕНИЕ: Убрали прозрачный градиент, который перекрывал список (пленку)
        }
        .navigationTitle("Your Routine")
        .navigationBarTitleDisplayMode(.inline)
    }
}
