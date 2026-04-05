//
//  ExerciseHistoryView.swift
//  WorkoutTracker
//

internal import SwiftUI
import SwiftData
import Charts

struct ExerciseHistoryView: View {
    @Environment(DIContainer.self) private var di // Добавили DI для инициализации VM
    @Environment(UnitsManager.self) var unitsManager
    @FocusState private var isInputActive: Bool
    
    let exerciseName: String // Сохраняем имя
    @State private var viewModel: ExerciseHistoryViewModel? // VM теперь опциональна до инициализации
    
    init(exerciseName: String) {
        self.exerciseName = exerciseName
    }
    
    var body: some View {
        Group {
            if let viewModel = viewModel {
                mainContent(vm: viewModel)
            } else {
                ProgressView() // Заглушка до инициализации VM
            }
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // 1. Инициализируем ViewModel через DIContainer
            if viewModel == nil {
                viewModel = di.makeExerciseHistoryViewModel(exerciseName: exerciseName)
            }
            
            // 2. Загружаем данные (убрали лишний аргумент modelContainer)
            await viewModel?.loadData(unitsManager: unitsManager)
        }
    }
    
    @ViewBuilder
    private func mainContent(vm: ExerciseHistoryViewModel) -> some View {
        VStack(spacing: 0) {
            tabBar(vm: vm)
            
            if !vm.isDataLoaded {
                Spacer()
                ProgressView(LocalizedStringKey("Loading data..."))
                    .controlSize(.large)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 30) {
                            switch vm.selectedTab {
                            case .summary: summaryContent(vm: vm)
                            case .technique: techniqueContent(vm: vm)
                            case .history: historyContent(vm: vm)
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
        .onChange(of: vm.selectedTimeRange) { _, _ in withAnimation { vm.updateGraphData() } }
        .onChange(of: vm.selectedMetric) { _, _ in withAnimation { vm.updateGraphData() } }
    }
    
    // MARK: - Tab Bar
    private func tabBar(vm: ExerciseHistoryViewModel) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(ExerciseHistoryViewModel.Tab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { vm.selectedTab = tab }
                    } label: {
                        VStack(spacing: 8) {
                            Text(tab.localizedName)
                                .font(.subheadline)
                                .fontWeight(vm.selectedTab == tab ? .semibold : .regular)
                                .foregroundColor(vm.selectedTab == tab ? .blue : .secondary)
                            Rectangle()
                                .fill(vm.selectedTab == tab ? Color.blue : Color.clear)
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
    private func summaryContent(vm: ExerciseHistoryViewModel) -> some View {
        VStack(spacing: 30) {
            chartContainerView(vm: vm)
            
            if let trend = vm.exerciseTrend {
                exerciseTrendSection(trend: trend)
            }
            if let forecast = vm.exerciseForecast {
                exerciseForecastSection(forecast: forecast)
            }
            
            ExerciseNoteEditor(exerciseName: vm.exerciseName, isInputActive: $isInputActive)
                .id("notesSection")
                .padding().background(Color(UIColor.secondarySystemBackground)).cornerRadius(12).shadow(radius: 5)
        }
    }
    
    private func techniqueContent(vm: ExerciseHistoryViewModel) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(LocalizedStringKey("Exercise Technique")).font(.title2).bold().padding(.bottom, 10)
            
            VStack(alignment: .leading, spacing: 15) {
                Text(LocalizedStringKey("How to Perform")).font(.headline).foregroundColor(.secondary)
                Text(TechniqueHelper.getDescription(for: vm.exerciseCategory)).font(.body).lineSpacing(4)
            }
            .padding().background(Color(UIColor.secondarySystemBackground)).cornerRadius(12).shadow(radius: 5)
            
            VStack(alignment: .leading, spacing: 15) {
                Text(LocalizedStringKey("Key Tips")).font(.headline).foregroundColor(.secondary)
                ForEach(TechniqueHelper.getTips(for: vm.exerciseCategory), id: \.self) { tip in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.blue).font(.caption).padding(.top, 4)
                        Text(tip).font(.body).lineSpacing(4)
                    }
                }
            }
            .padding().background(Color(UIColor.secondarySystemBackground)).cornerRadius(12).shadow(radius: 5)
            
            let targetMuscles = MuscleDisplayHelper.getTargetMuscleNames(for: vm.exerciseName, muscleGroup: vm.muscleGroup)
            if !targetMuscles.isEmpty {
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Image(systemName: "figure.strengthtraining.traditional").font(.caption).foregroundColor(.secondary)
                        Text(LocalizedStringKey("Target Muscles")).font(.headline).foregroundColor(.secondary)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                        ForEach(targetMuscles, id: \.self) { muscle in
                            NavigationLink(destination: ExerciseView(preselectedCategory: vm.muscleGroup)) {
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
    
    private func historyContent(vm: ExerciseHistoryViewModel) -> some View {
        VStack(alignment: .leading) {
            Text(LocalizedStringKey("History")).font(.title2).bold()
            
            if vm.displayedGraphData.isEmpty {
                EmptyStateView(
                    icon: "clock.fill",
                    title: LocalizedStringKey("No history yet"),
                    message: LocalizedStringKey("This exercise hasn't been performed in any workouts yet. Add it to a workout to start tracking your progress!")
                )
                .padding(.top, 20)
            } else {
                ForEach(vm.displayedGraphData.reversed()) { dataPoint in
                    historyRowContent(dataPoint: dataPoint, vm: vm)
                }
            }
        }
    }
    
    // MARK: - Components
    
    private func chartContainerView(vm: ExerciseHistoryViewModel) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text(vm.chartTitle).font(.headline).foregroundColor(.secondary)
                Spacer()
                Picker(LocalizedStringKey("Range"), selection: Binding(get: { vm.selectedTimeRange }, set: { vm.selectedTimeRange = $0 })) {
                    ForEach(ExerciseHistoryViewModel.TimeRange.allCases, id: \.self) { range in
                        Text(LocalizedStringKey(range.rawValue)).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            
            if vm.displayedGraphData.isEmpty {
                Text(LocalizedStringKey("Not enough data"))
                    .padding().frame(maxWidth: .infinity).background(Color.gray.opacity(0.1)).cornerRadius(8)
            } else {
                chartView(vm: vm)
                Divider()
                if vm.displayedGraphData.count > 1 {
                    HStack {
                        Text(LocalizedStringKey("Show line:")).font(.caption).foregroundColor(.secondary)
                        Picker(LocalizedStringKey("Metric"), selection: Binding(get: { vm.selectedMetric }, set: { vm.selectedMetric = $0 })) {
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
    
    private func chartView(vm: ExerciseHistoryViewModel) -> some View {
          Chart {
              ForEach(vm.displayedGraphData) { dataPoint in
                  if vm.displayedGraphData.count > 1 {
                      LineMark(x: .value("Date", dataPoint.date), y: .value("Value", dataPoint.value))
                          .interpolationMethod(.linear).foregroundStyle(vm.chartColor).lineStyle(StrokeStyle(lineWidth: 3))
                  }
                  PointMark(x: .value("Date", dataPoint.date), y: .value("Value", dataPoint.value))
                      .foregroundStyle(vm.chartColor).symbolSize(vm.displayedGraphData.count == 1 ? 50 : 30)
                      .annotation(position: .top) {
                          if vm.displayedGraphData.count < 10 {
                              Text(LocalizationHelper.shared.formatInteger(dataPoint.value)).font(.caption2).foregroundColor(.secondary)
                          }
                      }
              }
              
              if let val = vm.currentMetricValue, vm.displayedGraphData.count > 1 {
                  RuleMark(y: .value("Metric", val))
                      .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5])).foregroundStyle(.secondary)
                      .annotation(position: .top, alignment: .leading) {
                          Text("\(vm.selectedMetric.rawValue): \(val, format: .number.precision(.fractionLength(1))) \(vm.unitLabel)")
                              .font(.caption).bold().foregroundColor(.secondary)
                      }
              }
          }
          .frame(height: 250)
          .chartXAxis { AxisMarks(values: .automatic) { _ in AxisGridLine().foregroundStyle(.secondary.opacity(0.3)); AxisTick(); AxisValueLabel(format: .dateTime.month(.abbreviated).day()) } }
          .chartYAxis { AxisMarks { _ in AxisGridLine().foregroundStyle(.secondary.opacity(0.3)); AxisTick(); AxisValueLabel() } }
          // ✅ FIX: Fallback to including zero if there's only 1 point to prevent chart axes collapse
          .chartYScale(domain: vm.displayedGraphData.count == 1 ? .automatic(includesZero: true) : .automatic(includesZero: false))
      }
      
      @ViewBuilder
      private func historyRowContent(dataPoint: ExerciseHistoryDataPoint, vm: ExerciseHistoryViewModel) -> some View {
          // ✅ FIX: Wrapped in a NavigationLink to navigate directly to the specific Workout
          NavigationLink {
              WorkoutDetailWrapperView(workoutID: dataPoint.rawWorkoutID)
          } label: {
              HStack {
                  VStack(alignment: .leading) {
                      Text(dataPoint.date, style: .date).font(.headline).foregroundColor(.primary)
                  }
                  Spacer()
                  VStack(alignment: .trailing) {
                      Text("\(LocalizationHelper.shared.formatDecimal(dataPoint.value)) \(vm.unitLabel)")
                          .bold().foregroundColor(vm.chartColor)
                  }
                  Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray)
              }
              .padding()
              .background(Color.gray.opacity(0.05))
              .cornerRadius(10)
          }
          .buttonStyle(PlainButtonStyle())
      }

    @ViewBuilder
    private func exerciseTrendSection(trend: ExerciseTrend) -> some View {
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
    private func exerciseForecastSection(forecast: ProgressForecast) -> some View {
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
        // ИСПРАВЛЕНИЕ: Передаем persistentModelID и оборачиваем в Task
        let noteID = notes.first?.persistentModelID
        Task {
            await userStatsViewModel.saveExerciseNote(exerciseName: exerciseName, text: text, existingNoteID: noteID)
        }
    }
}
struct WorkoutDetailWrapperView: View {
    let workoutID: PersistentIdentifier
    @Environment(\.modelContext) private var context
    @Environment(DIContainer.self) private var di
    
    @State private var workout: Workout?
    
    var body: some View {
        Group {
            if let safeWorkout = workout {
                WorkoutDetailView(workout: safeWorkout, viewModel: di.makeWorkoutDetailViewModel())
            } else {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
        .onAppear {
            if let fetchedWorkout = context.model(for: workoutID) as? Workout {
                self.workout = fetchedWorkout
            }
        }
    }
}
