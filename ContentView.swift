import SwiftUI
import Charts

@main
struct TrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ProgressView()
        }
    }
}

// MARK: - Основной экран
struct ProgressView: View {
    @State private var showingAddGoal = false
    @State private var showProfile = false
    @State private var selectedPeriod = "День"
    let periods = ["День", "Месяц", "Год"]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.07).edgesIgnoringSafeArea(.all)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        HeaderView(showProfile: $showProfile)
                        
                        MascotStreakView()
                        GoalsSectionView(showingAddGoal: $showingAddGoal)
                        AIIslandView()
                        
                        VStack(spacing: 16) {
                            PeriodPicker(selectedPeriod: $selectedPeriod, periods: periods)
                            QuickStatsView(period: selectedPeriod)
                        }
                        
                        ComparisonSectionView()
                        AdvancedStatsSectionView()
                        AllTimeResultsView()
                        
                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddGoal) {
                AddGoalSheet()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .preferredColorScheme(.dark)
        }
    }
}

// MARK: - 1. Хедер
struct HeaderView: View {
    @Binding var showProfile: Bool
    
    var body: some View {
        HStack {
            Text("Прогресс")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundColor(.white)
            Spacer()
            
            Button(action: { showProfile = true }) {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    .foregroundStyle(.purple, .white.opacity(0.8))
            }
        }
        .padding(.top, 10)
    }
}

// MARK: - 2. Маскот и Стрик (С ТВОИМ МАСКОТОМ)
struct MascotStreakView: View {
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 60, height: 60)
                    .shadow(color: .orange.opacity(0.5), radius: 10, x: 0, y: 5)
                
                // ЗДЕСЬ ТВОЯ КАРТИНКА (вместо лисы)
                Image("fire_mascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .offset(y: -3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Ты в ударе, машина! 🔥")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text("3 дня тренировок подряд")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.03))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
}

// MARK: - 3. Цели
struct GoalsSectionView: View {
    @Binding var showingAddGoal: Bool
    
    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Ваши цели")
                    .font(.title2).bold()
                    .foregroundColor(.white)
                Text("Бросьте вызов себе")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
            
            Button(action: { showingAddGoal = true }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Добавить цель")
                }
                .font(.system(size: 14, weight: .bold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white)
                .foregroundColor(.black)
                .clipShape(Capsule())
            }
        }
    }
}

// MARK: - 4. Обзор с ИИ
struct AIIslandView: View {
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(LinearGradient(colors: [.purple, .cyan], startPoint: .top, endPoint: .bottom))
            
            Text("Обзор эффективности с ИИ")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.5))
        }
        .padding()
        .background(.ultraThinMaterial)
        .background(
            LinearGradient(colors: [Color.purple.opacity(0.2), Color.blue.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .shadow(color: .purple.opacity(0.15), radius: 20, x: 0, y: 10)
    }
}

// MARK: - 5. Карусель Времени и Быстрые Статы
struct PeriodPicker: View {
    @Binding var selectedPeriod: String
    let periods: [String]
    @Namespace private var animation
    
    var body: some View {
        HStack {
            ForEach(periods, id: \.self) { period in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedPeriod = period
                    }
                }) {
                    Text(period)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(selectedPeriod == period ? .black : .gray)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            ZStack {
                                if selectedPeriod == period {
                                    Capsule()
                                        .fill(Color.white)
                                        .matchedGeometryEffect(id: "ACTIVETAB", in: animation)
                                }
                            }
                        )
                }
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.05))
        .clipShape(Capsule())
    }
}

struct QuickStatsView: View {
    var period: String
    
    var body: some View {
        HStack(spacing: 12) {
            StatCard(icon: "figure.run", title: "Тренировки", value: period == "День" ? "1" : "12")
            StatCard(icon: "dumbbell.fill", title: "Объем (кг)", value: period == "День" ? "4 500" : "54 200")
            StatCard(icon: "map.fill", title: "Дистанция", value: period == "День" ? "2.3 км" : "34 км")
        }
    }
}

struct StatCard: View {
    var icon: String
    var title: String
    var value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.03))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
}

// MARK: - 6. Сравнение дней
struct ComparisonData: Identifiable {
    var id = UUID()
    var day: String
    var volume: Double
    var color: Color
}

struct ComparisonSectionView: View {
    let data: [ComparisonData] = [
        ComparisonData(day: "13 Апр", volume: 3200, color: .gray.opacity(0.5)),
        ComparisonData(day: "14 Апр", volume: 4500, color: .purple)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Детальное сравнение")
                .font(.title3).bold()
                .foregroundColor(.white)
            
            VStack(spacing: 20) {
                Chart {
                    ForEach(data) { item in
                        BarMark(
                            x: .value("День", item.day),
                            y: .value("Объем", item.volume)
                        )
                        .foregroundStyle(item.color)
                        .cornerRadius(6)
                    }
                }
                .frame(height: 150)
                .chartYAxis(.hidden)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("13 Апреля").font(.caption).foregroundColor(.gray)
                        Text("3 200 кг").font(.headline).foregroundColor(.white)
                    }
                    Spacer()
                    Text("VS").font(.headline).foregroundColor(.white.opacity(0.2))
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("14 Апреля").font(.caption).foregroundColor(.gray)
                        Text("4 500 кг").font(.headline).foregroundColor(.purple)
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.03))
            .cornerRadius(20)
        }
        .padding(.top, 10)
    }
}

// MARK: - 7. Расширенная статистика
struct AdvancedStatsSectionView: View {
    @State private var openTab: Int? = 1
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Расширенная статистика")
                .font(.title3).bold()
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                CustomDisclosure(title: "Стиль и оборудование", isExpanded: Binding(get: { openTab == 0 }, set: { if $0 { openTab = 0 } else { openTab = nil } })) {
                    Text("Силовая тренировка • Свободные веса (80%)").font(.subheadline).foregroundColor(.gray)
                }
                
                CustomDisclosure(title: "Подходы на группу мышц", isExpanded: Binding(get: { openTab == 1 }, set: { if $0 { openTab = 1 } else { openTab = nil } })) {
                    VStack(spacing: 10) {
                        MuscleRow(name: "Грудь (Синий)", sets: 12, color: .blue, max: 15)
                        MuscleRow(name: "Спина (Зеленый)", sets: 15, color: .green, max: 15)
                        MuscleRow(name: "Ноги (Красный)", sets: 8, color: .red, max: 15)
                    }
                }
                
                CustomDisclosure(title: "Распределение мышц (График)", isExpanded: Binding(get: { openTab == 2 }, set: { if $0 { openTab = 2 } else { openTab = nil } })) {
                    Chart {
                        SectorMark(angle: .value("Грудь", 30), innerRadius: .ratio(0.6), angularInset: 2).foregroundStyle(.blue)
                        SectorMark(angle: .value("Спина", 45), innerRadius: .ratio(0.6), angularInset: 2).foregroundStyle(.green)
                        SectorMark(angle: .value("Ноги", 25), innerRadius: .ratio(0.6), angularInset: 2).foregroundStyle(.red)
                    }
                    .frame(height: 150)
                }
                
                CustomDisclosure(title: "Карта тела (Анатомия)", isExpanded: Binding(get: { openTab == 3 }, set: { if $0 { openTab = 3 } else { openTab = nil } })) {
                    ZStack {
                        Image(systemName: "figure.arms.open")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 150)
                            .foregroundColor(.white.opacity(0.1))
                        
                        Circle().fill(.blue).frame(width: 20).offset(x: 0, y: -20).blur(radius: 5)
                        Circle().fill(.red).frame(width: 25).offset(x: 0, y: 30).blur(radius: 5)
                    }
                }
                
                CustomDisclosure(title: "Отчет за последние 20 дней", isExpanded: Binding(get: { openTab == 4 }, set: { if $0 { openTab = 4 } else { openTab = nil } })) {
                    Text("Вы стабильны! Средний объем вырос на 12% по сравнению с прошлым периодом.").font(.subheadline).foregroundColor(.gray)
                }
            }
        }
        .padding(.top, 10)
    }
}

struct CustomDisclosure<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                        .rotationEffect(.degrees(isExpanded ? -180 : 0))
                }
                .padding()
                .background(Color.white.opacity(0.03))
            }
            
            if isExpanded {
                VStack(alignment: .leading) {
                    content()
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.01))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
}

struct MuscleRow: View {
    var name: String
    var sets: Int
    var color: Color
    var max: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name).font(.caption).foregroundColor(.gray)
                Spacer()
                Text("\(sets) подх.").font(.caption).bold().foregroundColor(.white)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1)).frame(height: 8)
                    Capsule().fill(color).frame(width: geo.size.width * CGFloat(sets) / CGFloat(max), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - 8. Результаты за все время
struct AllTimeData: Identifiable {
    var id = UUID()
    var week: String
    var load: Double
}

struct AllTimeResultsView: View {
    let data: [AllTimeData] = [
        AllTimeData(week: "Нед 1", load: 20000),
        AllTimeData(week: "Нед 2", load: 22000),
        AllTimeData(week: "Нед 3", load: 18000),
        AllTimeData(week: "Лучшая", load: 31000)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("За все время")
                .font(.title3).bold()
                .foregroundColor(.white)
            
            VStack(spacing: 20) {
                Chart {
                    ForEach(data) { item in
                        LineMark(
                            x: .value("Неделя", item.week),
                            y: .value("Нагрузка", item.load)
                        )
                        .foregroundStyle(LinearGradient(colors: [.purple, .cyan], startPoint: .leading, endPoint: .trailing))
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        
                        AreaMark(
                            x: .value("Неделя", item.week),
                            y: .value("Нагрузка", item.load)
                        )
                        .foregroundStyle(LinearGradient(colors: [.purple.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                    }
                }
                .frame(height: 120)
                .chartXAxis(.hidden)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Лучшая неделя").font(.subheadline).foregroundColor(.gray)
                        Text("31 000 кг").font(.title2).bold().foregroundColor(.purple)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Всего трен.").font(.subheadline).foregroundColor(.gray)
                        Text("124").font(.title2).bold().foregroundColor(.white)
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.03))
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.05), lineWidth: 1))
        }
        .padding(.top, 10)
    }
}

// MARK: - 9. Модальное окно (Sheet) Добавления цели
struct AddGoalSheet: View {
    @Environment(\.dismiss) var dismiss
    
    let predefinedGoals = [
        "Сбросить 1 кг за неделю",
        "Тренироваться 4 раза в неделю",
        "Увеличить рабочий вес на 5%",
        "Пройти 10 000 шагов в день"
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.1, green: 0.1, blue: 0.12).edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Выбери цель из предложенных или создай свою:")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                        
                        ForEach(predefinedGoals, id: \.self) { goal in
                            Button(action: {
                                dismiss()
                            }) {
                                HStack {
                                    Text(goal)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.purple)
                                }
                                .padding()
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(16)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Новая цель")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") { dismiss() }
                        .foregroundColor(.gray)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
