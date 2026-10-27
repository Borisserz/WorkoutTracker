

internal import SwiftUI
import SwiftData
import Charts

struct ExerciseHistoryView: View {
    @Environment(DIContainer.self) private var di
    @Environment(UnitsManager.self) var unitsManager
    @FocusState private var isInputActive: Bool
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme 
    let exerciseName: String
    @State private var viewModel: ExerciseHistoryViewModel?

    @Namespace private var tabNamespace

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
            PastelTheme.canvas
                .ignoresSafeArea()

            // Subtle ambient athletic glow
            VStack {
                Circle()
                    .fill(PastelTheme.pastelSage.opacity(0.06))
                    .frame(width: 340, height: 340)
                    .blur(radius: 80)
                    .offset(y: -120)
                Spacer()
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                customTabBar(vm: vm)

                if !vm.isDataLoaded {
                    Spacer()
                    ProgressView(LocalizedStringKey("Loading data..."))
                        .controlSize(.large)
                        .tint(PastelTheme.pastelOat)
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 20) {
                                switch vm.selectedTab {
                                case .summary: summaryContent(vm: vm)
                                case .technique: techniqueContent(vm: vm)
                                case .oneRepMax: OneRepMaxTabView(vm: vm)
                                case .history: historyContent(vm: vm)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
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

    private func customTabBar(vm: ExerciseHistoryViewModel) -> some View {
        HStack(spacing: 4) {
            ForEach(ExerciseHistoryViewModel.Tab.allCases, id: \.self) { tab in
                if tab == .oneRepMax && vm.exerciseType != .strength {
                    EmptyView()
                } else {
                    let isSelected = vm.selectedTab == tab

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            vm.selectedTab = tab
                        }
                    } label: {
                        Text(tab.localizedName)
                            .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                            .foregroundColor(isSelected ? PastelTheme.textOnOat : PastelTheme.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background {
                                if isSelected {
                                    Capsule()
                                        .fill(PastelTheme.pastelOat)
                                        .matchedGeometryEffect(id: "activeTab", in: tabNamespace)
                                }
                            }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(3)
        .background(PastelTheme.cardSurfaceSubtle)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private func summaryContent(vm: ExerciseHistoryViewModel) -> some View {
        VStack(spacing: 20) {
            proChartContainerView(vm: vm)

            if let trend = vm.exerciseTrend {
                proExerciseTrendSection(trend: trend)
            }

            if let forecast = vm.exerciseForecast {
                proForecastSection(forecast: forecast)
            }

            if let records = vm.personalRecords, vm.exerciseType == .strength {
                PersonalRecordsCardView(records: records)
            }

            ExerciseNoteEditor(exerciseName: vm.exerciseName, isInputActive: $isInputActive)
                .id("notesSection")
        }
    }

    private func techniqueContent(vm: ExerciseHistoryViewModel) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(LocalizedStringKey("Exercise Technique"))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(PastelTheme.textPrimary)
                .padding(.bottom, 2)

            ExerciseVideoView(urlString: vm.gifUrl)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(PastelTheme.cardBorder, lineWidth: 1)
                )
                .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "book.pages.fill")
                        .foregroundColor(PastelTheme.pastelSage)
                    Text(LocalizedStringKey("How to Perform"))
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundColor(PastelTheme.textPrimary)
                }
                Text(TechniqueHelper.getDescription(for: vm.exerciseCategory))
                    .font(.body)
                    .foregroundColor(PastelTheme.textSecondary)
                    .lineSpacing(5)
            }
            .padding(18)
            .background(PastelTheme.cardSurface)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(PastelTheme.pastelAmber)
                    Text(LocalizedStringKey("Key Tips"))
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundColor(PastelTheme.textPrimary)
                }

                ForEach(TechniqueHelper.getTips(for: vm.exerciseCategory), id: \.self) { tip in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(PastelTheme.pastelSage)
                            .font(.body)
                            .padding(.top, 2)
                        Text(tip)
                            .font(.subheadline)
                            .foregroundColor(PastelTheme.textSecondary)
                            .lineSpacing(4)
                    }
                }
            }
            .padding(18)
            .background(PastelTheme.cardSurface)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
            )

            let targetMuscles = MuscleDisplayHelper.getTargetMuscleNames(for: vm.exerciseName, muscleGroup: vm.muscleGroup)
            if !vm.primaryMuscles.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .foregroundColor(PastelTheme.pastelSage)
                        Text(LocalizedStringKey("Target (Primary) Muscles"))
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundColor(PastelTheme.textPrimary)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(vm.primaryMuscles, id: \.self) { muscle in
                                HStack(spacing: 6) {
                                    Circle().fill(PastelTheme.pastelSage).frame(width: 7, height: 7)
                                    Text(LocalizedStringKey(muscle.capitalized))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(PastelTheme.cardSurfaceSubtle)
                                .foregroundColor(PastelTheme.textPrimary)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(PastelTheme.cardBorder, lineWidth: 1)
                                )
                            }
                        }
                    }
                }
                .padding(18)
                .background(PastelTheme.cardSurface)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(PastelTheme.cardBorder, lineWidth: 1)
                )
            }

            if !vm.secondaryMuscles.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "figure.mixed.cardio")
                            .foregroundColor(PastelTheme.pastelSlate)
                        Text(LocalizedStringKey("Synergist (Secondary) Muscles"))
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundColor(PastelTheme.textPrimary)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(vm.secondaryMuscles, id: \.self) { muscle in
                                HStack(spacing: 6) {
                                    Circle().fill(PastelTheme.pastelSlate).frame(width: 6, height: 6)
                                    Text(LocalizedStringKey(muscle.capitalized))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(PastelTheme.cardSurfaceSubtle)
                                .foregroundColor(PastelTheme.textSecondary)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(PastelTheme.cardBorder, lineWidth: 1)
                                )
                            }
                        }
                    }
                }
                .padding(18)
                .background(PastelTheme.cardSurface)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(PastelTheme.cardBorder, lineWidth: 1)
                )
            }
        }
    }

    private func historyContent(vm: ExerciseHistoryViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedStringKey("History"))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(PastelTheme.textPrimary)
                .padding(.bottom, 2)

            if vm.displayedGraphData.isEmpty {
                EmptyStateView(
                    icon: "clock.fill",
                    title: LocalizedStringKey("No history yet"),
                    message: LocalizedStringKey("This exercise hasn't been performed in any workouts yet. Add it to a workout to start tracking your progress!"),
                    iconColor: PastelTheme.textTertiary
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

    private func proChartContainerView(vm: ExerciseHistoryViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {

            HStack {
                Text(vm.chartTitle)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundColor(PastelTheme.textPrimary)

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
                        .background(PastelTheme.cardSurfaceSubtle)
                        .foregroundColor(PastelTheme.textPrimary)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)

            if vm.displayedGraphData.isEmpty {
                Text(LocalizedStringKey("Not enough data"))
                    .font(.subheadline)
                    .foregroundColor(PastelTheme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .background(PastelTheme.cardSurfaceSubtle)
                    .cornerRadius(14)
                    .padding(.horizontal, 18)
            } else {
                proChartView(vm: vm)
                    .padding(.horizontal, 18)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Spacer().frame(width: 8)
                    ForEach(ExerciseHistoryViewModel.TimeRange.allCases, id: \.self) { range in
                        let isSelected = vm.selectedTimeRange == range
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            vm.selectedTimeRange = range
                        } label: {
                            Text(LocalizedStringKey(range.rawValue))
                                .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .rounded))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(isSelected ? PastelTheme.pastelOat : PastelTheme.cardSurfaceSubtle)
                                .foregroundColor(isSelected ? PastelTheme.textOnOat : PastelTheme.textTertiary)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    Spacer().frame(width: 8)
                }
            }
            .padding(.bottom, 16)
        }
        .background(PastelTheme.cardSurface)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
    }

    private func proChartView(vm: ExerciseHistoryViewModel) -> some View {
        let minVal = vm.displayedGraphData.map { $0.value }.min() ?? 0
        let maxVal = vm.displayedGraphData.map { $0.value }.max() ?? 10
        let diff = maxVal - minVal
        let yPadding = diff == 0 ? (maxVal == 0 ? 10 : maxVal * 0.4) : diff * 0.4
        let yDomainMin = max(0, minVal - (diff == 0 ? 0 : diff * 0.1))
        let yDomainMax = maxVal + yPadding

        return Chart {
            ForEach(vm.displayedGraphData) { dataPoint in
                if vm.displayedGraphData.count > 1 {
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Value", dataPoint.value)
                    )
                    .foregroundStyle(PastelTheme.pastelSage)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3.0, lineCap: .round, lineJoin: .round))
                }

                if vm.displayedGraphData.count < 20 {
                    PointMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Value", dataPoint.value)
                    )
                    .symbol {
                        Circle()
                            .fill(PastelTheme.cardSurface)
                            .frame(width: vm.displayedGraphData.count == 1 ? 14 : 9, height: vm.displayedGraphData.count == 1 ? 14 : 9)
                            .overlay(
                                Circle().stroke(PastelTheme.pastelSage, lineWidth: 2.5)
                            )
                    }
                }
            }

            if let val = vm.currentMetricValue, vm.displayedGraphData.count > 1, vm.selectedMetric != .none {
                RuleMark(y: .value("Metric", val))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .foregroundStyle(Color.white.opacity(0.15))
                    .annotation(position: .top, alignment: .leading) {
                        Text("\(val, format: .number.precision(.fractionLength(1))) \(vm.unitLabel)")
                            .font(.caption)
                            .bold()
                            .foregroundColor(PastelTheme.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(PastelTheme.cardSurfaceSubtle)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(PastelTheme.cardBorder, lineWidth: 1))
                    }
            }

            if let selectedDate = selectedX {
                if let closestPoint = vm.displayedGraphData.min(by: { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }) {
                    RuleMark(x: .value("Selected", closestPoint.date))
                        .foregroundStyle(Color.white.opacity(0.2))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4]))
                        .annotation(position: .top) {
                            VStack(alignment: .center, spacing: 2) {
                                Text("\(LocalizationHelper.shared.formatDecimal(closestPoint.value)) \(vm.unitLabel)")
                                    .font(.headline)
                                    .bold()
                                    .foregroundColor(PastelTheme.textPrimary)
                                Text(closestPoint.date, format: .dateTime.month(.abbreviated).day())
                                    .font(.caption)
                                    .foregroundColor(PastelTheme.textTertiary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(PastelTheme.cardSurfaceSubtle)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(PastelTheme.cardBorder, lineWidth: 1))
                        }
                }
            }
        }
        .frame(height: 240)
        .chartXSelection(value: $selectedX)
        .chartXScale(range: .plotDimension(padding: 15))
        .chartYScale(domain: yDomainMin...yDomainMax, range: .plotDimension(padding: 15))
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Color.white.opacity(0.06))
                AxisTick()
                    .foregroundStyle(Color.white.opacity(0.2))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
                    .foregroundStyle(PastelTheme.textTertiary)
                    .font(.caption2.bold())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Color.white.opacity(0.06))
                AxisTick()
                    .foregroundStyle(Color.white.opacity(0.2))
                AxisValueLabel()
                    .foregroundStyle(PastelTheme.textTertiary)
                    .font(.caption2.bold())
            }
        }
    }

    @ViewBuilder
    private func proExerciseTrendSection(trend: ExerciseTrend) -> some View {
        let isGrowing = trend.trend == .growing
        let isDeclining = trend.trend == .declining
        let trendColor = isGrowing ? PastelTheme.pastelSage : (isDeclining ? PastelTheme.pastelPeach : PastelTheme.pastelAmber)

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(LocalizedStringKey("Exercise Trend"))
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundColor(PastelTheme.textSecondary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: trend.trend.icon)
                        .font(.caption.bold())
                    Text(isGrowing ? LocalizedStringKey("↑ Growing") : isDeclining ? LocalizedStringKey("↓ Declining") : LocalizedStringKey("→ Stable"))
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .foregroundColor(trendColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(trendColor.opacity(0.12))
                .clipShape(Capsule())
            }

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("Previous"))
                        .font(.caption2)
                        .foregroundColor(PastelTheme.textTertiary)
                        .textCase(.uppercase)
                    let prev = unitsManager.convertFromKilograms(trend.previousValue)
                    Text("\(LocalizationHelper.shared.formatInteger(prev))")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(PastelTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .foregroundColor(PastelTheme.textTertiary)
                    .font(.title3)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(LocalizedStringKey("Current"))
                        .font(.caption2)
                        .foregroundColor(trendColor)
                        .textCase(.uppercase)
                    let curr = unitsManager.convertFromKilograms(trend.currentValue)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(LocalizationHelper.shared.formatInteger(curr))")
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundColor(PastelTheme.textPrimary)
                        Text(unitsManager.weightUnitString())
                            .font(.subheadline)
                            .foregroundColor(PastelTheme.textSecondary)
                    }
                }
            }

            Divider().overlay(PastelTheme.separator)

            HStack {
                Text(LocalizedStringKey("Overall Progress"))
                    .font(.subheadline)
                    .foregroundColor(PastelTheme.textSecondary)
                Spacer()
                Text("\(trend.changePercentage > 0 ? "+" : "")\(trend.changePercentage, specifier: "%.1f")%")
                    .font(.headline)
                    .fontWeight(.heavy)
                    .foregroundColor(trendColor)
            }
        }
        .padding(18)
        .background(PastelTheme.cardSurface)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func proForecastSection(forecast: ProgressForecast) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(LocalizedStringKey("AI Forecast"))
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundColor(PastelTheme.textSecondary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                    Text("\(forecast.confidence)% Confidence")
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .foregroundColor(PastelTheme.pastelAmber)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(PastelTheme.pastelAmber.opacity(0.12))
                .clipShape(Capsule())
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("Current 1RM"))
                        .font(.caption2)
                        .foregroundColor(PastelTheme.textTertiary)
                        .textCase(.uppercase)
                    let cur = unitsManager.convertFromKilograms(forecast.currentMax)
                    Text("\(LocalizationHelper.shared.formatInteger(cur)) \(unitsManager.weightUnitString())")
                        .font(.title3)
                        .bold()
                        .foregroundColor(PastelTheme.textSecondary)
                }

                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(PastelTheme.pastelAmber)
                    .font(.title2)
                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(LocalizedStringKey("Predicted 1RM"))
                        .font(.caption2)
                        .foregroundColor(PastelTheme.pastelAmber)
                        .textCase(.uppercase)
                    let pred = unitsManager.convertFromKilograms(forecast.predictedMax)
                    Text("\(LocalizationHelper.shared.formatInteger(pred)) \(unitsManager.weightUnitString())")
                        .font(.title2)
                        .bold()
                        .foregroundColor(PastelTheme.textPrimary)
                }
            }

            let diff = unitsManager.convertFromKilograms(forecast.predictedMax - forecast.currentMax)
            HStack {
                Text(LocalizedStringKey("Expected gains in \(forecast.timeframe)"))
                    .font(.caption)
                    .foregroundColor(PastelTheme.textSecondary)
                Spacer()
                Text("+\(LocalizationHelper.shared.formatDecimal(diff)) \(unitsManager.weightUnitString())")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(PastelTheme.pastelSage)
            }
        }
        .padding(18)
        .background(PastelTheme.cardSurface)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func proHistoryRowContent(dataPoint: ExerciseHistoryDataPoint, vm: ExerciseHistoryViewModel) -> some View {
        NavigationLink {
            WorkoutDetailWrapperView(workoutID: dataPoint.rawWorkoutID)
        } label: {
            HStack(spacing: 14) {

                VStack(spacing: 1) {
                    Text(dataPoint.date, format: .dateTime.month(.abbreviated))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(PastelTheme.textTertiary)
                        .textCase(.uppercase)
                    Text(dataPoint.date, format: .dateTime.day())
                        .font(.title3)
                        .fontWeight(.heavy)
                        .foregroundColor(PastelTheme.textPrimary)
                }
                .frame(width: 48)
                .padding(.vertical, 8)
                .background(PastelTheme.cardSurfaceSubtle)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(PastelTheme.cardBorder, lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(LocalizedStringKey("Session Max"))
                        .font(.caption)
                        .foregroundColor(PastelTheme.textTertiary)
                        .textCase(.uppercase)

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(LocalizationHelper.shared.formatFlexible(dataPoint.value))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(PastelTheme.pastelSage)
                        Text(vm.unitLabel)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(PastelTheme.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(PastelTheme.textTertiary)
            }
            .padding(14)
            .background(PastelTheme.cardSurface)
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

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
                    .foregroundColor(PastelTheme.pastelOat)
                Text(LocalizedStringKey("My Notes"))
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundColor(PastelTheme.textPrimary)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $exerciseNote)
                    .font(.body)
                    .frame(minHeight: 110, maxHeight: 180)
                    .padding(12)
                    .scrollContentBackground(.hidden)
                    .background(PastelTheme.cardSurfaceSubtle)
                    .foregroundColor(PastelTheme.textPrimary)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(PastelTheme.cardBorder, lineWidth: 1)
                    )
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
                        .foregroundColor(PastelTheme.textTertiary)
                        .font(.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(18)
        .background(PastelTheme.cardSurface)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(LocalizedStringKey("Done")) {
                    saveTask?.cancel()
                    saveNote(exerciseNote)
                    isInputActive.wrappedValue = false
                }
                .fontWeight(.bold)
                .foregroundColor(PastelTheme.pastelOat)
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

struct PersonalRecordsCardView: View {
    let records: ExerciseRecordsDTO
    @Environment(UnitsManager.self) var unitsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .foregroundColor(PastelTheme.pastelAmber)
                Text(LocalizedStringKey("Personal Records"))
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundColor(PastelTheme.textPrimary)
            }
            .padding(.bottom, 2)

            recordRow(title: "Max Set Reps", value: records.maxSetReps > 0 ? "\(records.maxSetReps)" : "--")

            Divider().overlay(PastelTheme.separator)

            recordRow(title: "Max Workout Reps", value: records.maxWorkoutReps > 0 ? "\(records.maxWorkoutReps)" : "--")

            Divider().overlay(PastelTheme.separator)

            let setVol = unitsManager.convertFromKilograms(records.maxSetVolume)
            let setVolStr = records.maxSetVolume > 0 ? "\(LocalizationHelper.shared.formatInteger(setVol)) \(unitsManager.weightUnitString())" : "--"
            recordRow(title: "Max Set Volume", value: setVolStr)

            Divider().overlay(PastelTheme.separator)

            let woVol = unitsManager.convertFromKilograms(records.maxWorkoutVolume)
            let woVolStr = records.maxWorkoutVolume > 0 ? "\(LocalizationHelper.shared.formatInteger(woVol)) \(unitsManager.weightUnitString())" : "--"
            recordRow(title: "Max Workout Volume", value: woVolStr)
        }
        .padding(18)
        .background(PastelTheme.cardSurface)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
    }

    private func recordRow(title: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(PastelTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundColor(PastelTheme.textPrimary)
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
