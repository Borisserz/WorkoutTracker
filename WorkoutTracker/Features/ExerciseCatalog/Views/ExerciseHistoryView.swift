// MARK: - Imports
internal import SwiftUI
import SwiftData
import Charts

// MARK: - Main View
struct ExerciseHistoryView: View {
    @Environment(DIContainer.self) private var di
    @Environment(UnitsManager.self) var unitsManager
    @FocusState private var isInputActive: Bool
    
    let exerciseName: String
    @State private var viewModel: ExerciseHistoryViewModel?
    
    // Namespace for custom tab picker animation
    @Namespace private var tabNamespace
    // For chart interactivity
    @State private var selectedX: Date?
    
    init(exerciseName: String) {
        self.exerciseName = exerciseName
    }
    
    var body: some View {
        Group {
            if let viewModel = viewModel {
                mainContent(vm: viewModel)
            } else {
                ProgressView()
                    .controlSize(.large)
            }
        }
        .navigationTitle(LocalizationHelper.shared.translateName(exerciseName))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                viewModel = di.makeExerciseHistoryViewModel(exerciseName: exerciseName)
            }
            await viewModel?.loadData(unitsManager: unitsManager)
        }
    }
    
    @ViewBuilder
    private func mainContent(vm: ExerciseHistoryViewModel) -> some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                customTabBar(vm: vm)
                
                if !vm.isDataLoaded {
                    Spacer()
                    ProgressView(LocalizedStringKey("Loading data..."))
                        .controlSize(.large)
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 24) {
                                switch vm.selectedTab {
                                case .summary: summaryContent(vm: vm)
                                case .technique: techniqueContent(vm: vm)
                                case .oneRepMax: OneRepMaxTabView(vm: vm)
                                case .history: historyContent(vm: vm)
                                
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 20)
                            .padding(.bottom, 60)
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
        }
        .onChange(of: vm.selectedTimeRange) { _, _ in withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { vm.updateGraphData() } }
        .onChange(of: vm.selectedMetric) { _, _ in withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { vm.updateGraphData() } }
    }
    
    // MARK: - Modern Tab Picker
    private func customTabBar(vm: ExerciseHistoryViewModel) -> some View {
            HStack(spacing: 0) {
                ForEach(ExerciseHistoryViewModel.Tab.allCases, id: \.self) { tab in
                    // ✅ ПРОВЕРКА: Скрываем 1RM для несиловых тренировок
                    if tab == .oneRepMax && vm.exerciseType != .strength {
                        EmptyView()
                    } else {
                        let isSelected = vm.selectedTab == tab
                        
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                vm.selectedTab = tab
                            }
                        } label: {
                            Text(tab.localizedName)
                                .font(.subheadline)
                                .fontWeight(isSelected ? .bold : .medium)
                                .foregroundColor(isSelected ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background {
                                    if isSelected {
                                        Capsule()
                                            .fill(vm.chartColor)
                                            .matchedGeometryEffect(id: "activeTab", in: tabNamespace)
                                            .shadow(color: vm.chartColor.opacity(0.3), radius: 5, x: 0, y: 2)
                                    }
                                }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        .padding(4)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    // MARK: - Tab Contents
    private func summaryContent(vm: ExerciseHistoryViewModel) -> some View {
           VStack(spacing: 24) {
               proChartContainerView(vm: vm)
               
               if let trend = vm.exerciseTrend {
                   proExerciseTrendSection(trend: trend)
               }
               
               if let forecast = vm.exerciseForecast {
                   proForecastSection(forecast: forecast)
               }
               
               // ✅ ДОБАВЛЕНО: Интеграция нового блока Personal Records
               if let records = vm.personalRecords, vm.exerciseType == .strength {
                   PersonalRecordsCardView(records: records)
               }
               
               ExerciseNoteEditor(exerciseName: vm.exerciseName, isInputActive: $isInputActive)
                   .id("notesSection")
           }
       }

    
    private func techniqueContent(vm: ExerciseHistoryViewModel) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(LocalizedStringKey("Exercise Technique"))
                .font(.title2)
                .bold()
                .padding(.bottom, 4)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "book.pages.fill")
                        .foregroundColor(vm.chartColor)
                    Text(LocalizedStringKey("How to Perform"))
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                Text(TechniqueHelper.getDescription(for: vm.exerciseCategory))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineSpacing(6)
            }
            .padding(20)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 5)
            
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text(LocalizedStringKey("Key Tips"))
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                ForEach(TechniqueHelper.getTips(for: vm.exerciseCategory), id: \.self) { tip in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(vm.chartColor)
                            .font(.body)
                            .padding(.top, 2)
                        Text(tip)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                    }
                }
            }
            .padding(20)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 5)
            
            let targetMuscles = MuscleDisplayHelper.getTargetMuscleNames(for: vm.exerciseName, muscleGroup: vm.muscleGroup)
            if !vm.primaryMuscles.isEmpty {
                         VStack(alignment: .leading, spacing: 16) {
                             HStack(spacing: 8) {
                                 Image(systemName: "figure.strengthtraining.traditional").foregroundColor(vm.chartColor)
                                 Text(LocalizedStringKey("Target (Primary) Muscles")).font(.headline).foregroundColor(.primary)
                             }
                             
                             // Теги с мышцами
                             ScrollView(.horizontal, showsIndicators: false) {
                                 HStack(spacing: 10) {
                                     ForEach(vm.primaryMuscles, id: \.self) { muscle in
                                         HStack(spacing: 6) {
                                             Circle().fill(vm.chartColor).frame(width: 8, height: 8)
                                             Text(LocalizedStringKey(muscle.capitalized))
                                                 .font(.subheadline).fontWeight(.semibold)
                                         }
                                         .padding(.horizontal, 14).padding(.vertical, 10)
                                         .background(vm.chartColor.opacity(0.15))
                                         .foregroundColor(vm.chartColor)
                                         .cornerRadius(12)
                                     }
                                 }
                             }
                         }
                         .padding(20)
                         .background(Color(UIColor.secondarySystemGroupedBackground))
                         .cornerRadius(20)
                         .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 5)
                     }
                     
                     // ✅ Блок: ВТОРОСТЕПЕННЫЕ МЫШЦЫ (Secondary)
                     if !vm.secondaryMuscles.isEmpty {
                         VStack(alignment: .leading, spacing: 16) {
                             HStack(spacing: 8) {
                                 Image(systemName: "figure.mixed.cardio").foregroundColor(.orange)
                                 Text(LocalizedStringKey("Synergist (Secondary) Muscles")).font(.headline).foregroundColor(.primary)
                             }
                             
                             // Теги с мышцами
                             ScrollView(.horizontal, showsIndicators: false) {
                                 HStack(spacing: 10) {
                                     ForEach(vm.secondaryMuscles, id: \.self) { muscle in
                                         HStack(spacing: 6) {
                                             Circle().fill(Color.orange).frame(width: 6, height: 6)
                                             Text(LocalizedStringKey(muscle.capitalized))
                                                 .font(.subheadline).fontWeight(.medium)
                                         }
                                         .padding(.horizontal, 14).padding(.vertical, 10)
                                         .background(Color.orange.opacity(0.1))
                                         .foregroundColor(.orange)
                                         .cornerRadius(12)
                                     }
                                 }
                             }
                         }
                         .padding(20)
                         .background(Color(UIColor.secondarySystemGroupedBackground))
                         .cornerRadius(20)
                         .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 5)
                     }
                 }
             }
    private func historyContent(vm: ExerciseHistoryViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedStringKey("History"))
                .font(.title2)
                .bold()
                .padding(.bottom, 4)
            
            if vm.displayedGraphData.isEmpty {
                EmptyStateView(
                    icon: "clock.fill",
                    title: LocalizedStringKey("No history yet"),
                    message: LocalizedStringKey("This exercise hasn't been performed in any workouts yet. Add it to a workout to start tracking your progress!"),
                    iconColor: vm.chartColor.opacity(0.5)
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(vm.displayedGraphData.reversed()) { dataPoint in
                        proHistoryRowContent(dataPoint: dataPoint, vm: vm)
                    }
                }
            }
        }
    }
    
    // MARK: - Pro Chart Components
    
    private func proChartContainerView(vm: ExerciseHistoryViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header & Metric Picker
            HStack {
                Text(vm.chartTitle)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if vm.displayedGraphData.count > 1 {
                    Menu {
                        ForEach(ExerciseHistoryViewModel.GraphMetric.allCases, id: \.self) { metric in
                            Button(LocalizedStringKey(metric.rawValue)) {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                vm.selectedMetric = metric
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(LocalizedStringKey(vm.selectedMetric.rawValue))
                            Image(systemName: "chevron.up.chevron.down")
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(UIColor.tertiarySystemFill))
                        .foregroundColor(.primary)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Interactive Chart
            if vm.displayedGraphData.isEmpty {
                Text(LocalizedStringKey("Not enough data"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .background(Color(UIColor.tertiarySystemFill).opacity(0.5))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
            } else {
                proChartView(vm: vm)
                    .padding(.horizontal, 20)
            }
            
            // Time Range Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Spacer().frame(width: 10)
                    ForEach(ExerciseHistoryViewModel.TimeRange.allCases, id: \.self) { range in
                        let isSelected = vm.selectedTimeRange == range
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            vm.selectedTimeRange = range
                        } label: {
                            Text(LocalizedStringKey(range.rawValue))
                                .font(.caption)
                                .fontWeight(isSelected ? .bold : .medium)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(isSelected ? vm.chartColor : Color(UIColor.tertiarySystemFill))
                                .foregroundColor(isSelected ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    Spacer().frame(width: 10)
                }
            }
            .padding(.bottom, 20)
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.04), radius: 15, x: 0, y: 5)
    }
    
  
    private func proChartView(vm: ExerciseHistoryViewModel) -> some View {
        // Вычисляем динамический размер осей, чтобы тултипы никогда не обрезались
        let minVal = vm.displayedGraphData.map { $0.value }.min() ?? 0
        let maxVal = vm.displayedGraphData.map { $0.value }.max() ?? 10
        let diff = maxVal - minVal
        let yPadding = diff == 0 ? (maxVal == 0 ? 10 : maxVal * 0.4) : diff * 0.4
        let yDomainMin = max(0, minVal - (diff == 0 ? 0 : diff * 0.1))
        let yDomainMax = maxVal + yPadding
        
        return Chart {
            ForEach(vm.displayedGraphData) { dataPoint in
                if vm.displayedGraphData.count > 1 {
                    // Главная линия тренда (Без заливки)
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Value", dataPoint.value)
                    )
                    .foregroundStyle(vm.chartColor)
                    .interpolationMethod(.catmullRom)
                    // Чуть толще основная линия для большей четкости
                    .lineStyle(StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                }
                
                // Рисуем точки ТОЛЬКО если данных мало (чтобы не было "каши")
                if vm.displayedGraphData.count < 20 {
                    PointMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Value", dataPoint.value)
                    )
                    .symbol {
                        Circle()
                            .fill(Color(UIColor.systemBackground))
                            .frame(width: vm.displayedGraphData.count == 1 ? 16 : 10, height: vm.displayedGraphData.count == 1 ? 16 : 10)
                            .overlay(
                                Circle().stroke(vm.chartColor, lineWidth: 3)
                            )
                            .shadow(color: vm.chartColor.opacity(0.4), radius: 4, x: 0, y: 2)
                    }
                }
            }
            
            // Четкая пунктирная линия Average / Max
            if let val = vm.currentMetricValue, vm.displayedGraphData.count > 1, vm.selectedMetric != .none {
                RuleMark(y: .value("Metric", val))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .foregroundStyle(Color.primary.opacity(0.3))
                    .annotation(position: .top, alignment: .leading) {
                        Text("\(val, format: .number.precision(.fractionLength(1))) \(vm.unitLabel)")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(UIColor.systemBackground).opacity(0.95))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.15), lineWidth: 1))
                    }
            }
            
            // Выбранная точка (Tooltip)
            if let selectedDate = selectedX {
                if let closestPoint = vm.displayedGraphData.min(by: { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }) {
                    RuleMark(x: .value("Selected", closestPoint.date))
                        .foregroundStyle(Color.primary.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4]))
                        .annotation(position: .top) {
                            VStack(alignment: .center, spacing: 2) {
                                Text("\(LocalizationHelper.shared.formatDecimal(closestPoint.value)) \(vm.unitLabel)")
                                    .font(.headline)
                                    .bold()
                                    .foregroundColor(Color(UIColor.systemBackground))
                                Text(closestPoint.date, format: .dateTime.month(.abbreviated).day())
                                    .font(.caption)
                                    .foregroundColor(Color(UIColor.systemBackground).opacity(0.8))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(UIColor.label).opacity(0.9))
                            .cornerRadius(8)
                            .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                        }
                }
            }
        }
        .frame(height: 240)
        .chartXSelection(value: $selectedX)
        .chartXScale(range: .plotDimension(padding: 15))
        .chartYScale(domain: yDomainMin...yDomainMax, range: .plotDimension(padding: 15))
        // Настройка осей и сетки
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Color.gray.opacity(0.3))
                AxisTick()
                    .foregroundStyle(Color.gray.opacity(0.5))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
                    .foregroundStyle(Color.primary.opacity(0.7))
                    .font(.caption2.bold())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Color.gray.opacity(0.3))
                AxisTick()
                    .foregroundStyle(Color.gray.opacity(0.5))
                AxisValueLabel()
                    .foregroundStyle(Color.primary.opacity(0.7))
                    .font(.caption2.bold())
            }
        }
    }
    // MARK: - Widget-Style Cards
    
    @ViewBuilder
    private func proExerciseTrendSection(trend: ExerciseTrend) -> some View {
        let isGrowing = trend.trend == .growing
        let isDeclining = trend.trend == .declining
        let glowColor = isGrowing ? Color.green : (isDeclining ? Color.red : Color.orange)
        
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(LocalizedStringKey("Exercise Trend"))
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: trend.trend.icon)
                        .font(.caption.bold())
                    Text(isGrowing ? LocalizedStringKey("↑ Growing") : isDeclining ? LocalizedStringKey("↓ Declining") : LocalizedStringKey("→ Stable"))
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .foregroundColor(glowColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(glowColor.opacity(0.15))
                .clipShape(Capsule())
            }
            
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("Previous"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    let prev = unitsManager.convertFromKilograms(trend.previousValue)
                    Text("\(LocalizationHelper.shared.formatInteger(prev))")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.gray.opacity(0.5))
                    .font(.title3)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(LocalizedStringKey("Current"))
                        .font(.caption2)
                        .foregroundColor(glowColor)
                        .textCase(.uppercase)
                    let curr = unitsManager.convertFromKilograms(trend.currentValue)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(LocalizationHelper.shared.formatInteger(curr))")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                        Text(unitsManager.weightUnitString())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Divider().opacity(0.5)
            
            HStack {
                Text(LocalizedStringKey("Overall Progress"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(trend.changePercentage > 0 ? "+" : "")\(trend.changePercentage, specifier: "%.1f")%")
                    .font(.headline)
                    .fontWeight(.heavy)
                    .foregroundColor(glowColor)
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(24)
        .shadow(color: glowColor.opacity(0.15), radius: 15, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(glowColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func proForecastSection(forecast: ProgressForecast) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(LocalizedStringKey("AI Forecast"))
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                    Text("\(forecast.confidence)% Confidence")
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .foregroundColor(.purple)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.purple.opacity(0.15))
                .clipShape(Capsule())
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("Current 1RM"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    let cur = unitsManager.convertFromKilograms(forecast.currentMax)
                    Text("\(LocalizationHelper.shared.formatInteger(cur)) \(unitsManager.weightUnitString())")
                        .font(.title3)
                        .bold()
                }
                
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.purple)
                    .font(.title2)
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(LocalizedStringKey("Predicted 1RM"))
                        .font(.caption2)
                        .foregroundColor(.purple)
                        .textCase(.uppercase)
                    let pred = unitsManager.convertFromKilograms(forecast.predictedMax)
                    Text("\(LocalizationHelper.shared.formatInteger(pred)) \(unitsManager.weightUnitString())")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.primary)
                }
            }
            
            let diff = unitsManager.convertFromKilograms(forecast.predictedMax - forecast.currentMax)
            HStack {
                Text(LocalizedStringKey("Expected gains in \(forecast.timeframe)"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("+\(LocalizationHelper.shared.formatDecimal(diff)) \(unitsManager.weightUnitString())")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.green)
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(24)
        .shadow(color: .purple.opacity(0.1), radius: 15, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Rich History List
    
    @ViewBuilder
    private func proHistoryRowContent(dataPoint: ExerciseHistoryDataPoint, vm: ExerciseHistoryViewModel) -> some View {
        NavigationLink {
            WorkoutDetailWrapperView(workoutID: dataPoint.rawWorkoutID)
        } label: {
            HStack(spacing: 16) {
                // Left: Date Block
                VStack(spacing: 0) {
                    Text(dataPoint.date, format: .dateTime.month(.abbreviated))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Text(dataPoint.date, format: .dateTime.day())
                        .font(.title2)
                        .fontWeight(.heavy)
                        .foregroundColor(.primary)
                }
                .frame(width: 50)
                .padding(.vertical, 8)
                .background(Color(UIColor.tertiarySystemFill))
                .cornerRadius(12)
                
                // Center: Minimal info
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("Session Max"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(LocalizationHelper.shared.formatFlexible(dataPoint.value))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(vm.chartColor)
                        Text(vm.unitLabel)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.02), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Notebook Style Notes Editor
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "pencil.and.outline")
                    .foregroundColor(.blue)
                Text(LocalizedStringKey("My Notes"))
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $exerciseNote)
                    .font(.body)
                    .frame(minHeight: 120, maxHeight: 200)
                    .padding(12)
                    .scrollContentBackground(.hidden)
                    .background(Color(UIColor.tertiarySystemFill).opacity(0.5))
                    .cornerRadius(12)
                    .focused(isInputActive)
                    .onChange(of: exerciseNote) { _, newValue in
                        saveTask?.cancel()
                        saveTask = Task { @MainActor in
                            try? await Task.sleep(for: .seconds(0.5))
                            if !Task.isCancelled { saveNote(newValue) }
                        }
                    }
                
                if exerciseNote.isEmpty {
                    Text(LocalizedStringKey("Write notes..."))
                        .foregroundColor(Color(UIColor.placeholderText))
                        .font(.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 5)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(LocalizedStringKey("Done")) {
                    saveTask?.cancel()
                    saveNote(exerciseNote)
                    isInputActive.wrappedValue = false
                }
                .fontWeight(.bold)
            }
        }
        .onAppear {
            exerciseNote = notes.first?.text ?? ""
        }
    }
    
    private func saveNote(_ text: String) {
        let noteID = notes.first?.persistentModelID
        Task {
            await userStatsViewModel.saveExerciseNote(exerciseName: exerciseName, text: text, existingNoteID: noteID)
        }
    }
}

// MARK: - WorkoutDetailWrapperView (FIX: Restored to resolve compilation error)
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

// MARK: - Personal Records Card View
struct PersonalRecordsCardView: View {
    let records: ExerciseRecordsDTO
    @Environment(UnitsManager.self) var unitsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedStringKey("Personal Records"))
                .font(.title2)
                .bold()
                .foregroundColor(.primary)
                .padding(.bottom, 4)
            
            recordRow(title: "Max Set Reps", value: records.maxSetReps > 0 ? "\(records.maxSetReps)" : "--")
            
            Divider().opacity(0.5)
            
            recordRow(title: "Max Workout Reps", value: records.maxWorkoutReps > 0 ? "\(records.maxWorkoutReps)" : "--")
            
            Divider().opacity(0.5)
            
            let setVol = unitsManager.convertFromKilograms(records.maxSetVolume)
            let setVolStr = records.maxSetVolume > 0 ? "\(LocalizationHelper.shared.formatInteger(setVol)) \(unitsManager.weightUnitString())" : "--"
            recordRow(title: "Max Set Volume", value: setVolStr)
            
            Divider().opacity(0.5)
            
            let woVol = unitsManager.convertFromKilograms(records.maxWorkoutVolume)
            let woVolStr = records.maxWorkoutVolume > 0 ? "\(LocalizationHelper.shared.formatInteger(woVol)) \(unitsManager.weightUnitString())" : "--"
            recordRow(title: "Max Workout Volume", value: woVolStr)
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 5)
    }
    
    private func recordRow(title: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.headline)
                .foregroundColor(.primary)
        }
    }
}
