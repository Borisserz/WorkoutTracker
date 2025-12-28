internal import SwiftUI
import Charts

struct ExerciseHistoryView: View {
    let exerciseName: String
    let allWorkouts: [Workout]
    
    @EnvironmentObject var notesManager: ExerciseNotesManager
    @FocusState private var isInputActive: Bool
    
    @State private var selectedTimeRange: TimeRange = .all
    @State private var exerciseNote: String = ""
    
    // 1. НОВЫЙ ENUM ДЛЯ ПЕРЕКЛЮЧАТЕЛЯ ЛИНИИ
    enum GraphMetric: String, CaseIterable {
        case none = "None"
        case max = "Max"
        case average = "Average"
    }
    
    // 2. Состояние переключателя
    @State private var selectedMetric: GraphMetric = .none
    
    enum TimeRange: String, CaseIterable {
        case month = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case year = "1Y"
        case all = "All"
    }
    
    struct DataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let weight: Double
    }
    
    // --- ВЫЧИСЛЕНИЯ ДЛЯ ЛИНИИ ---
    var metricValue: Double? {
        let weights = graphData.map { $0.weight }
        guard !weights.isEmpty else { return nil }
        
        switch selectedMetric {
        case .none:
            return nil
        case .max:
            return weights.max()
        case .average:
            let total = weights.reduce(0.0, +)
            return total / Double(weights.count)
        }
    }
    
    var metricColor: Color {
        switch selectedMetric {
        case .max: return .orange
        case .average: return .purple
        default: return .clear
        }
    }
    
    // Оставляем averageWeight для текстовой подписи (как было раньше, или можно убрать, если линия дублирует)
    var averageWeight: Double {
        let weights = graphData.map { $0.weight }
        guard !weights.isEmpty else { return 0.0 }
        let total = weights.reduce(0.0, +)
        return total / Double(weights.count)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                
                // --- Секция заметок (без изменений) ---
                VStack(alignment: .leading, spacing: 10) {
                    Text("My Notes").font(.headline).foregroundColor(.secondary)
                    TextEditor(text: $exerciseNote)
                        .frame(minHeight: 100, maxHeight: 200)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .focused($isInputActive)
                        .overlay(
                            Text(exerciseNote.isEmpty ? "Write notes..." : "")
                                .foregroundColor(.gray.opacity(0.6))
                                .padding(12)
                                .allowsHitTesting(false),
                            alignment: .topLeading
                        )
                        .onChange(of: exerciseNote) { oldValue, newValue in
                            notesManager.setNote(newValue, for: exerciseName)
                        }
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done") { isInputActive = false }.bold()
                            }
                        }
                }
                .padding().background(Color.white).cornerRadius(12).shadow(radius: 5)
                
                // --- БЛОК ГРАФИКА ---
                VStack(alignment: .leading, spacing: 15) {
                    // Хедер графика
                    HStack {
                        Text("Progress").font(.headline).foregroundColor(.secondary)
                        Spacer()
                        Picker("Range", selection: $selectedTimeRange) {
                            ForEach(TimeRange.allCases, id: \.self) { range in
                                Text(LocalizedStringKey(range.rawValue)).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                    }
                    
                    if graphData.isEmpty {
                        Text("Not enough data").padding().frame(maxWidth: .infinity).background(Color.gray.opacity(0.1)).cornerRadius(8)
                    } else {
                        // 3. CHART С RULE MARK
                        Chart {
                            // Рисуем график
                            ForEach(graphData) { dataPoint in
                                LineMark(x: .value("Date", dataPoint.date), y: .value("Weight", dataPoint.weight))
                                    .interpolationMethod(.linear)
                                    .foregroundStyle(Color.blue)
                                    .lineStyle(StrokeStyle(lineWidth: 3))
                                
                                PointMark(x: .value("Date", dataPoint.date), y: .value("Weight", dataPoint.weight))
                                    .foregroundStyle(Color.blue)
                                    .symbolSize(30)
                            }
                            
                            // 4. Рисуем линию (если выбрана)
                            if let val = metricValue {
                                RuleMark(y: .value("Metric", val))
                                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                                    .foregroundStyle(metricColor)
                                    .annotation(position: .top, alignment: .leading) {
                                        Text("\(selectedMetric.rawValue): \(val, format: .number.precision(.fractionLength(1))) kg")
                                            .font(.caption).bold()
                                            .foregroundColor(metricColor)
                                    }
                            }
                        }
                        .frame(height: 250)
                        // Немного расширим ось Y, чтобы линия Max не прилипала к верху
                        .chartYScale(domain: .automatic(includesZero: false))
                        .chartXAxis {
                            AxisMarks { _ in AxisGridLine(); AxisTick(); AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true) }
                        }
                        
                        Divider()
                        
                        // 5. НИЖНИЙ ПЕРЕКЛЮЧАТЕЛЬ (Метрики)
                        HStack {
                            Text("Show line:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("Metric", selection: $selectedMetric) {
                                ForEach(GraphMetric.allCases, id: \.self) { metric in
                                    Text(LocalizedStringKey(metric.rawValue)).tag(metric)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(radius: 5)
                
                // --- Список истории (без изменений) ---
                VStack(alignment: .leading) {
                    Text("History").font(.title2).bold()
                    if filteredWorkouts.isEmpty {
                        Text("No history yet.").foregroundColor(.secondary).padding(.top, 5)
                    } else {
                        ForEach(filteredWorkouts) { workout in
                            if let exerciseObj = findExerciseInWorkout(workout) {
                                NavigationLink(destination: WorkoutDetailView(workout: .constant(workout))) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(workout.title).font(.headline).foregroundColor(.primary)
                                            Text(workout.date, style: .date).font(.caption).foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing) {
                                            Text("\(Int(exerciseObj.weight)) kg").bold().foregroundColor(.blue)
                                            Text("\(exerciseObj.sets) x \(exerciseObj.reps)").font(.caption).foregroundColor(.secondary)
                                        }
                                    }
                                    .padding().background(Color.gray.opacity(0.05)).cornerRadius(10)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(exerciseName)
        .onAppear {
            exerciseNote = notesManager.getNote(for: exerciseName)
        }
    }
    
    // ... (вспомогательные функции findExerciseInWorkout, filteredWorkouts, graphData - оставляем как были) ...
    func findExerciseInWorkout(_ workout: Workout) -> Exercise? {
        if let direct = workout.exercises.first(where: { $0.name == exerciseName && !$0.isSuperset }) {
            return direct
        }
        for ex in workout.exercises where ex.isSuperset {
            if let sub = ex.subExercises.first(where: { $0.name == exerciseName }) {
                return sub
            }
        }
        return nil
    }
    
    var filteredWorkouts: [Workout] {
        return allWorkouts.filter { workout in
            findExerciseInWorkout(workout) != nil
        }.sorted(by: { $0.date > $1.date })
    }

    var graphData: [DataPoint] {
        let allData = filteredWorkouts.reversed().compactMap { workout -> DataPoint? in
            guard let exercise = findExerciseInWorkout(workout) else { return nil }
            if exercise.weight == 0 { return nil }
            return DataPoint(date: workout.date, weight: exercise.weight)
        }
        
        if selectedTimeRange == .all { return allData }
        
        let calendar = Calendar.current
        let daysToSubtract: Int
        switch selectedTimeRange {
        case .month: daysToSubtract = 30
        case .threeMonths: daysToSubtract = 90
        case .sixMonths: daysToSubtract = 180
        case .year: daysToSubtract = 365
        default: daysToSubtract = 0
        }
        
        guard let cutoffDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: Date()) else { return allData }
        return allData.filter { $0.date >= cutoffDate }
    }
}
