internal import SwiftUI
import SwiftData
import Charts

struct ExerciseHistoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(UnitsManager.self) var unitsManager
    @FocusState private var isInputActive: Bool
    
    @State private var viewModel: ExerciseHistoryViewModel
    
    init(exerciseName: String) {
        // Инициализируем ViewModel легким состоянием
        _viewModel = State(wrappedValue: ExerciseHistoryViewModel(exerciseName: exerciseName))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            tabBar
            
            if !viewModel.isDataLoaded {
                Spacer()
                ProgressView(LocalizedStringKey("Loading data..."))
                    .controlSize(.large)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 30) {
                            switch viewModel.selectedTab {
                            case .summary: summaryContent
                            case .technique: techniqueContent
                            case .history: historyContent
                            }
                        }
                        .padding()
                    }
                    .onChange(of: isInputActive) { _, newValue in
                        if newValue {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo("notesSection", anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(viewModel.exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // При появлении экрана просим ViewModel асинхронно стянуть данные
            await viewModel.loadData(modelContainer: context.container, unitsManager: unitsManager)
        }
        .onChange(of: viewModel.selectedTimeRange) { _, _ in withAnimation { viewModel.updateGraphData() } }
        .onChange(of: viewModel.selectedMetric) { _, _ in withAnimation { viewModel.updateGraphData() } }
    }
    
    // MARK: - Tab Bar
    private var tabBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(ExerciseHistoryViewModel.Tab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { viewModel.selectedTab = tab }
                    } label: {
                        VStack(spacing: 8) {
                            Text(tab.localizedName)
                                .font(.subheadline)
                                .fontWeight(viewModel.selectedTab == tab ? .semibold : .regular)
                                .foregroundColor(viewModel.selectedTab == tab ? .blue : .secondary)
                            Rectangle()
                                .fill(viewModel.selectedTab == tab ? Color.blue : Color.clear)
                                .frame(height: 2)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal).padding(.top, 8).padding(.bottom, 4)
            Divider()
        }
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - Tab Contents
    private var summaryContent: some View {
        VStack(spacing: 30) {
            chartContainerView
            
            if let trend = viewModel.exerciseTrend {
                exerciseTrendSection(trend: trend)
            }
            if let forecast = viewModel.exerciseForecast {
                exerciseForecastSection(forecast: forecast)
            }
            
            ExerciseNoteEditor(exerciseName: viewModel.exerciseName, isInputActive: $isInputActive)
                .id("notesSection")
                .padding().background(Color(UIColor.secondarySystemBackground)).cornerRadius(12).shadow(radius: 5)
        }
    }
    
    private var techniqueContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(LocalizedStringKey("Exercise Technique")).font(.title2).bold().padding(.bottom, 10)
            
            VStack(alignment: .leading, spacing: 15) {
                Text(LocalizedStringKey("How to Perform")).font(.headline).foregroundColor(.secondary)
                Text(TechniqueHelper.getDescription(for: viewModel.exerciseCategory)).font(.body).lineSpacing(4)
            }
            .padding().background(Color(UIColor.secondarySystemBackground)).cornerRadius(12).shadow(radius: 5)
            
            VStack(alignment: .leading, spacing: 15) {
                Text(LocalizedStringKey("Key Tips")).font(.headline).foregroundColor(.secondary)
                ForEach(TechniqueHelper.getTips(for: viewModel.exerciseCategory), id: \.self) { tip in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.blue).font(.caption).padding(.top, 4)
                        Text(tip).font(.body).lineSpacing(4)
                    }
                }
            }
            .padding().background(Color(UIColor.secondarySystemBackground)).cornerRadius(12).shadow(radius: 5)
            
            let targetMuscles = MuscleDisplayHelper.getTargetMuscleNames(for: viewModel.exerciseName, muscleGroup: viewModel.muscleGroup)
            if !targetMuscles.isEmpty {
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Image(systemName: "figure.strengthtraining.traditional").font(.caption).foregroundColor(.secondary)
                        Text(LocalizedStringKey("Target Muscles")).font(.headline).foregroundColor(.secondary)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                        ForEach(targetMuscles, id: \.self) { muscle in
                            NavigationLink(destination: ExerciseView(preselectedCategory: viewModel.muscleGroup)) {
                                HStack(spacing: 4) {
                                    Image(systemName: "figure.strengthtraining.traditional").font(.caption2)
                                    Text(muscle).font(.subheadline)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1)).foregroundColor(.blue).cornerRadius(8)
                            }
                        }
                    }
                }
                .padding().background(Color(UIColor.secondarySystemBackground)).cornerRadius(12).shadow(radius: 5)
            }
        }
    }
    
    private var historyContent: some View {
        VStack(alignment: .leading) {
            Text(LocalizedStringKey("History")).font(.title2).bold()
            
            if viewModel.displayedGraphData.isEmpty {
                EmptyStateView(
                    icon: "clock.fill",
                    title: LocalizedStringKey("No history yet"),
                    message: LocalizedStringKey("This exercise hasn't been performed in any workouts yet. Add it to a workout to start tracking your progress!")
                )
                .padding(.top, 20)
            } else {
                ForEach(viewModel.displayedGraphData.reversed()) { dataPoint in
                    historyRowContent(dataPoint: dataPoint)
                }
            }
        }
    }
    
    // MARK: - Components
    
    private var chartContainerView: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text(viewModel.chartTitle).font(.headline).foregroundColor(.secondary)
                Spacer()
                Picker(LocalizedStringKey("Range"), selection: $viewModel.selectedTimeRange) {
                    ForEach(ExerciseHistoryViewModel.TimeRange.allCases, id: \.self) { range in
                        Text(LocalizedStringKey(range.rawValue)).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            
            if viewModel.displayedGraphData.isEmpty {
                Text(LocalizedStringKey("Not enough data"))
                    .padding().frame(maxWidth: .infinity).background(Color.gray.opacity(0.1)).cornerRadius(8)
            } else {
                chartView
                Divider()
                if viewModel.displayedGraphData.count > 1 {
                    HStack {
                        Text(LocalizedStringKey("Show line:")).font(.caption).foregroundColor(.secondary)
                        Picker(LocalizedStringKey("Metric"), selection: $viewModel.selectedMetric) {
                            ForEach(ExerciseHistoryViewModel.GraphMetric.allCases, id: \.self) { metric in
                                Text(LocalizedStringKey(metric.rawValue)).tag(metric)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
        }
        .padding().background(Color(UIColor.secondarySystemBackground)).cornerRadius(12).shadow(radius: 5)
    }
    
    private var chartView: some View {
        Chart {
            ForEach(viewModel.displayedGraphData) { dataPoint in
                if viewModel.displayedGraphData.count > 1 {
                    LineMark(x: .value("Date", dataPoint.date), y: .value("Value", dataPoint.value))
                        .interpolationMethod(.linear).foregroundStyle(viewModel.chartColor).lineStyle(StrokeStyle(lineWidth: 3))
                }
                PointMark(x: .value("Date", dataPoint.date), y: .value("Value", dataPoint.value))
                    .foregroundStyle(viewModel.chartColor).symbolSize(viewModel.displayedGraphData.count == 1 ? 50 : 30)
                    .annotation(position: .top) {
                        if viewModel.displayedGraphData.count < 10 {
                            Text(LocalizationHelper.shared.formatInteger(dataPoint.value)).font(.caption2).foregroundColor(.secondary)
                        }
                    }
            }
            
            if let val = viewModel.currentMetricValue, viewModel.displayedGraphData.count > 1 {
                RuleMark(y: .value("Metric", val))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5])).foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text("\(viewModel.selectedMetric.rawValue): \(val, format: .number.precision(.fractionLength(1))) \(viewModel.unitLabel)")
                            .font(.caption).bold().foregroundColor(.secondary)
                    }
            }
        }
        .frame(height: 250)
        .chartXAxis { AxisMarks(values: .automatic) { _ in AxisGridLine().foregroundStyle(.secondary.opacity(0.3)); AxisTick(); AxisValueLabel(format: .dateTime.month(.abbreviated).day()) } }
        .chartYAxis { AxisMarks { _ in AxisGridLine().foregroundStyle(.secondary.opacity(0.3)); AxisTick(); AxisValueLabel() } }
        .chartYScale(domain: .automatic(includesZero: false))
    }
    
    @ViewBuilder
    private func historyRowContent(dataPoint: ExerciseHistoryViewModel.DataPoint) -> some View {
        // Мы не можем открыть WorkoutDetailView без самой модели Workout.
        // Чтобы не грузить модель в память, мы можем отрендерить просто строку текста.
        // Если нужен переход, потребуется реализовать FetchDescriptor по dataPoint.rawWorkoutID.
        HStack {
            VStack(alignment: .leading) {
                Text(dataPoint.date, style: .date).font(.headline).foregroundColor(.primary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("\(LocalizationHelper.shared.formatDecimal(dataPoint.value)) \(viewModel.unitLabel)")
                    .bold().foregroundColor(viewModel.chartColor)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }
    
    @ViewBuilder
    private func exerciseTrendSection(trend: WorkoutViewModel.ExerciseTrend) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(LocalizedStringKey("Exercise Trend")).font(.headline).foregroundColor(.secondary)
                Spacer()
            }
            HStack {
                Image(systemName: trend.trend.icon).foregroundColor(trend.trend.color).frame(width: 24)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        let prev = unitsManager.convertFromKilograms(trend.previousValue)
                        let curr = unitsManager.convertFromKilograms(trend.currentValue)
                        Text("\(Int(prev)) \(unitsManager.weightUnitString())").font(.caption).foregroundColor(.secondary)
                        Image(systemName: "arrow.right").font(.caption2).foregroundColor(.secondary)
                        Text("\(Int(curr)) \(unitsManager.weightUnitString())").font(.caption).bold()
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(trend.changePercentage, specifier: "%.0f")%").font(.headline).foregroundColor(trend.trend.color)
                    Text(trend.trend == .growing ? LocalizedStringKey("↑ Growing") : trend.trend == .declining ? LocalizedStringKey("↓ Declining") : LocalizedStringKey("→ Stable")).font(.caption2).foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
        .padding().background(Color(UIColor.secondarySystemBackground)).cornerRadius(12).shadow(radius: 5)
    }
    
    @ViewBuilder
    private func exerciseForecastSection(forecast: WorkoutViewModel.ProgressForecast) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(LocalizedStringKey("Progress Forecast")).font(.headline).foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(forecast.confidence >= 70 ? Color.green : forecast.confidence >= 50 ? Color.orange : Color.red).frame(width: 8, height: 8)
                    Text("\(forecast.confidence)%").font(.caption).foregroundColor(.secondary)
                }
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey("Current")).font(.caption2).foregroundColor(.secondary)
                    let cur = unitsManager.convertFromKilograms(forecast.currentMax)
                    Text("\(Int(cur)) \(unitsManager.weightUnitString())").font(.subheadline).bold()
                }
                Image(systemName: "arrow.right").foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey("Predicted")).font(.caption2).foregroundColor(.secondary)
                    let pred = unitsManager.convertFromKilograms(forecast.predictedMax)
                    Text("\(Int(pred)) \(unitsManager.weightUnitString())").font(.subheadline).bold().foregroundColor(.blue)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    let diff = unitsManager.convertFromKilograms(forecast.predictedMax - forecast.currentMax)
                    Text("+\(Int(diff)) \(unitsManager.weightUnitString())").font(.caption).bold().foregroundColor(.green)
                    Text(LocalizedStringKey("in \(forecast.timeframe)")).font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding().background(Color(UIColor.secondarySystemBackground)).cornerRadius(12).shadow(radius: 5)
    }
}

// MARK: - Isolated Note Editor View

struct ExerciseNoteEditor: View {
    let exerciseName: String
    var isInputActive: FocusState<Bool>.Binding
    
    @Environment(\.modelContext) private var context
    // ИСПРАВЛЕНИЕ: Обязательно импортируем SwiftData в файле, чтобы работал @Query
    @Query private var notes: [ExerciseNote]
    @Environment(UserStatsViewModel.self) var userStatsViewModel
    
    @State private var exerciseNote: String = ""
    @State private var saveTask: Task<Void, Never>?
    
    init(exerciseName: String, isInputActive: FocusState<Bool>.Binding) {
        self.exerciseName = exerciseName
        self.isInputActive = isInputActive
        let filter = #Predicate<ExerciseNote> { $0.exerciseName == exerciseName }
        _notes = Query(filter: filter)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey("My Notes")).font(.headline).foregroundColor(.secondary)
            
            TextEditor(text: $exerciseNote)
                .frame(minHeight: 100, maxHeight: 200)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .focused(isInputActive)
                .overlay(
                    Text(exerciseNote.isEmpty ? LocalizedStringKey("Write notes...") : "")
                        .foregroundColor(.gray.opacity(0.6))
                        .padding(12)
                        .allowsHitTesting(false),
                    alignment: .topLeading
                )
                .onChange(of: exerciseNote) { _, newValue in
                    saveTask?.cancel()
                    saveTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        if !Task.isCancelled { saveNote(newValue) }
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button(LocalizedStringKey("Done")) {
                            saveTask?.cancel()
                            saveNote(exerciseNote)
                            isInputActive.wrappedValue = false
                        }.bold()
                    }
                }
        }
        .onAppear {
            exerciseNote = notes.first?.text ?? ""
        }
    }
    
    private func saveNote(_ text: String) {
        userStatsViewModel.saveExerciseNote(exerciseName: exerciseName, text: text, existingNote: notes.first)
    }
}
