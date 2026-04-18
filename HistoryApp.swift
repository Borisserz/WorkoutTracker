import SwiftUI

// MARK: - ТОЧКА ВХОДА
@main
struct TrackerApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}

// MARK: - ПЛАВАЮЩИЙ TAB BAR
struct MainTabView: View {
    @State private var selectedTab: Tab = .history
    
    enum Tab: String, CaseIterable {
        case progress = "chart.xyaxis.line"
        case history = "clock.fill"
        case profile = "person.circle.fill"
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                Color.black.ignoresSafeArea().tag(Tab.progress)
                HistoryView().tag(Tab.history)
                Color.black.ignoresSafeArea().tag(Tab.profile)
            }
            
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.rawValue) { tab in
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        VStack(spacing: 6) {
                            Image(systemName: tab.rawValue)
                                .font(.system(size: 22, weight: selectedTab == tab ? .bold : .regular))
                                .foregroundColor(selectedTab == tab ? .white : .gray.opacity(0.5))
                                .scaleEffect(selectedTab == tab ? 1.15 : 1.0)
                            
                            Circle()
                                .fill(selectedTab == tab ? Color.purple : Color.clear)
                                .frame(width: 4, height: 4)
                                .shadow(color: .purple, radius: 4)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                }
            }
            .frame(height: 70)
            .background(.ultraThinMaterial)
            .background(Color.white.opacity(0.05))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
            .shadow(color: .purple.opacity(0.15), radius: 20, y: 10)
            .padding(.horizontal, 40)
            .padding(.bottom, 10)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - МОДЕЛИ ДАННЫХ
struct SearchedWorkout: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let description: String
    var isFavorite: Bool = false
}

struct AddedWorkout: Identifiable {
    let id = UUID()
    let name: String
    let difficulty: Int
    let totalWeight: Int
    let exerciseCount: Int
}

// MARK: - ЭКРАН ИСТОРИИ
struct HistoryView: View {
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var showSparks = false
    
    // Для открытия окна с деталями тренировки
    @State private var showDetailSheet = false
    @State private var detailWorkoutId: UUID? = nil
    
    // БАЗА ИЗ 8 ТРЕНИРОВОК
    @State private var searchDatabase: [SearchedWorkout] = [
        SearchedWorkout(name: "Тренировка Арнольда", description: "Классическая программа Золотой Эры: суперсеты на грудь и спину для максимального пампа и расширения грудной клетки."),
        SearchedWorkout(name: "Тренировка: Фуллбоди База", description: "Мощный фундамент. Приседания, жим лёжа и становая тяга в одну сессию. Идеально для выброса тестостерона."),
        SearchedWorkout(name: "Тренировка: Сплит Грудь/Трицепс", description: "Убойная сессия на жимовые мышцы. Включает тяжелый жим штанги, разводки и французский жим."),
        SearchedWorkout(name: "Тренировка: Убийца Ног 3000", description: "Только для смелых. Тяжелый присед, жим ногами и выпады. На следующий день ходить будет тяжело!"),
        SearchedWorkout(name: "Тренировка: Дельты-Пушки", description: "Фокус на плечи. Армейский жим, махи в стороны и тяга к подбородку сделают твои плечи круглыми как шары."),
        SearchedWorkout(name: "Тренировка: Спина Демона", description: "Подтягивания с дополнительным весом, тяжелая тяга штанги в наклоне. Строим V-образный силуэт."),
        SearchedWorkout(name: "Тренировка: Кардио-Интенсив", description: "Интервальная (HIIT) тренировка. Пульс 160+, пот ручьем, сжигание жира на максималках."),
        SearchedWorkout(name: "Тренировка: Стальной Кор", description: "Прокачка пресса до глубоких кубиков. Планки, скручивания и подъемы ног в висе на турнике.")
    ]
    
    @State private var myWorkouts: [AddedWorkout] = []
    
    var body: some View {
        ZStack {
            HistoryBreathingBackground()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    HistoryHeader()
                    
                    TopStatsIslandsView()
                    
                    // ПОИСКОВИК
                    VStack(spacing: 12) {
                        SearchBar(text: $searchText, isSearching: $isSearching)
                        
                        if isSearching && !searchText.isEmpty {
                            SearchResultsDropdown(
                                results: $searchDatabase,
                                searchText: searchText,
                                onSelect: { workout in
                                    // При нажатии открываем детальное окно
                                    hideKeyboard()
                                    detailWorkoutId = workout.id
                                    showDetailSheet = true
                                }
                            )
                        }
                    }
                    .zIndex(20)
                    
                    PremiumCategoriesIslands()
                        .zIndex(10)
                    
                    // ДОБАВЛЕННЫЕ ТРЕНИРОВКИ (ВНИЗУ)
                    if !myWorkouts.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Добавленные тренировки")
                                .font(.title3).bold()
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                            
                            ForEach(myWorkouts) { workout in
                                PremiumAddedWorkoutCard(workout: workout)
                                    .transition(.scale.combined(with: .opacity).combined(with: .move(edge: .bottom)))
                            }
                        }
                    }
                    
                    Spacer().frame(height: 120)
                }
                .padding(.top, 20)
            }
            .onTapGesture {
                hideKeyboard()
                withAnimation { isSearching = false }
            }
            
            if showSparks {
                ParticleExplosionView().allowsHitTesting(false)
            }
        }
        // ВЫЗОВ МОДАЛЬНОГО ОКНА ДЛЯ ТРЕНИРОВКИ
        .sheet(isPresented: $showDetailSheet) {
            if let id = detailWorkoutId, let index = searchDatabase.firstIndex(where: { $0.id == id }) {
                WorkoutDetailSheet(
                    workout: $searchDatabase[index],
                    onAddWorkout: {
                        addWorkout(name: searchDatabase[index].name)
                        showDetailSheet = false // Закрываем окно
                        triggerSparks()         // Вызываем искры
                    }
                )
                .presentationDetents([.fraction(0.65)]) // Окно займет 65% экрана снизу
                .presentationDragIndicator(.visible)
            }
        }
    }
    
    private func addWorkout(name: String) {
        let newWorkout = AddedWorkout(
            name: name,
            difficulty: Int.random(in: 3...5),
            totalWeight: Int.random(in: 4000...15000),
            exerciseCount: Int.random(in: 5...12)
        )
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            myWorkouts.insert(newWorkout, at: 0)
        }
        searchText = ""
        isSearching = false
    }
    
    private func triggerSparks() {
        showSparks = true
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showSparks = false
        }
    }
}

// MARK: - МОДАЛЬНОЕ ОКНО ОПИСАНИЯ ТРЕНИРОВКИ (НОВАЯ КРУТАЯ ФИЧА)
struct WorkoutDetailSheet: View {
    @Binding var workout: SearchedWorkout
    var onAddWorkout: () -> Void
    
    var body: some View {
        ZStack {
            Color(red: 0.1, green: 0.1, blue: 0.12).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                // Заголовок и звездочка
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(workout.name)
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Информация о тренировке")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    
                    // Звездочка Избранного
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            workout.isFavorite.toggle()
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }) {
                        Image(systemName: workout.isFavorite ? "star.fill" : "star")
                            .font(.system(size: 24))
                            .foregroundColor(workout.isFavorite ? .yellow : .gray.opacity(0.5))
                            .padding(14)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Circle())
                            .scaleEffect(workout.isFavorite ? 1.1 : 1.0)
                    }
                }
                
                // Карточка описания
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(.purple)
                        Text("Описание")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    
                    Text(workout.description)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(6)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.03))
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.05), lineWidth: 1))
                
                Spacer()
                
                // Огромная кнопка "Добавить"
                Button(action: onAddWorkout) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                        Text("Добавить в Историю")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(LinearGradient(colors: [.purple, .cyan], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .purple.opacity(0.4), radius: 15, y: 5)
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - ПОИСК И ВЫПАДАЮЩИЙ СПИСОК
struct SearchBar: View {
    @Binding var text: String
    @Binding var isSearching: Bool
    
    var body: some View {
        HStack {
            // КЛИКАБЕЛЬНАЯ ЛУПА
            Button(action: {
                withAnimation { isSearching = true }
            }) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(isSearching ? .purple : .gray)
                    .font(.system(size: 18, weight: .bold))
            }
            
            TextField("Найти тренировку (напр. Тренировка Арнольда)", text: $text)
                .foregroundColor(.white)
                .onTapGesture { withAnimation { isSearching = true } }
                .onChange(of: text) { _ in
                    withAnimation { isSearching = true }
                }
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                }
            }
        }
        .padding(14).background(.ultraThinMaterial).background(isSearching ? Color.purple.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(isSearching ? Color.purple.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1))
        .shadow(color: isSearching ? .purple.opacity(0.2) : .clear, radius: 10).padding(.horizontal, 20)
    }
}

struct SearchResultsDropdown: View {
    @Binding var results: [SearchedWorkout]
    var searchText: String
    var onSelect: (SearchedWorkout) -> Void
    
    var filtered: [SearchedWorkout] {
        if searchText.isEmpty { return results }
        // Фильтрация без учета регистра
        let query = searchText.lowercased()
        let f = results.filter { $0.name.lowercased().contains(query) || $0.description.lowercased().contains(query) }
        
        // Если ничего не найдено, предлагаем создать новую
        return f.isEmpty ? [SearchedWorkout(name: searchText, description: "Сгенерировать новую тренировку")] : f
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(filtered.indices, id: \.self) { index in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(filtered[index].name).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                        Text(filtered[index].description).font(.system(size: 12)).foregroundColor(.gray).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelect(filtered[index]) // ОТКРЫВАЕТ ОКНО
                    }
                    
                    // Быстрое добавление в избранное прямо из поиска
                    Button(action: {
                        withAnimation { results[index].isFavorite.toggle() }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        Image(systemName: filtered[index].isFavorite ? "star.fill" : "star")
                            .font(.system(size: 20))
                            .foregroundColor(filtered[index].isFavorite ? .yellow : .gray.opacity(0.5))
                            .padding(12)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Circle())
                    }
                }
                .padding(.vertical, 12).padding(.horizontal, 16).background(Color.white.opacity(0.01))
                
                if index < filtered.count - 1 {
                    Divider().background(Color.white.opacity(0.1)).padding(.horizontal, 16)
                }
            }
        }
        .background(Color(red: 0.1, green: 0.1, blue: 0.12)).clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1)).padding(.horizontal, 20)
    }
}

// MARK: - ПРЕМИУМ-ОСТРОВКИ КАТЕГОРИЙ
struct PremiumCategoriesIslands: View {
    let cats = [
        ("Избранные", "star.fill", Color.yellow),
        ("Лучшие\nза всё время", "crown.fill", Color.orange),
        ("Лучшие\nпо сочетанию", "flame.fill", Color.red)
    ]
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<cats.count, id: \.self) { i in
                PremiumCategoryCard(title: cats[i].0, icon: cats[i].1, color: cats[i].2)
            }
        }
        .padding(.horizontal, 20)
    }
}

struct PremiumCategoryCard: View {
    let title: String; let icon: String; let color: Color
    @State private var isBreathing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundStyle(LinearGradient(colors: [.white, color], startPoint: .topLeading, endPoint: .bottomTrailing)).shadow(color: color.opacity(0.5), radius: isBreathing ? 8 : 2)
            Text(title).font(.system(size: 12, weight: .bold)).foregroundColor(.white).lineLimit(2).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(16)
        .background(.ultraThinMaterial).background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .shadow(color: color.opacity(isBreathing ? 0.3 : 0.05), radius: isBreathing ? 15 : 5, y: 5)
        .onAppear { withAnimation(.easeInOut(duration: .random(in: 1.5...2.5)).repeatForever(autoreverses: true)) { isBreathing = true } }
    }
}

// MARK: - ДОБАВЛЕННАЯ ТРЕНИРОВКА
struct PremiumAddedWorkoutCard: View {
    let workout: AddedWorkout
    @State private var isBreathing = false
    @State private var rotation: Double = 0
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.white.opacity(0.1)).frame(width: 50, height: 50)
                Text(workout.difficulty >= 4 ? "🔥" : "⚡️").font(.title2)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(workout.name).font(.headline).foregroundColor(.white)
                HStack(spacing: 8) {
                    HStack(spacing: 2) { ForEach(0..<workout.difficulty, id: \.self) { _ in Text("🔥").font(.caption) } }
                    Text("•").foregroundColor(.gray)
                    Text("\(workout.exerciseCount) упр.").font(.caption).foregroundColor(.gray)
                    Text("•").foregroundColor(.gray)
                    Text("\(workout.totalWeight) кг").font(.caption).bold().foregroundColor(.cyan)
                }
            }
            Spacer()
        }
        .padding().background(Color(red: 0.1, green: 0.1, blue: 0.13))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20).stroke(
                AngularGradient(gradient: Gradient(colors: [.purple, .cyan, .clear, .clear, .purple]), center: .center, startAngle: .degrees(rotation), endAngle: .degrees(rotation + 360)), lineWidth: 2
            )
        )
        .shadow(color: .purple.opacity(isBreathing ? 0.2 : 0.0), radius: 10).padding(.horizontal, 20)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { isBreathing = true }
            withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) { rotation = 360 }
        }
    }
}

// MARK: - ВЕРХНИЕ ОСТРОВКИ
struct TopStatsIslandsView: View {
    var body: some View {
        HStack(spacing: 12) {
            StatIslandWithTooltip(icon: "clock.fill", title: "Время", value: "1ч 15м", color: .blue, tooltipTitle: "Средняя длительность", tooltipDesc: "Отличное время под нагрузкой.", statusText: nil, statusColor: nil)
            StatIslandWithTooltip(icon: "dumbbell.fill", title: "Вес", value: "4.5 т", color: .purple, tooltipTitle: "Средний вес", tooltipDesc: "Ваш суммарный средний тоннаж.", statusText: nil, statusColor: nil)
            StatIslandWithTooltip(icon: "heart.fill", title: "Пульс", value: "142", color: .red, tooltipTitle: "Средний пульс", tooltipDesc: "Ваш пульс в норме.", statusText: "Идеальный показатель", statusColor: .green)
        }.padding(.horizontal, 20).zIndex(30)
    }
}

struct StatIslandWithTooltip: View {
    var icon: String; var title: String; var value: String; var color: Color
    var tooltipTitle: String; var tooltipDesc: String; var statusText: String?; var statusColor: Color?
    @State private var isBreathing = false; @State private var showCloud = false
    
    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.title2).foregroundStyle(LinearGradient(colors: [.white, color], startPoint: .topLeading, endPoint: .bottomTrailing))
                VStack(spacing: 2) { Text(value).font(.system(size: 16, weight: .bold)).foregroundColor(.white); Text(title).font(.system(size: 11)).foregroundColor(.gray) }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 16).background(.ultraThinMaterial).background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
            .shadow(color: color.opacity(isBreathing ? 0.3 : 0.05), radius: isBreathing ? 15 : 5, y: 5)
            .onLongPressGesture(minimumDuration: 0.1, maximumDistance: 50, perform: {}, onPressingChanged: { isPressing in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showCloud = isPressing; if isPressing { UIImpactFeedbackGenerator(style: .medium).impactOccurred() } }
            })
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

// MARK: - ХЕДЕР И ФОН
struct HistoryHeader: View {
    var body: some View {
        HStack {
            Text("История").font(.system(size: 34, weight: .black, design: .rounded)).foregroundColor(.white)
            Text("🕒").font(.system(size: 30))
            Spacer()
        }.padding(.horizontal, 20)
    }
}

struct ParticleExplosionView: View {
    @State private var animate = false
    var body: some View {
        ZStack {
            ForEach(0..<20, id: \.self) { i in
                Circle().fill(Color(red: .random(in: 0.5...1), green: .random(in: 0...0.5), blue: .random(in: 0.5...1)))
                    .frame(width: CGFloat.random(in: 5...12), height: CGFloat.random(in: 5...12))
                    .offset(x: animate ? CGFloat.random(in: -150...150) : 0, y: animate ? CGFloat.random(in: -150...150) : 0)
                    .opacity(animate ? 0 : 1).scaleEffect(animate ? 0.1 : 1)
                    .animation(.easeOut(duration: 0.8).delay(Double.random(in: 0...0.2)), value: animate)
            }
        }.onAppear { animate = true }
    }
}

struct HistoryBreathingBackground: View {
    @State private var phase = false
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.07).edgesIgnoringSafeArea(.all)
            Circle().fill(Color.purple.opacity(0.08)).frame(width: 400).blur(radius: 120).offset(x: phase ? -40 : 40, y: phase ? -50 : 50).scaleEffect(phase ? 1.1 : 0.9)
            Circle().fill(Color.cyan.opacity(0.05)).frame(width: 300).blur(radius: 100).offset(x: phase ? 60 : -60, y: phase ? 80 : -80).scaleEffect(phase ? 1.2 : 0.8)
                .onAppear { withAnimation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true)) { phase = true } }
        }
    }
}

#if canImport(UIKit)
extension View { func hideKeyboard() { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } }
#endif
