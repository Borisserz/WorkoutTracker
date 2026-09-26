internal import SwiftUI
import SwiftData

/// Filter options for History tab
enum HistoryFilter: String, CaseIterable, Identifiable {
    case all = "Все"
    case favorites = "Избранные ★"
    case month = "Этот месяц"
    case threeMonths = "3 месяца"
    case year = "За год"

    var id: String { rawValue }
}

/// Timeline grouping structure for workouts
struct WorkoutTimelineGroup: Identifiable {
    let id: String
    let title: String
    let workouts: [Workout]
    var totalVolume: Double {
        workouts.reduce(0.0) { $0 + $1.totalStrengthVolume }
    }
}

/// Completely redesigned Workout History tab adhering strictly to PastelTheme.
/// Features timeline grouping, stats ribbon, capsule filters, and clean sports-science cards.
struct HistoryView: View {
    @Environment(DIContainer.self) private var di
    @Environment(\.modelContext) private var context
    @Environment(WorkoutService.self) var workoutService
    @Environment(UnitsManager.self) var unitsManager

    @Query(sort: \Workout.date, order: .reverse) private var allWorkouts: [Workout]

    @State private var searchText = ""
    @State private var isSearching = false
    @State private var selectedFilter: HistoryFilter = .all
    @State private var isEditingList = false

    // MARK: - Computed Filtered Workouts
    private var filteredWorkouts: [Workout] {
        let calendar = Calendar.current
        let now = Date()

        return allWorkouts.filter { workout in
            // Search text filter
            if !searchText.isEmpty {
                let matchTitle = workout.title.localizedCaseInsensitiveContains(searchText)
                let matchExercise = workout.exercises.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
                if !matchTitle && !matchExercise { return false }
            }

            // Period & favorites filter
            switch selectedFilter {
            case .all:
                return true
            case .favorites:
                return workout.isFavorite
            case .month:
                let cutoff = calendar.date(byAdding: .month, value: -1, to: now) ?? .distantPast
                return workout.date >= cutoff
            case .threeMonths:
                let cutoff = calendar.date(byAdding: .month, value: -3, to: now) ?? .distantPast
                return workout.date >= cutoff
            case .year:
                let cutoff = calendar.date(byAdding: .year, value: -1, to: now) ?? .distantPast
                return workout.date >= cutoff
            }
        }
    }

    // MARK: - Timeline Groups
    private var timelineGroups: [WorkoutTimelineGroup] {
        let calendar = Calendar.current
        let now = Date()

        guard let startOfThisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start,
              let startOfLastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfThisWeek),
              let startOfThisMonth = calendar.dateInterval(of: .month, for: now)?.start else {
            return [WorkoutTimelineGroup(id: "all", title: "Все тренировки", workouts: filteredWorkouts)]
        }

        var thisWeek: [Workout] = []
        var lastWeek: [Workout] = []
        var thisMonth: [Workout] = []
        var older: [Workout] = []

        for workout in filteredWorkouts {
            if workout.date >= startOfThisWeek {
                thisWeek.append(workout)
            } else if workout.date >= startOfLastWeek {
                lastWeek.append(workout)
            } else if workout.date >= startOfThisMonth {
                thisMonth.append(workout)
            } else {
                older.append(workout)
            }
        }

        var groups: [WorkoutTimelineGroup] = []
        if !thisWeek.isEmpty {
            groups.append(WorkoutTimelineGroup(id: "thisWeek", title: "На этой неделе", workouts: thisWeek))
        }
        if !lastWeek.isEmpty {
            groups.append(WorkoutTimelineGroup(id: "lastWeek", title: "Прошлая неделя", workouts: lastWeek))
        }
        if !thisMonth.isEmpty {
            groups.append(WorkoutTimelineGroup(id: "thisMonth", title: "В этом месяце", workouts: thisMonth))
        }
        if !older.isEmpty {
            let monthFormatter = DateFormatter()
            monthFormatter.dateFormat = "LLLL yyyy"
            monthFormatter.locale = Locale(identifier: "ru_RU")

            let groupedByMonth = Dictionary(grouping: older) { workout in
                monthFormatter.string(from: workout.date).capitalized
            }

            let sortedMonths = groupedByMonth.keys.sorted { m1, m2 in
                let d1 = groupedByMonth[m1]?.first?.date ?? Date.distantPast
                let d2 = groupedByMonth[m2]?.first?.date ?? Date.distantPast
                return d1 > d2
            }

            for month in sortedMonths {
                if let monthWorkouts = groupedByMonth[month] {
                    groups.append(WorkoutTimelineGroup(id: month, title: month, workouts: monthWorkouts))
                }
            }
        }

        return groups
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PastelTheme.canvas.ignoresSafeArea()

                // Ambient athletic glow (Emerald & Warm Beige)
                GeometryReader { _ in
                    ZStack {
                        Circle()
                            .fill(PastelTheme.pastelSage.opacity(0.12))
                            .blur(radius: 70)
                            .frame(width: 240, height: 240)
                            .offset(x: -80, y: -40)

                        Circle()
                            .fill(PastelTheme.pastelOat.opacity(0.10))
                            .blur(radius: 80)
                            .frame(width: 260, height: 260)
                            .offset(x: 120, y: -10)
                    }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)

                List {
                    Group {
                        // 1. Header with Edit Button
                        HistoryHeaderView(
                            isEditing: $isEditingList,
                            totalCount: filteredWorkouts.count
                        )

                        // 2. High-Level Hero Bento Card (Volume, Sessions, Avg Duration)
                        HistoryHeroBentoCard(
                            workouts: filteredWorkouts,
                            unitsManager: unitsManager
                        )

                        // 3. Pastel Search Bar
                        HistorySearchBarView(
                            text: $searchText,
                            isSearching: $isSearching
                        )

                        // 4. Capsule Filter Bar
                        HistoryFilterBarView(
                            selectedFilter: $selectedFilter
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                    // 5. Timeline Grouped Workouts List
                    if filteredWorkouts.isEmpty {
                        PastelHistoryEmptyState(
                            isSearching: !searchText.isEmpty || selectedFilter != .all,
                            onResetFilters: {
                                searchText = ""
                                selectedFilter = .all
                            },
                            onStartWorkout: {
                                di.appState.selectedTab = 2
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 20, leading: 16, bottom: 20, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(timelineGroups) { group in
                            Section {
                                ForEach(group.workouts) { workout in
                                    HStack(spacing: 12) {
                                        if isEditingList {
                                            Button {
                                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                Task {
                                                    await workoutService.deleteWorkout(workout)
                                                }
                                            } label: {
                                                Image(systemName: "minus.circle.fill")
                                                    .font(.title3)
                                                    .foregroundStyle(PastelTheme.pastelPeach)
                                            }
                                            .transition(.move(edge: .leading).combined(with: .opacity))
                                        }

                                        ZStack {
                                            NavigationLink(destination: WorkoutDetailView(workout: workout, viewModel: di.makeWorkoutDetailViewModel())) {
                                                EmptyView()
                                            }
                                            .opacity(0)

                                            PastelWorkoutCard(workout: workout, unitsManager: unitsManager)
                                        }
                                    }
                                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            Task {
                                                await workoutService.deleteWorkout(workout)
                                            }
                                        } label: {
                                            Label("Удалить", systemImage: "trash.fill")
                                        }
                                        .tint(PastelTheme.pastelPeach)
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                            workout.isFavorite.toggle()
                                            try? context.save()
                                        } label: {
                                            Label(workout.isFavorite ? "Убрать из избранного" : "В избранное", systemImage: workout.isFavorite ? "star.slash.fill" : "star.fill")
                                        }
                                        .tint(PastelTheme.pastelAmber)
                                    }
                                }
                            } header: {
                                HStack(alignment: .center, spacing: 8) {
                                    Circle()
                                        .fill(PastelTheme.pastelSage)
                                        .frame(width: 7, height: 7)

                                    Text(group.title)
                                        .font(.headline)
                                        .foregroundStyle(PastelTheme.textPrimary)

                                    Spacer()

                                    let tons = group.totalVolume / 1000.0
                                    HStack(spacing: 5) {
                                        Text("\(group.workouts.count) сес.")
                                            .font(.caption2.bold())
                                            .foregroundStyle(PastelTheme.pastelSage)

                                        Text("·")
                                            .font(.caption2)
                                            .foregroundStyle(PastelTheme.textTertiary)

                                        Text("\(String(format: "%.1f", tons)) т")
                                            .font(.caption2.bold())
                                            .foregroundStyle(PastelTheme.pastelOat)
                                    }
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(PastelTheme.cardSurface)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1))
                                }
                                .textCase(nil)
                                .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 6, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                        }
                    }

                    Color.clear
                        .frame(height: 100)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(PastelTheme.canvas.ignoresSafeArea())
                .onTapGesture {
                    hideKeyboard()
                    withAnimation { isSearching = false }
                }
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - 1. Header View
private struct HistoryHeaderView: View {
    @Binding var isEditing: Bool
    let totalCount: Int

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("История")
                        .font(.largeTitle.bold())
                        .foregroundStyle(PastelTheme.textPrimary)

                    if totalCount > 0 {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(PastelTheme.pastelSage)
                                .frame(width: 6, height: 6)

                            Text("\(totalCount)")
                                .font(.caption.bold())
                                .foregroundStyle(PastelTheme.pastelSage)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(PastelTheme.cardSurface)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1))
                    }
                }

                Text("Журнал тренировок и прогресс")
                    .font(.caption)
                    .foregroundStyle(PastelTheme.textSecondary)
            }

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    isEditing.toggle()
                }
            } label: {
                Text(isEditing ? "Готово" : "Править")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isEditing ? PastelTheme.textOnOat : PastelTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(isEditing ? PastelTheme.pastelOat : PastelTheme.cardSurfaceSubtle)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(isEditing ? PastelTheme.pastelOat : PastelTheme.cardBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }
}

// MARK: - 2. Athletic Hero Bento Card
private struct HistoryHeroBentoCard: View {
    let workouts: [Workout]
    let unitsManager: UnitsManager

    private var totalVolumeTons: Double {
        let kg = workouts.reduce(0.0) { $0 + $1.totalStrengthVolume }
        return kg / 1000.0
    }

    private var avgDurationMinutes: Int {
        guard !workouts.isEmpty else { return 0 }
        let totalSeconds = workouts.reduce(0) { $0 + $1.durationSeconds }
        return (totalSeconds / workouts.count) / 60
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Top Row: Big Volume + Status Badge
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(String(format: "%.1f", totalVolumeTons))
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundStyle(PastelTheme.pastelOat)

                    Text("Т")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(PastelTheme.pastelOat)

                    Text("поднято")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PastelTheme.textSecondary)
                        .padding(.leading, 2)
                }

                Spacer()

                // Athletic status badge
                HStack(spacing: 5) {
                    Circle()
                        .fill(PastelTheme.pastelSage)
                        .frame(width: 6, height: 6)

                    Text(workouts.isEmpty ? "Отдых" : "Активный прогресс")
                        .font(.caption2.bold())
                        .foregroundStyle(PastelTheme.pastelSage)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(PastelTheme.pastelSage.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(PastelTheme.pastelSage.opacity(0.3), lineWidth: 1))
            }

            // Bottom Dual Stat Pods
            HStack(spacing: 10) {
                // Sessions Pod
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(PastelTheme.pastelSage)
                        .frame(width: 3, height: 26)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(workouts.count) сессий")
                            .font(.subheadline.bold())
                            .foregroundStyle(PastelTheme.textPrimary)

                        Text("завершено")
                            .font(.caption2)
                            .foregroundStyle(PastelTheme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(PastelTheme.cardSurfaceSubtle)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(PastelTheme.cardBorder, lineWidth: 1))

                // Average Duration Pod
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(PastelTheme.pastelOat)
                        .frame(width: 3, height: 26)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(avgDurationMinutes) мин")
                            .font(.subheadline.bold())
                            .foregroundStyle(PastelTheme.textPrimary)

                        Text("в среднем")
                            .font(.caption2)
                            .foregroundStyle(PastelTheme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(PastelTheme.cardSurfaceSubtle)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(PastelTheme.cardBorder, lineWidth: 1))
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [PastelTheme.cardSurface, PastelTheme.cardSurfaceSubtle],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - 3. Pastel Search Bar
private struct HistorySearchBarView: View {
    @Binding var text: String
    @Binding var isSearching: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isSearching ? PastelTheme.pastelOat : PastelTheme.textTertiary)

            TextField("Поиск по названию или упражнениям...", text: $text)
                .font(.subheadline)
                .foregroundStyle(PastelTheme.textPrimary)
                .onTapGesture { withAnimation { isSearching = true } }

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(PastelTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(PastelTheme.cardSurfaceSubtle)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSearching ? PastelTheme.cardBorderFocused : PastelTheme.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - 4. Capsule Filter Bar
private struct HistoryFilterBarView: View {
    @Binding var selectedFilter: HistoryFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HistoryFilter.allCases) { filter in
                    let isSelected = selectedFilter == filter

                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedFilter = filter
                        }
                    } label: {
                        Text(filter.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isSelected ? PastelTheme.textOnOat : PastelTheme.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(isSelected ? PastelTheme.pastelOat : PastelTheme.cardSurfaceSubtle)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(isSelected ? PastelTheme.pastelOat : PastelTheme.cardBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 1)
        }
    }
}

// MARK: - 5. Pastel Workout Card (Athletic Bento Style)
private struct PastelWorkoutCard: View {
    let workout: Workout
    let unitsManager: UnitsManager

    private var targetedMuscles: [String] {
        let slugs = workout.exercises.compactMap { ex -> String? in
            guard !ex.muscleGroup.isEmpty else { return nil }
            return ex.muscleGroup.lowercased()
        }
        return Array(Set(slugs)).prefix(3).map { MuscleDisplayHelper.getDisplayName(for: $0) }
    }

    private var exercisePreviews: [String] {
        let names = workout.exercises.map(\.name)
        return Array(names.prefix(3))
    }

    private var extraExercisesCount: Int {
        max(0, workout.exercises.count - 3)
    }

    private var accentColor: Color {
        if workout.isActive {
            return PastelTheme.pastelSage
        } else if workout.isFavorite {
            return PastelTheme.pastelAmber
        } else {
            return PastelTheme.pastelOat
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            
            // Header: Accent Tag, Title, Date/Relative, Chevron
            HStack(alignment: .top, spacing: 12) {
                // Workout Type Icon
                ZStack {
                    Circle()
                        .fill(PastelTheme.cardSurfaceSubtle)
                        .frame(width: 40, height: 40)
                        .overlay(Circle().stroke(PastelTheme.cardBorder, lineWidth: 1))

                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(accentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(workout.title.isEmpty ? "Тренировка" : workout.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(PastelTheme.textPrimary)
                            .lineLimit(1)

                        if workout.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(PastelTheme.pastelAmber)
                        }
                    }

                    Text(workout.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(PastelTheme.textSecondary)
                }

                Spacer()

                if workout.isActive {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(PastelTheme.pastelSage)
                            .frame(width: 6, height: 6)

                        Text("В процессе")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(PastelTheme.pastelSage)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(PastelTheme.pastelSage.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(PastelTheme.pastelSage.opacity(0.3), lineWidth: 1))
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(PastelTheme.textTertiary)
                        .padding(.top, 4)
                }
            }

            // Real Exercise Preview Chips (Brings workout to life)
            if !exercisePreviews.isEmpty {
                HStack(spacing: 6) {
                    ForEach(exercisePreviews, id: \.self) { exName in
                        Text(exName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PastelTheme.textSecondary)
                            .lineLimit(1)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(PastelTheme.cardSurfaceSubtle)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
                            )
                    }

                    if extraExercisesCount > 0 {
                        Text("+\(extraExercisesCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(PastelTheme.pastelOat)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(PastelTheme.cardSurfaceSubtle)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }

            // Dual Bottom Pods: Volume & Duration (Athletic Dashboard Pods)
            HStack(spacing: 8) {
                // Volume Pod
                HStack(spacing: 6) {
                    Image(systemName: "scalemass.fill")
                        .font(.caption2)
                        .foregroundStyle(PastelTheme.pastelOat)

                    Text("\(Int(unitsManager.convertFromKilograms(workout.totalStrengthVolume))) \(unitsManager.weightUnitString())")
                        .font(.caption.bold())
                        .foregroundStyle(PastelTheme.pastelOat)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(PastelTheme.cardSurfaceSubtle)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(PastelTheme.cardBorder, lineWidth: 1)
                )

                // Duration Pod
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                        .foregroundStyle(PastelTheme.pastelSage)

                    Text("\(workout.durationSeconds / 60) мин")
                        .font(.caption.bold())
                        .foregroundStyle(PastelTheme.pastelSage)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(PastelTheme.cardSurfaceSubtle)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(PastelTheme.cardBorder, lineWidth: 1)
                )

                // Exercises count pod
                HStack(spacing: 5) {
                    Image(systemName: "dumbbell.fill")
                        .font(.caption2)
                        .foregroundStyle(PastelTheme.textPrimary)

                    Text("\(workout.exercises.count) упр.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PastelTheme.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(PastelTheme.cardSurfaceSubtle)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(PastelTheme.cardBorder, lineWidth: 1)
                )
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [PastelTheme.cardSurface, PastelTheme.cardSurfaceSubtle],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(workout.isActive ? PastelTheme.pastelSage.opacity(0.5) : PastelTheme.cardBorder, lineWidth: 1)
        )
    }
}



// MARK: - 6. Empty State View
private struct PastelHistoryEmptyState: View {
    let isSearching: Bool
    let onResetFilters: () -> Void
    let onStartWorkout: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: isSearching ? "magnifyingglass.circle" : "clock.arrow.circlepath")
                .font(.system(size: 44))
                .foregroundStyle(PastelTheme.pastelSlate)
                .padding(.top, 12)

            VStack(spacing: 4) {
                Text(isSearching ? "Ничего не найдено" : "История пуста")
                    .font(.headline)
                    .foregroundStyle(PastelTheme.textPrimary)

                Text(isSearching 
                    ? "Попробуйте изменить запрос или фильтр" 
                    : "Завершите вашу первую тренировку, чтобы она появилась в истории")
                    .font(.caption)
                    .foregroundStyle(PastelTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            if isSearching {
                Button {
                    onResetFilters()
                } label: {
                    Text("Сбросить фильтры")
                        .font(.caption.bold())
                        .foregroundStyle(PastelTheme.pastelOat)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(PastelTheme.cardSurfaceSubtle)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    onStartWorkout()
                } label: {
                    HStack(spacing: 6) {
                        Text("Начать тренировку")
                            .font(.caption.bold())
                        Image(systemName: "arrow.right")
                            .font(.caption2.bold())
                    }
                    .foregroundStyle(PastelTheme.textOnOat)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(PastelTheme.pastelOat)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
    }
}

#if canImport(UIKit)
import UIKit

extension View {
    fileprivate func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

