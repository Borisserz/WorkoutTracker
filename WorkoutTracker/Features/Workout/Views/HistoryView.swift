

internal import SwiftUI
import SwiftData

struct SearchedWorkout: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let description: String
    var isFavorite: Bool = false
}

struct HistoryView: View {
    @Environment(DIContainer.self) private var di
    @Environment(\.modelContext) private var context
    @Environment(WorkoutService.self) var workoutService
    @Environment(UnitsManager.self) var unitsManager
    @Environment(DashboardViewModel.self) var dashboardViewModel
    @Environment(\.colorScheme) private var colorScheme 

    @State private var searchText = ""
    @State private var isSearching = false
    @State private var showSparks = false

    @State private var showDetailSheet = false
    @State private var detailWorkoutId: UUID? = nil

    @State private var selectedFilter: WorkoutView.FilterPeriod = .all
    @State private var sortOption: WorkoutView.SortOption = .dateDescending
    @State private var showFavoritesOnly = false
    @State private var listViewModel = WorkoutListViewModel()

    @State private var isEditingList = false

    @State private var searchDatabase: [SearchedWorkout] = [
        SearchedWorkout(name: "Тренировка Арнольда", description: "Классическая программа Золотой Эры: суперсеты на грудь и спину для максимального пампа и расширения грудной клетки."),
        SearchedWorkout(name: "Фуллбоди База", description: "Мощный фундамент. Приседания, жим лёжа и становая тяга в одну сессию. Идеально для выброса тестостерона."),
        SearchedWorkout(name: "Сплит Грудь/Трицепс", description: "Убойная сессия на жимовые мышцы. Включает тяжелый жим штанги, разводки и французский жим."),
        SearchedWorkout(name: "Убийца Ног 3000", description: "Только для смелых. Тяжелый присед, жим ногами и выпады. На следующий день ходить будет тяжело!"),
        SearchedWorkout(name: "Дельты-Пушки", description: "Фокус на плечи. Армейский жим, махи в стороны и тяга к подбородку сделают твои плечи круглыми как шары."),
        SearchedWorkout(name: "Кардио-Интенсив", description: "Интервальная (HIIT) тренировка. Пульс 160+, пот ручьем, сжигание жира на максималках.")
    ]

    var body: some View {
        NavigationStack {
            ZStack {

                if colorScheme == .dark {
                    HistoryBreathingBackground(cnsScore: 100)
                } else {
                    Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        HistoryHeader(isEditing: $isEditingList) 

                        TopStatsIslandsView(listViewModel: listViewModel, unitsManager: unitsManager)

                        VStack(spacing: 12) {
                            HistorySearchBar(text: $searchText, isSearching: $isSearching)

                            if isSearching && !searchText.isEmpty {
                                SearchResultsDropdown(
                                    results: $searchDatabase,
                                    searchText: searchText,
                                    onSelect: { workout in
                                        hideKeyboard()
                                        detailWorkoutId = workout.id
                                        showDetailSheet = true
                                    }
                                )
                            }
                        }
                        .zIndex(20)

                        PremiumCategoriesIslands(
                            selectedFilter: $selectedFilter,
                            showFavoritesOnly: $showFavoritesOnly
                        )
                        .zIndex(10)

                        VStack(alignment: .leading, spacing: 16) {
                            Text("Workout History")
                                .font(.title3).bold()
                                .foregroundColor(colorScheme == .dark ? .white : .primary)
                                .padding(.horizontal, 20)

                            DynamicWorkoutListView(
                                searchText: "",
                                filter: selectedFilter,
                                sort: sortOption,
                                favoritesOnly: showFavoritesOnly,
                                listViewModel: listViewModel,
                                isEditing: isEditingList 
                            )
                        }

                        Spacer().frame(height: 120)
                    }
                    .padding(.top, 20)
                }
                .onTapGesture {
                    hideKeyboard()
                    withAnimation { isSearching = false }
                }

                if showSparks && colorScheme == .dark {
                    ParticleExplosionView().allowsHitTesting(false)
                }
            }
            .navigationBarHidden(true)

            .sheet(isPresented: $showDetailSheet) {
                if let id = detailWorkoutId, let index = searchDatabase.firstIndex(where: { $0.id == id }) {
                    QuickWorkoutDetailSheet(
                        workout: $searchDatabase[index],
                        onAddWorkout: {
                            Task {
                                _ = await workoutService.createWorkout(title: searchDatabase[index].name, presetID: nil, isAIGenerated: true)
                            }
                            showDetailSheet = false
                            triggerSparks()
                        }
                    )
                    .presentationDetents([.fraction(0.65)])
                    .presentationDragIndicator(.visible)
                }
            }
        }
    }

    private func triggerSparks() {
        showSparks = true
        HapticManager.shared.impact(.heavy)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showSparks = false
        }
    }
}

struct HistoryHeader: View {
    @Binding var isEditing: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            Text("История")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundColor(colorScheme == .dark ? .white : .primary)

            Spacer()

            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isEditing.toggle()
                }
            }) {
                Text(isEditing ? "Готово" : "Править")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
    }
}

struct ParticleExplosionView: View {
    @State private var animate = false
    var body: some View {
        ZStack {
            ForEach(0..<20, id: \.self) { i in
                Circle()
                    .fill(Color(red: .random(in: 0.5...1), green: .random(in: 0...0.5), blue: .random(in: 0.5...1)))
                    .frame(width: CGFloat.random(in: 5...12), height: CGFloat.random(in: 5...12))
                    .offset(x: animate ? CGFloat.random(in: -150...150) : 0, y: animate ? CGFloat.random(in: -150...150) : 0)
                    .opacity(animate ? 0 : 1)
                    .scaleEffect(animate ? 0.1 : 1)
                    .animation(.easeOut(duration: 0.8).delay(Double.random(in: 0...0.2)), value: animate)
            }
        }.onAppear { animate = true }
    }
}

struct TopStatsIslandsView: View {
    var listViewModel: WorkoutListViewModel
    var unitsManager: UnitsManager

    @State private var activeTooltip: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            StatIslandWithTooltip(
                icon: "stopwatch.fill",
                title: "Время",
                value: "\(listViewModel.calculatedAvgDuration)м",
                color: .blue,
                tooltipTitle: "Средняя длительность",
                tooltipDesc: "Отличное время под нагрузкой.",
                statusText: nil,
                statusColor: nil,
                activeTooltip: $activeTooltip 
            )

            let tons = Double(listViewModel.calculatedAvgVolume) / 1000.0
            StatIslandWithTooltip(
                icon: "scalemass.fill",
                title: "Вес",
                value: "\(LocalizationHelper.shared.formatTwoDecimals(tons))т",
                color: .purple,
                tooltipTitle: "Средний вес",
                tooltipDesc: "Ваш суммарный средний тоннаж.",
                statusText: nil,
                statusColor: nil,
                activeTooltip: $activeTooltip 
            )

            StatIslandWithTooltip(
                icon: "heart.fill",
                title: "Пульс",
                value: "142",
                color: .red,
                tooltipTitle: "Средний пульс",
                tooltipDesc: "Ваш пульс в норме.",
                statusText: "Идеальный показатель",
                statusColor: .green,
                activeTooltip: $activeTooltip 
            )
        }
        .padding(.horizontal, 20)
        .zIndex(30)
    }
}

struct StatIslandWithTooltip: View {
    @Environment(\.colorScheme) private var colorScheme
    var icon: String; var title: String; var value: String; var color: Color
    var tooltipTitle: String; var tooltipDesc: String; var statusText: String?; var statusColor: Color?

    @Binding var activeTooltip: String?

    @State private var isBreathing = false

    private var showCloud: Bool {
        activeTooltip == title
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.title2).foregroundStyle(LinearGradient(colors: [colorScheme == .dark ? .white : color, color], startPoint: .topLeading, endPoint: .bottomTrailing))
                VStack(spacing: 2) {
                    Text(value).font(.system(size: 16, weight: .bold)).foregroundColor(colorScheme == .dark ? .white : .black)
                    Text(title).font(.system(size: 11)).foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 16).background(.ultraThinMaterial).background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.primary.opacity(0.05), lineWidth: 1))
            .shadow(color: color.opacity(isBreathing ? 0.3 : 0.05), radius: isBreathing ? 15 : 5, y: 5)
            .onTapGesture {
                HapticManager.shared.impact(.medium)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {

                    if activeTooltip == title {
                        activeTooltip = nil
                    } else {
                        activeTooltip = title
                    }
                }

                if activeTooltip == title {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {

                            if activeTooltip == title {
                                activeTooltip = nil
                            }
                        }
                    }
                }
            }
            .onAppear { withAnimation(.easeInOut(duration: .random(in: 1.5...2.5)).repeatForever(autoreverses: true)) { isBreathing = true } }

            if showCloud {
                VStack(spacing: 0) {
                    VStack(spacing: 6) {
                        Text(tooltipTitle).font(.system(size: 12, weight: .bold)).foregroundColor(.black)
                        Text(tooltipDesc).font(.system(size: 11)).foregroundColor(.black.opacity(0.8)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                        if let status = statusText, let sColor = statusColor { Text(status).font(.system(size: 12, weight: .bold)).foregroundColor(sColor).padding(.top, 2) }
                    }.padding(12).frame(width: 160).background(Color.white.opacity(0.95)).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: .black.opacity(0.3), radius: 15, y: 10)
                    Path { p in p.move(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: 16, y: 0)); p.addLine(to: CGPoint(x: 8, y: 8)); p.closeSubpath() }
                        .fill(Color.white.opacity(0.95)).frame(width: 16, height: 8)
                }.offset(y: -110).transition(.scale(scale: 0.5, anchor: .bottom).combined(with: .opacity)).zIndex(100)
            }
        }
    }
}

struct HistorySearchBar: View {
    @Binding var text: String
    @Binding var isSearching: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            Button(action: { withAnimation { isSearching = true } }) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(isSearching ? .cyan : .gray)
                    .font(.system(size: 18, weight: .bold))
            }

            TextField("Найти или добавить (напр. Тренировка Арнольда)", text: $text)
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .onTapGesture { withAnimation { isSearching = true } }
                .onChange(of: text) { _ in withAnimation { isSearching = true } }

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                }
            }
        }
        .padding(14).background(.ultraThinMaterial).background(isSearching ? Color.cyan.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(isSearching ? Color.cyan.opacity(0.5) : Color.primary.opacity(0.05), lineWidth: 1))
        .shadow(color: isSearching ? .cyan.opacity(0.2) : .clear, radius: 10).padding(.horizontal, 20)
    }
}

struct SearchResultsDropdown: View {
    @Binding var results: [SearchedWorkout]
    var searchText: String
    var onSelect: (SearchedWorkout) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var filtered: [SearchedWorkout] {
        if searchText.isEmpty { return results }
        let query = searchText.lowercased()
        let f = results.filter { $0.name.lowercased().contains(query) || $0.description.lowercased().contains(query) }
        return f.isEmpty ? [SearchedWorkout(name: searchText, description: "Сгенерировать новую тренировку")] : f
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(filtered.indices, id: \.self) { index in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(filtered[index].name).font(.system(size: 16, weight: .bold)).foregroundColor(colorScheme == .dark ? .white : .black)
                        Text(filtered[index].description).font(.system(size: 12)).foregroundColor(.gray).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(filtered[index]) }

                    Button(action: {
                        withAnimation { results[index].isFavorite.toggle() }
                        HapticManager.shared.impact(.light)
                    }) {
                        Image(systemName: filtered[index].isFavorite ? "star.fill" : "star")
                            .font(.system(size: 20))
                            .foregroundColor(filtered[index].isFavorite ? .yellow : .gray.opacity(0.5))
                            .padding(12)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(Circle())
                    }
                }
                .padding(.vertical, 12).padding(.horizontal, 16).background(Color.primary.opacity(0.01))

                if index < filtered.count - 1 {
                    Divider().background(Color.primary.opacity(0.1)).padding(.horizontal, 16)
                }
            }
        }
        .background(colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.12) : Color.white).clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.05), lineWidth: 1)).padding(.horizontal, 20)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
}

struct PremiumCategoriesIslands: View {
    @Binding var selectedFilter: WorkoutView.FilterPeriod
    @Binding var showFavoritesOnly: Bool

    var body: some View {
        HStack(spacing: 12) {
            PremiumCategoryCard(
                title: "Все\nтренировки",
                icon: "list.bullet",
                color: selectedFilter == .all && !showFavoritesOnly ? .cyan : .gray,
                isActive: selectedFilter == .all && !showFavoritesOnly
            ) {
                selectedFilter = .all
                showFavoritesOnly = false
            }

            PremiumCategoryCard(
                title: "Избранные\nтренировки",
                icon: "star.fill",
                color: showFavoritesOnly ? .yellow : .gray,
                isActive: showFavoritesOnly
            ) {
                showFavoritesOnly = true
            }

            PremiumCategoryCard(
                title: "Лучшие\nза месяц",
                icon: "flame.fill",
                color: selectedFilter == .month ? .red : .gray,
                isActive: selectedFilter == .month && !showFavoritesOnly
            ) {
                selectedFilter = .month
                showFavoritesOnly = false
            }
        }
        .padding(.horizontal, 20)
    }
}

struct PremiumCategoryCard: View {
    let title: String; let icon: String; let color: Color; let isActive: Bool
    let action: () -> Void
    @State private var isBreathing = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: {
            HapticManager.shared.selection()
            action()
        }) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(LinearGradient(colors: [colorScheme == .dark ? .white : color, color], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: color.opacity(0.5), radius: isBreathing && isActive ? 8 : 2)

                Text(title)
                    .font(.system(size: 12, weight: .bold))

                    .foregroundColor(isActive ? (colorScheme == .dark ? .white : color) : .gray)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)

            .background(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white))
            .background(color.opacity(isActive ? 0.15 : 0.05))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(isActive ? color.opacity(0.5) : Color.primary.opacity(0.05), lineWidth: 1))
            .shadow(color: color.opacity(isBreathing && isActive ? 0.3 : 0.05), radius: isBreathing && isActive ? 15 : 5, y: 5)
            .onAppear {
                withAnimation(.easeInOut(duration: .random(in: 1.5...2.5)).repeatForever(autoreverses: true)) { isBreathing = true }
            }
        }
        .buttonStyle(.plain)
    }
}

struct QuickWorkoutDetailSheet: View {
    @Binding var workout: SearchedWorkout
    var onAddWorkout: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.12) : Color.white).edgesIgnoringSafeArea(.all)

            VStack(spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(workout.name)
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? .white : .black)

                        Text("Информация о тренировке")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()

                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { workout.isFavorite.toggle() }
                        HapticManager.shared.impact(.medium)
                    }) {
                        Image(systemName: workout.isFavorite ? "star.fill" : "star")
                            .font(.system(size: 24))
                            .foregroundColor(workout.isFavorite ? .yellow : .gray.opacity(0.5))
                            .padding(14)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(Circle())
                            .scaleEffect(workout.isFavorite ? 1.1 : 1.0)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "doc.text.fill").foregroundColor(.cyan)
                        Text("Описание").font(.headline).foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                    Text(workout.description)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                        .lineSpacing(6)
                }
                .padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Color.primary.opacity(0.03)).cornerRadius(20).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.primary.opacity(0.05), lineWidth: 1))

                Spacer()

                Button(action: onAddWorkout) {
                    HStack {
                        Image(systemName: "plus.circle.fill").font(.title3)
                        Text("Создать в моей базе").font(.system(size: 18, weight: .bold))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
                    .background(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white).clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .cyan.opacity(0.4), radius: 15, y: 5)
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 24).padding(.top, 40)
        }
    }
}

#if canImport(UIKit)
import UIKit

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif
