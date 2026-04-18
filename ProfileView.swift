import SwiftUI
import Charts

// MARK: - Главный экран профиля
struct ProfileView: View {
    @State private var weight: Double = 75.5
    @State private var height: Int = 182
    @State private var age: Int = 24
    
    var body: some View {
        ZStack {
            BreathingBackground()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    ProfileHeader()
                    LevelProgressBar()
                    YearlyTransformationView()
                    AchievementsCarousel()
                    PersonalRecordsView()
                    BodyProgressChartView()
                    BodyStatsView(weight: $weight, height: $height, age: $age)
                    
                    Spacer().frame(height: 40)
                }
                .padding(.top, 30)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - 1. Хедер (С ТВОИМ МАСКОТОМ)
struct ProfileHeader: View {
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 80, height: 80)
                    .shadow(color: .red.opacity(0.6), radius: 20, x: 0, y: 10)
                
                // ЗДЕСЬ ТВОЯ КАРТИНКА
                Image("fire_mascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 70, height: 70)
                    .offset(y: -5)
            }
            
            VStack(spacing: 4) {
                Text("Алекс Трекер")
                    .font(.title2).bold()
                    .foregroundColor(.white)
                Text("@alex_flame")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
}

// MARK: - 2. Полоса прогресса
struct LevelProgressBar: View {
    let progress: CGFloat = 0.65
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("🕯️ Искорка").font(.caption).bold().foregroundColor(progress > 0 ? .orange : .gray)
                Spacer()
                Text("🔥 Огонек").font(.subheadline).bold().foregroundColor(.red)
                Spacer()
                Text("🌋 Воин").font(.caption).bold().foregroundColor(.gray)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.05)).frame(height: 12)
                    Capsule()
                        .fill(LinearGradient(colors: [.orange, .red, .purple], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * progress, height: 12)
                        .shadow(color: .red.opacity(0.5), radius: 8, x: 0, y: 0)
                }
            }
            .frame(height: 12)
        }
        .padding()
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.05), lineWidth: 1))
        .padding(.horizontal, 20)
    }
}

// MARK: - 3. Трансформация
struct YearlyTransformationView: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Начало года").font(.caption).foregroundColor(.gray)
                Text("Искорка 🕯️").font(.headline).foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            Image(systemName: "arrow.right").foregroundColor(.red).font(.system(size: 20, weight: .bold))
            Spacer()
            VStack(alignment: .trailing) {
                Text("Сейчас").font(.caption).foregroundColor(.gray)
                Text("Огонек 🔥").font(.headline).foregroundColor(.red)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }
}

// MARK: - 4. 3D Карусель
struct AchievementsCarousel: View {
    let achievements = [
        ("Монстр Базы", "100 кг жим", Color.blue, "Пожать на 10 кг больше, чем вчера!"),
        ("Железный стрик", "30 дней", Color.purple, "Тренироваться 30 дней подряд без пропусков."),
        ("Кардио машина", "100 км", Color.green, "Пробежать суммарно 100 км за один месяц."),
        ("Ранняя пташка", "Треня в 6:00", Color.orange, "Начать свою тренировку до 6:00 утра."),
        ("Титаниум", "Тяга 150 кг", Color.red, "Сделать становую тягу с весом 150 кг."),
        ("Воин тени", "Ночная треня", Color.indigo, "Закончить тренировку после полуночи."),
        ("Несокрушимый", "100 отжиманий", Color.cyan, "Сделать 100 отжиманий за один подход!"),
        ("Легенда", "Год без пауз", Color.yellow, "Тренироваться стабильно целый год.")
    ]
    
    @State private var currentIndex: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0
    
    var body: some View {
        let total = CGFloat(achievements.count)
        let current = currentIndex - (dragOffset / 250)
        
        VStack(alignment: .leading, spacing: 16) {
            Text("Ваши трофеи (Удерживай)")
                .font(.title3).bold()
                .foregroundColor(.white)
                .padding(.horizontal, 20)
            
            ZStack {
                ForEach(0..<achievements.count, id: \.self) { i in
                    let distance = shortestDistance(from: current, to: CGFloat(i), total: total)
                    let angle = distance * (360.0 / total)
                    let angleRad = angle * .pi / 180
                    
                    let x = sin(angleRad) * 280
                    let z = cos(angleRad)
                    
                    let scale = 0.75 + 0.25 * z
                    let opacity = max(0, 0.1 + 0.9 * z)
                    
                    AchievementCard(
                        title: achievements[i].0,
                        sub: achievements[i].1,
                        glowColor: achievements[i].2,
                        description: achievements[i].3
                    )
                    .offset(x: x)
                    .scaleEffect(scale)
                    .opacity(z > -0.3 ? opacity : 0)
                    .zIndex(z)
                    .rotation3DEffect(.degrees(angle * 0.7), axis: (x: 0, y: 1, z: 0))
                }
            }
            .frame(height: 240)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .updating($dragOffset) { val, state, _ in
                        state = val.translation.width
                    }
                    .onEnded { val in
                        let moved = val.translation.width / 250
                        let target = round(currentIndex - moved)
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            currentIndex = target
                        }
                    }
            )
        }
    }
    
    func shortestDistance(from current: CGFloat, to target: CGFloat, total: CGFloat) -> CGFloat {
        let diff = target - current
        var wrapped = diff.truncatingRemainder(dividingBy: total)
        if wrapped < 0 { wrapped += total }
        if wrapped > total / 2.0 { wrapped -= total }
        return wrapped
    }
}

struct AchievementCard: View {
    let title: String
    let sub: String
    let glowColor: Color
    let description: String
    
    @State private var isBreathing = false
    @State private var showCloud = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 12) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(LinearGradient(colors: [.white, glowColor], startPoint: .topLeading, endPoint: .bottomTrailing))
                
                VStack(spacing: 4) {
                    Text(title).font(.system(size: 14, weight: .bold)).foregroundColor(.white).multilineTextAlignment(.center)
                    Text(sub).font(.caption).foregroundColor(.gray)
                }
            }
            .frame(width: 130, height: 160)
            .background(.ultraThinMaterial)
            .background(glowColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 1))
            .shadow(color: glowColor.opacity(isBreathing ? 0.4 : 0.1), radius: isBreathing ? 15 : 5)
            .onLongPressGesture(minimumDuration: 0.1, maximumDistance: 50, perform: {
            }, onPressingChanged: { isPressing in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    showCloud = isPressing
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }
            })
            .onAppear {
                withAnimation(.easeInOut(duration: .random(in: 1.5...2.5)).repeatForever(autoreverses: true)) {
                    isBreathing = true
                }
            }
            
            if showCloud {
                VStack(spacing: 0) {
                    Text(description)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.black.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.95))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .white.opacity(0.4), radius: 10, y: 5)
                    
                    BubbleTail()
                        .fill(Color.white.opacity(0.95))
                        .frame(width: 14, height: 8)
                }
                .offset(y: -175)
                .transition(.scale(scale: 0.5, anchor: .bottom).combined(with: .opacity))
                .zIndex(10)
            }
        }
    }
}

struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - 5. Личные Рекорды
struct PersonalRecordsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Личные рекорды")
                .font(.title3).bold()
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                RecordRow(title: "Жим лежа", value: "100 кг", period: "За год")
                RecordRow(title: "Присед", value: "120 кг", period: "За месяц")
                RecordRow(title: "Мертвая тяга", value: "140 кг", period: "За все время")
            }
            .padding()
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .padding(.horizontal, 20)
    }
}

struct RecordRow: View {
    var title: String
    var value: String
    var period: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title).font(.headline).foregroundColor(.white)
                Text(period).font(.caption).foregroundColor(.gray)
            }
            Spacer()
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 6. График прогресса (С ТВОИМ МАСКОТОМ)
struct BodyProgressData: Identifiable {
    let id = UUID()
    let day: String
    let value: Double
}

struct BodyProgressChartView: View {
    let data: [BodyProgressData] = [
        BodyProgressData(day: "1", value: 80.5),
        BodyProgressData(day: "2", value: 79.8),
        BodyProgressData(day: "3", value: 79.5),
        BodyProgressData(day: "4", value: 78.2),
        BodyProgressData(day: "5", value: 78.6),
        BodyProgressData(day: "6", value: 77.0),
        BodyProgressData(day: "7", value: 76.1),
        BodyProgressData(day: "8", value: 75.5)
    ]
    
    @State private var mascotBreathe = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Динамика изменений").font(.title3).bold().foregroundColor(.white)
                Spacer()
                Text("-5.0 кг!").font(.caption).bold().padding(.horizontal, 8).padding(.vertical, 4).background(Color.green.opacity(0.2)).foregroundColor(.green).clipShape(Capsule())
            }
            
            Chart {
                ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                    LineMark(x: .value("День", item.day), y: .value("Вес", item.value))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    
                    AreaMark(x: .value("День", item.day), y: .value("Вес", item.value))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(LinearGradient(colors: [.red.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom))
                    
                    if index == data.count - 1 {
                        PointMark(x: .value("День", item.day), y: .value("Вес", item.value))
                            .foregroundStyle(.clear)
                            .annotation(position: .top, alignment: .center) {
                                // ЗДЕСЬ ТВОЯ КАРТИНКА ДЫШИТ НАД ГРАФИКОМ
                                Image("fire_mascot")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 45, height: 45)
                                    .shadow(color: .orange, radius: mascotBreathe ? 10 : 2)
                                    .scaleEffect(mascotBreathe ? 1.15 : 0.95)
                                    .offset(y: -15)
                                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: mascotBreathe)
                                    .onAppear { mascotBreathe = true }
                            }
                    }
                }
            }
            .frame(height: 140)
            .chartYScale(domain: 74...82)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
        }
        .padding()
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.05), lineWidth: 1))
        .padding(.horizontal, 20)
    }
}

// MARK: - 7. Антропометрия
struct BodyStatsView: View {
    @Binding var weight: Double
    @Binding var height: Int
    @Binding var age: Int
    
    var body: some View {
        HStack(spacing: 12) {
            StatAdjuster(title: "Вес", value: String(format: "%.1f", weight), unit: "кг", onMinus: { weight -= 0.5 }, onPlus: { weight += 0.5 })
            StatAdjuster(title: "Рост", value: "\(height)", unit: "см", onMinus: { height -= 1 }, onPlus: { height += 1 })
            StatAdjuster(title: "Возраст", value: "\(age)", unit: "лет", onMinus: { age -= 1 }, onPlus: { age += 1 })
        }
        .padding(.horizontal, 20)
    }
}

struct StatAdjuster: View {
    var title: String; var value: String; var unit: String
    var onMinus: () -> Void; var onPlus: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Text(title).font(.caption).foregroundColor(.gray)
            HStack(spacing: 0) {
                Text(value).font(.system(size: 20, weight: .bold)).monospacedDigit()
                Text(unit).font(.caption).foregroundColor(.gray).padding(.leading, 2)
            }
            .foregroundColor(.white)
            HStack(spacing: 16) {
                Button(action: { UIImpactFeedbackGenerator(style: .light).impactOccurred(); withAnimation { onMinus() } }) { Image(systemName: "minus.circle.fill").foregroundColor(.white.opacity(0.3)) }
                Button(action: { UIImpactFeedbackGenerator(style: .light).impactOccurred(); withAnimation { onPlus() } }) { Image(systemName: "plus.circle.fill").foregroundColor(.white.opacity(0.3)) }
            }
            .font(.title3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
}

// MARK: - Фон
struct BreathingBackground: View {
    @State private var phase = false
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.07).edgesIgnoringSafeArea(.all)
            Circle().fill(Color.red.opacity(0.08)).frame(width: 350, height: 350).blur(radius: 120)
                .offset(x: phase ? 40 : -40, y: phase ? -30 : 30)
                .scaleEffect(phase ? 1.2 : 0.8)
                .animation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true), value: phase)
                .onAppear { phase = true }
        }
    }
}
