internal import SwiftUI
import SwiftData

// MARK: - БЕЗОПАСНЫЕ ОБЕРТКИ И МОДЕЛИ ДАННЫХ (Исправлены конфликты имен)
struct CoachSheetItem: Identifiable {
    let id: String
}

enum CoachMuscleGroup: String, CaseIterable, Identifiable {
    case chest = "Грудь", back = "Спина", legs = "Ноги", shoulders = "Плечи", arms = "Руки", abs = "Пресс"
    var id: String { self.rawValue }
}

struct ProWorkout: Identifiable {
    let id = UUID()
    let name: String; let sets: String; let type: String
    let rpe: String; let tempo: String; let technique: String; let tips: String
}

struct MuscleStats: Identifiable {
    let id = UUID()
    let name: String
    let currentShare: Double; let pastShare: Double
    let color: Color
}

// MARK: - ГЛАВНЫЙ ЭКРАН AI COACH
struct AICoachView: View {
    @Environment(DIContainer.self) private var di
    @Environment(AICoachViewModel.self) private var viewModel
    @State private var showChatView = false
    @State private var showWorkoutSheet = false
    @State private var showProgressSheet = false
    @State private var showRestSheet = false
    
    @State private var isBreathing = false
    @State private var isLevitating = false
    @State private var isListening = false
    @State private var userQuery: String = ""
    
    @State private var showSyncToast = false
    @State private var readinessValue: CGFloat = 0.0
    @State private var sphereDragOffset: CGSize = .zero
    @State private var shimmerOffset: CGFloat = -1.0
    
    @AppStorage("cnsScore") private var cnsScore: Double = 85.0
    @AppStorage(Constants.UserDefaultsKeys.userName.rawValue) private var userName = "Атлет"
    
    let quickPrompts = ["Как пробить плато?", "Биомеханика жима", "Восстановление ЦНС", "Сплит на массу"]
    
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour { case 6..<12: return "Доброе утро,"; case 12..<18: return "Добрый день,"; case 18..<24: return "Фокус на вечер,"; default: return "Время восстановления," }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                HistoryBreathingBackground(cnsScore: cnsScore)
                DotGridBackground()
                FloatingParticles()
                
                VStack {
                    if showSyncToast {
                        HStack(spacing: 12) {
                            Image(systemName: "waveform.path.ecg").foregroundColor(.cyan).symbolEffect(.pulse, options: .repeating)
                            Text("Биометрия синхронизирована").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(.white)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(.ultraThinMaterial).clipShape(Capsule())
                        .overlay(Capsule().stroke(LinearGradient(colors: [.cyan.opacity(0.5), .purple.opacity(0.2)], startPoint: .leading, endPoint: .trailing), lineWidth: 1))
                        .shadow(color: .cyan.opacity(0.3), radius: 15, y: 5)
                        .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale))
                        .zIndex(2)
                    }
                    Spacer()
                }
                .padding(.top, 10)
                
                VStack {
                    // Хедер
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(greeting).font(.system(size: 14, weight: .medium, design: .rounded)).foregroundColor(.gray)
                            Text(userName.isEmpty ? "Атлет" : userName)
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundColor(.gray.opacity(0.5))
                                .overlay(
                                    LinearGradient(colors: [.clear, .white, .clear], startPoint: .leading, endPoint: .trailing)
                                        .offset(x: shimmerOffset * 150)
                                        .mask(Text(userName.isEmpty ? "Атлет" : userName).font(.system(size: 32, weight: .black, design: .rounded)))
                                )
                        }
                        Spacer()
                        
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill").foregroundColor(.orange).symbolEffect(.bounce, options: .repeating)
                            Text("12").font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit()).foregroundColor(.white)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color.orange.opacity(0.15).blur(radius: 5)).background(.ultraThinMaterial)
                        .clipShape(Capsule()).overlay(Capsule().stroke(Color.orange.opacity(0.4), lineWidth: 1))
                        
                        ZStack {
                            Circle().fill(LinearGradient(colors: [.purple, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 48, height: 48)
                            Image(systemName: "brain.head.profile").font(.system(size: 20)).foregroundColor(.white)
                        }
                        .shadow(color: .purple.opacity(0.4), radius: 10, y: 5)
                        .padding(.leading, 8)
                    }
                    .padding(.horizontal, 24).padding(.top, 20)
                    
                    // ПРО-ВИДЖЕТ ГОТОВНОСТИ
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle().stroke(Color.gray.opacity(0.2), lineWidth: 5).frame(width: 46, height: 46)
                                Circle().trim(from: 0, to: readinessValue)
                                    .stroke(AngularGradient(colors: [.cyan, .purple, .cyan], center: .center), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                    .frame(width: 46, height: 46).rotationEffect(.degrees(-90))
                                    .shadow(color: .cyan.opacity(0.5), radius: 5)
                                Text("\(Int(readinessValue * 100))").font(.system(size: 14, weight: .black).monospacedDigit()).foregroundColor(.white).contentTransition(.numericText())
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("ИНДЕКС ЦНС").font(.system(size: 11, weight: .black)).foregroundColor(.gray)
                                    Circle().fill(cnsScore > 50 ? .green : .red).frame(width: 6, height: 6).modifier(PulseEffect())
                                }
                                Text(cnsScore > 50 ? "Оптимально для гипертрофии" : "Требуется восстановление").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                            }
                            Spacer()
                        }
                        Divider().background(Color.white.opacity(0.1))
                        HStack {
                            MicroMetric(title: "HRV", value: "68", unit: "ms", color: .cyan)
                            Spacer()
                            MicroMetric(title: "RHR", value: "52", unit: "bpm", color: .purple)
                            Spacer()
                            MicroMetric(title: "Сон", value: "-1.2", unit: "ч", color: .orange)
                        }
                    }
                    .glassCard()
                    .padding(.horizontal, 24).padding(.top, 10)
                    
                    Spacer()
                    
                    // ИИ СФЕРА И ПОИСК
                    let spherePrimary: Color = isListening ? .green : (cnsScore > 50 ? .purple : .orange)
                    let sphereSecondary: Color = isListening ? .cyan : (cnsScore > 50 ? .blue : .red)
                    
                    VStack(spacing: 16) {
                        Button(action: {
                            HapticManager.shared.impact(.rigid)
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) { isListening.toggle() }
                            showChatView = true
                        }) {
                            ZStack {
                                Circle().fill(spherePrimary.opacity(0.3))
                                    .frame(width: 160, height: 160).blur(radius: isBreathing ? 30 : 15)
                                    .scaleEffect(isBreathing ? 1.2 : 0.8)
                                Circle().fill(LinearGradient(colors: [spherePrimary, sphereSecondary], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 120, height: 120).scaleEffect(isBreathing ? (isListening ? 1.1 : 1.05) : 0.95)
                                Circle().fill(.ultraThinMaterial).frame(width: 100, height: 100).overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                                Image(systemName: isListening ? "waveform.and.mic" : "aqi.high").font(.system(size: 44, weight: .light)).foregroundColor(isListening ? .green : .white).symbolEffect(.bounce, value: isListening)
                            }
                            .shadow(color: spherePrimary.opacity(0.5), radius: isBreathing ? 35 : 15)
                        }
                        .buttonStyle(.plain)
                        .offset(x: sphereDragOffset.width, y: isLevitating ? sphereDragOffset.height - 8 : sphereDragOffset.height + 8)
                        .rotation3DEffect(.degrees(Double(sphereDragOffset.width / 4)), axis: (x: 0, y: 1, z: 0))
                        .rotation3DEffect(.degrees(Double(-sphereDragOffset.height / 4)), axis: (x: 1, y: 0, z: 0))
                        .hueRotation(.degrees(isBreathing ? 15 : -15))
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    withAnimation(.interactiveSpring()) { sphereDragOffset = value.translation }
                                    if abs(value.translation.width) > 50 || abs(value.translation.height) > 50 { HapticManager.shared.selection() }
                                }
                                .onEnded { _ in withAnimation(.spring(response: 0.6, dampingFraction: 0.4)) { sphereDragOffset = .zero; HapticManager.shared.impact(.soft) } }
                        )
                        
                        VStack(spacing: 4) {
                            Text(isListening ? "Анализирую биометрию..." : "Нейро-тренер активен").font(.system(size: 26, weight: .black, design: .rounded)).foregroundColor(.white).contentTransition(.numericText())
                            Text(isListening ? "Слушаю ваши показатели и цели" : "Спроси меня о чем угодно").font(.system(size: 15, weight: .medium)).foregroundColor(.gray).multilineTextAlignment(.center)
                        }
                        
                        HStack {
                            Image(systemName: "sparkle.magnifyingglass").foregroundColor(.cyan)
                            TextField("План питания, техника...", text: $userQuery).foregroundColor(.white)
                                .submitLabel(.send)
                                .onSubmit {
                                    // 👇 ОТКРЫВАЕМ ЧАТ ПРИ НАЖАТИИ ENTER
                                    if !userQuery.isEmpty {
                                        viewModel.inputText = userQuery
                                        userQuery = "" // Очищаем локальный
                                        showChatView = true
                                    }
                                }
                            if !userQuery.isEmpty {
                                Button(action: { userQuery = "" }) {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(16).background(.ultraThinMaterial).cornerRadius(20).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1)).padding(.horizontal, 24)

                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 12) {
                                Spacer().frame(width: 12)
                                ForEach(quickPrompts, id: \.self) { prompt in
                                    Button(action: {
                                        HapticManager.shared.selection()
                                        // 👇 ПЕРЕДАЕМ ПРОМПТ В ВЬЮМОДЕЛЬ И ОТКРЫВАЕМ ЧАТ
                                        viewModel.inputText = prompt
                                        showChatView = true
                                    }) {
                                        Text(prompt).font(.system(size: 13, weight: .bold)).padding(.horizontal, 16).padding(.vertical, 10).background(Color.white.opacity(0.05)).foregroundColor(.white).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                                    }
                                }
                                Spacer().frame(width: 12)
                            }
                        }.scrollBounceBehavior(.basedOnSize)
                    }
                    .padding(.bottom, 12)
                    
                    Spacer()
                    
                    // DOCK
                    HStack(spacing: 12) {
                        AICoachIsland(title: "План", icon: "bolt.heart.fill", color: .purple) { showWorkoutSheet = true }
                        AICoachIsland(title: "Прогресс", icon: "chart.xyaxis.line", color: .cyan) { showProgressSheet = true }
                        AICoachIsland(title: "ЦНС", icon: "moon.stars.fill", color: .orange) { showRestSheet = true }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(.ultraThinMaterial).clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    .shadow(color: .black.opacity(0.4), radius: 25, x: 0, y: 15)
                    .padding(.horizontal, 24).padding(.bottom, 24)
                }
            }
            .navigationBarHidden(true)
            .dynamicTypeSize(.medium ... .accessibility1)
            .onAppear {
                Task {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) { showSyncToast = true }
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    withAnimation(.easeOut) { showSyncToast = false }
                }
                withAnimation(.easeOut(duration: 2.5).delay(0.5)) { readinessValue = cnsScore / 100 }
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { isBreathing = true }
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) { isLevitating = true }
                withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) { shimmerOffset = 2.0 }
            }
            .sheet(isPresented: $showRestSheet) { RestAnalysisSheet().presentationDetents([.large]).presentationCornerRadius(35).presentationDragIndicator(.visible) }
            .sheet(isPresented: $showProgressSheet) { ProgressAnalysisSheet().presentationDetents([.large]).presentationCornerRadius(35).presentationDragIndicator(.visible) }
            .sheet(isPresented: $showWorkoutSheet) { WorkoutConfigSheet().presentationDetents([.large]).presentationCornerRadius(35).presentationDragIndicator(.visible) }
            .fullScreenCover(isPresented: $showChatView) {
                        AIChatBotView(viewModel: viewModel)
                    }
        }
    }
}

// MARK: - ЭКРАН PROGRESS
struct ProgressAnalysisSheet: View {
    let periods = ["Последние 7 дней", "Мезоцикл (4 нед.)"]
    let focuses = ["Дисбаланс мышц", "Лидеры роста"]
    
    @State private var selectedPeriod = "Мезоцикл (4 нед.)"
    @State private var selectedFocus = "Дисбаланс мышц"
    @State private var appearAnimate = false
    @State private var impulseValue: Int = 0
    @State private var selectedMuscleTip: CoachSheetItem? = nil // Исправлено
    @State private var activeSegment: UUID? = nil
    
    let stats = [
        MuscleStats(name: "Грудь", currentShare: 30, pastShare: 24, color: .purple),
        MuscleStats(name: "Спина", currentShare: 20, pastShare: 28, color: .cyan),
        MuscleStats(name: "Ноги", currentShare: 32, pastShare: 30, color: .green),
        MuscleStats(name: "Руки", currentShare: 18, pastShare: 18, color: .orange)
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 30) {
                        Spacer().frame(height: 70)
                        
                        // ИИ-ПРЕДИКТОР
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "cpu").foregroundColor(.purple)
                                Text("ИИ-ПРЕДИКТОР").font(.system(size: 12, weight: .black)).foregroundColor(.gray)
                            }
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Импульс роста").font(.system(size: 14, weight: .medium)).foregroundColor(.gray)
                                    HStack(alignment: .firstTextBaseline) {
                                        Text("+\(impulseValue)%").font(.system(size: 38, weight: .black, design: .rounded).monospacedDigit()).foregroundColor(.cyan).contentTransition(.numericText())
                                        Text("к массе").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                                    }
                                }
                                Spacer()
                                ZStack {
                                    Circle().stroke(Color.cyan.opacity(0.3), lineWidth: 2).frame(width: 60, height: 60)
                                    Circle().fill(Color.cyan.opacity(0.1)).frame(width: 60, height: 60)
                                    Image(systemName: "arrow.up.forward").font(.title2).foregroundColor(.cyan).offset(x: appearAnimate ? 5 : -5, y: appearAnimate ? -5 : 5)
                                }.modifier(PulseEffect())
                            }
                            Text("При текущем RPE и объеме, ожидается прорыв в силовых на жиме лежа через 14 дней.").font(.system(size: 14)).foregroundColor(.gray)
                        }
                        .glassCard(strokeColors: [.purple.opacity(0.4), .cyan.opacity(0.2)])
                        .padding(.horizontal, 24)
                        
                        // ПАРАМЕТРЫ АНАЛИЗА
                        VStack(alignment: .leading, spacing: 16) {
                            Text("ДЕТАЛЬНАЯ АНАЛИТИКА").font(.system(size: 12, weight: .black)).foregroundColor(.gray).padding(.horizontal, 24)
                            VStack(spacing: 2) {
                                Menu { ForEach(periods, id: \.self) { p in Button(p) { withAnimation(.spring()) { selectedPeriod = p } } } } label: { HStack { Text("Период").foregroundColor(.gray); Spacer(); Text(selectedPeriod).fontWeight(.bold).foregroundColor(.white); Image(systemName: "chevron.up.chevron.down").foregroundColor(.cyan).font(.caption) }.padding().background(Color(UIColor.secondarySystemGroupedBackground)) }
                                Divider().background(Color.white.opacity(0.1)).padding(.horizontal)
                                Menu { ForEach(focuses, id: \.self) { f in Button(f) { withAnimation(.spring()) { selectedFocus = f } } } } label: { HStack { Text("Акцент").foregroundColor(.gray); Spacer(); Text(selectedFocus).fontWeight(.bold).foregroundColor(.white); Image(systemName: "chevron.up.chevron.down").foregroundColor(.purple).font(.caption) }.padding().background(Color(UIColor.secondarySystemGroupedBackground)) }
                            }.cornerRadius(20).padding(.horizontal, 24)
                        }
                        
                        // ГРАФИКИ
                        VStack(alignment: .center, spacing: 24) {
                            ZStack {
                                CustomDonutChart(data: stats.map { ($0.pastShare, $0.color.opacity(0.3), $0.id) }, thickness: 10, activeId: $activeSegment)
                                    .frame(width: 150, height: 150)
                                CustomDonutChart(data: stats.map { ($0.currentShare, $0.color, $0.id) }, thickness: 18, activeId: $activeSegment)
                                    .frame(width: 210, height: 210)
                                    .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 5)
                                VStack { Image(systemName: "figure.strengthtraining.traditional").font(.system(size: 34)).foregroundColor(.white) }
                            }
                            .scaleEffect(appearAnimate ? 1 : 0.8).opacity(appearAnimate ? 1 : 0)
                            .padding(.vertical, 10)
                            
                            VStack(spacing: 16) {
                                ForEach(stats) { stat in
                                    StatRowView(stat: stat, appearAnimate: appearAnimate, isSelected: activeSegment == stat.id)
                                        .onTapGesture { withAnimation(.spring()) { activeSegment = (activeSegment == stat.id) ? nil : stat.id } }
                                }
                            }
                        }.frame(maxWidth: .infinity)
                        
                        // РЕШЕНИЕ ИИ
                        VStack(alignment: .leading, spacing: 12) {
                            Text("ИИ ВЫВОД").font(.system(size: 12, weight: .black)).foregroundColor(.purple).padding(.horizontal, 24)
                            Button(action: {
                                let target = selectedFocus == "Дисбаланс мышц" ? stats.min(by: { ($0.currentShare - $0.pastShare) < ($1.currentShare - $1.pastShare) }) : stats.max(by: { ($0.currentShare - $0.pastShare) < ($1.currentShare - $1.pastShare) })
                                if let targetName = target?.name { selectedMuscleTip = CoachSheetItem(id: targetName) } // Исправлено
                                HapticManager.shared.impact(.heavy)
                            }) {
                                HStack(alignment: .top) {
                                    Image(systemName: "sparkles.tv").font(.title).foregroundStyle(LinearGradient(colors: [.purple, .cyan], startPoint: .top, endPoint: .bottom))
                                    VStack(alignment: .leading, spacing: 6) {
                                        let target = selectedFocus == "Дисбаланс мышц" ? stats.min(by: { ($0.currentShare - $0.pastShare) < ($1.currentShare - $1.pastShare) })! : stats.max(by: { ($0.currentShare - $0.pastShare) < ($1.currentShare - $1.pastShare) })!
                                        Text(selectedFocus == "Дисбаланс мышц" ? "Отстает: \(target.name)" : "Доминант: \(target.name)").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                                        Text("Нейросеть сформировала корректирующий протокол. Нажми, чтобы применить.").font(.system(size: 13)).foregroundColor(.gray).multilineTextAlignment(.leading)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundColor(.gray).padding(.top, 10)
                                }
                                .padding(20).background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(24)
                                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.purple.opacity(0.2), lineWidth: 1))
                            }
                            .buttonStyle(ParallaxButtonStyle())
                            .padding(.horizontal, 24)
                        }
                        
                    }.padding(.bottom, 40)
                }
                
                VStack {
                    HStack { Text("Прогресс").font(.system(size: 32, weight: .black, design: .rounded)); Spacer() }.padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 10)
                }.background(.regularMaterial)
            }
            .navigationBarHidden(true)
            .onAppear {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) { appearAnimate = true }
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    withAnimation(.easeOut(duration: 2.0)) { impulseValue = 12 }
                }
            }
            .sheet(item: $selectedMuscleTip) { wrapped in BestExercisesSheet(muscle: wrapped.id).presentationDetents([.fraction(0.85)]).presentationCornerRadius(35).presentationDragIndicator(.visible) } // Исправлено
        }
    }
}

struct StatRowView: View {
    let stat: MuscleStats; let appearAnimate: Bool; let isSelected: Bool
    var body: some View {
        let diff = stat.currentShare - stat.pastShare
        let diffStr = diff > 0 ? "+\(String(format: "%.1f", diff))%" : "\(String(format: "%.1f", diff))%"
        
        VStack(spacing: 6) {
            HStack {
                Circle().fill(stat.color).frame(width: 8, height: 8).scaleEffect(isSelected ? 1.5 : 1.0)
                Text(stat.name).font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                Spacer()
                Text(diffStr).font(.system(size: 13, weight: .bold).monospacedDigit()).foregroundColor(diff > 0 ? .green : (diff < 0 ? .red : .gray))
                Text("\(String(format: "%.1f", stat.currentShare))%").font(.system(size: 16, weight: .black).monospacedDigit()).foregroundColor(.white).frame(width: 55, alignment: .trailing)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.05)).frame(height: 6)
                    Capsule()
                        .fill(LinearGradient(colors: [stat.color.opacity(0.5), stat.color], startPoint: .leading, endPoint: .trailing))
                        .frame(width: appearAnimate ? geo.size.width * (stat.currentShare / 40.0) : 0, height: 6)
                        .shadow(color: stat.color.opacity(isSelected ? 0.6 : 0), radius: 5)
                }
            }.frame(height: 6)
        }.padding(.horizontal, 30)
    }
}

// MARK: - ЭКРАН WORKOUT CONFIG
struct WorkoutConfigSheet: View {
    let levels = ["Базовый", "Продвинутый", "Атлет PRO"]
    @State private var selectedLevel = "Продвинутый"
    @State private var selectedMuscle: CoachMuscleGroup? = nil // Исправлено
    @State private var showExercises = false
    
    func synergyFor(_ muscle: CoachMuscleGroup) -> String? { // Исправлено
        switch muscle { case .chest: return "Трицепс, Передняя дельта"; case .back: return "Бицепс, Трапеция"; case .legs: return "Ягодицы, Икры"; default: return nil }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 32) {
                        Spacer().frame(height: 70)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            Text("ИНТЕНСИВНОСТЬ").font(.system(size: 12, weight: .black)).foregroundColor(.gray).padding(.horizontal, 24)
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 12) {
                                    Spacer().frame(width: 12)
                                    ForEach(levels, id: \.self) { level in
                                        Button(action: { HapticManager.shared.impact(.light); selectedLevel = level }) {
                                            Text(level).font(.system(size: 15, weight: .bold)).padding(.horizontal, 20).padding(.vertical, 12).background(selectedLevel == level ? Color.white : Color(UIColor.secondarySystemGroupedBackground)).foregroundColor(selectedLevel == level ? .black : .white).cornerRadius(16)
                                        }
                                    }
                                    Spacer().frame(width: 12)
                                }
                            }.scrollBounceBehavior(.basedOnSize)
                        }
                        
                        VStack(alignment: .leading, spacing: 16) {
                            Text("ГЛАВНЫЙ ФОКУС").font(.system(size: 12, weight: .black)).foregroundColor(.gray).padding(.horizontal, 24)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                ForEach(CoachMuscleGroup.allCases) { muscle in // Исправлено
                                    Button(action: {
                                        HapticManager.shared.impact(.medium); selectedMuscle = muscle;
                                        Task { try? await Task.sleep(nanoseconds: 100_000_000); showExercises = true }
                                    }) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack { Text(muscle.rawValue).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(.white); Spacer(); Image(systemName: "chevron.right.circle.fill").foregroundColor(.purple.opacity(0.8)) }
                                            if let syn = synergyFor(muscle) { HStack(spacing: 4) { Image(systemName: "link").font(.system(size: 10)); Text(syn).font(.system(size: 11, weight: .medium)) }.foregroundColor(.cyan).lineLimit(1) } else { Text("Изоляция").font(.system(size: 11, weight: .medium)).foregroundColor(.gray) }
                                        }.padding(16).background(.ultraThinMaterial).cornerRadius(20).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.05), lineWidth: 1))
                                    }.buttonStyle(ParallaxButtonStyle())
                                }
                            }.padding(.horizontal, 24)
                        }
                    }.padding(.bottom, 40)
                }
                
                VStack { HStack { Text("Конструктор").font(.system(size: 32, weight: .black, design: .rounded)); Spacer() }.padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 10) }.background(.regularMaterial)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showExercises) { if let m = selectedMuscle { BestExercisesSheet(muscle: m.rawValue).presentationDetents([.fraction(0.85)]).presentationCornerRadius(35).presentationDragIndicator(.visible) } }
        }
    }
}

// MARK: - ЭКРАН ТОП-УПРАЖНЕНИЙ
struct BestExercisesSheet: View {
    let muscle: String
    @State private var isGenerating = true
    @State private var animatedTonnage: Int = 0
    @State private var selectedExercise: ProWorkout? = nil
    @State private var isSaved = false
    
    var data: [ProWorkout] {
        switch muscle {
        case "Грудь": return [
            ProWorkout(name: "Жим штанги лежа", sets: "4х8", type: "Механическое напряжение", rpe: "RPE 8.5", tempo: "3-1-1-0", technique: "1. Сведи лопатки и опусти их вниз.\n2. Жестко упрись ногами в пол.", tips: "Не отрывай таз от скамьи."),
            ProWorkout(name: "Жим гантелей", sets: "3х10", type: "Верхний пучок", rpe: "RPE 8", tempo: "2-0-2-1", technique: "1. Угол скамьи 30-45 градусов.\n2. Выжимай по дуге вверх.", tips: "Не бей гантели друг о друга.")
        ]
        default: return [
            ProWorkout(name: "Тяжелая База", sets: "4х8", type: "Основа", rpe: "RPE 8.5", tempo: "3-1-1-0", technique: "1. Займи устойчивую позицию.", tips: "Следи за дыханием."),
            ProWorkout(name: "Изоляция", sets: "3х12", type: "Проработка", rpe: "RPE 8", tempo: "2-0-2-1", technique: "1. Зафиксируй суставы.", tips: "Фокус на нейромышечной связи.")
        ]
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isGenerating ? "Нейросеть считает..." : "Протокол: \(muscle)").font(.system(size: 24, weight: .black, design: .rounded)).foregroundColor(.white)
                Spacer()
                if !isGenerating { Image(systemName: "checkmark.seal.fill").foregroundColor(.cyan).font(.title2).symbolEffect(.bounce) }
            }.padding(.horizontal, 24).padding(.top, 30).padding(.bottom, 10)
            
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Эстимейт Объем").font(.system(size: 12, weight: .bold)).foregroundColor(.gray)
                            Text("\(animatedTonnage) кг").font(.system(size: 20, weight: .black).monospacedDigit()).foregroundColor(.purple).contentTransition(.numericText())
                        }
                        Spacer()
                        Divider().background(Color.white.opacity(0.2)).frame(height: 30)
                        Spacer()
                        VStack(alignment: .trailing) { Text("Время").font(.system(size: 12, weight: .bold)).foregroundColor(.gray); Text("45 мин").font(.system(size: 20, weight: .black)).foregroundColor(.cyan) }
                    }
                    .padding(20).background(Color.white.opacity(0.05)).cornerRadius(20).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .redacted(reason: isGenerating ? .placeholder : [])
                    .modifier(PulseEffect())
                    
                    ForEach(Array(data.enumerated()), id: \.offset) { index, rec in
                        ExerciseRowView(index: index, rec: rec) {
                            HapticManager.shared.impact(.medium)
                            selectedExercise = rec
                        }
                        .redacted(reason: isGenerating ? .placeholder : [])
                        .scrollTransition { content, phase in
                            content.opacity(phase.isIdentity ? 1 : 0.5).scaleEffect(phase.isIdentity ? 1 : 0.95)
                        }
                    }
                    
                    if !isGenerating {
                        Button(action: {
                            HapticManager.shared.impact(.heavy)
                            withAnimation { isSaved = true }
                            Task { try? await Task.sleep(nanoseconds: 2_000_000_000); withAnimation { isSaved = false } }
                        }) {
                            HStack {
                                if isSaved { Image(systemName: "checkmark").bold() }
                                Text(isSaved ? "Сохранено" : "Сохранить в Apple Health").font(.system(size: 16, weight: .bold))
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(LinearGradient(colors: isSaved ? [.green, .mint] : [.purple, .blue], startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(.white).cornerRadius(20)
                            .shadow(color: isSaved ? .green.opacity(0.5) : .purple.opacity(0.4), radius: 15, y: 5)
                        }.padding(.top, 10).buttonStyle(ParallaxButtonStyle())
                    }
                    
                }.padding(.horizontal, 24).padding(.bottom, 30)
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            Task {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                withAnimation(.easeOut) { isGenerating = false }
                withAnimation(.easeOut(duration: 1.5)) { animatedTonnage = 14500 }
            }
        }
        .sheet(item: $selectedExercise) { exercise in
            ExerciseTechniqueSheet(exercise: exercise).presentationDetents([.medium]).presentationCornerRadius(35).presentationDragIndicator(.visible)
        }
    }
}

struct ExerciseRowView: View {
    let index: Int; let rec: ProWorkout; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                HStack(alignment: .top) {
                    Text(String(format: "%02d", index + 1)).font(.system(size: 24, weight: .black, design: .rounded).monospacedDigit()).foregroundColor(.white.opacity(0.2))
                    VStack(alignment: .leading, spacing: 4) { Text(rec.name).font(.system(size: 18, weight: .bold)).foregroundColor(.white); Text(rec.type).font(.system(size: 13)).foregroundColor(.gray) }.padding(.leading, 8)
                    Spacer()
                    Image(systemName: "chevron.right.circle.fill").font(.title2).foregroundColor(.purple.opacity(0.8))
                }
                Divider().background(Color.white.opacity(0.1))
                HStack {
                    HStack(spacing: 6) { Image(systemName: "flame").foregroundColor(.orange); Text(rec.rpe).font(.system(size: 12, weight: .bold)).foregroundColor(.white) }
                    Spacer()
                    HStack(spacing: 6) { Image(systemName: "arrow.2.squarepath").foregroundColor(.purple); Text(rec.sets).font(.system(size: 12, weight: .bold)).foregroundColor(.white) }
                    Spacer()
                    HStack(spacing: 6) { Image(systemName: "metronome").foregroundColor(.cyan); Text(rec.tempo).font(.system(size: 12, weight: .bold)).foregroundColor(.white) }
                }.padding(.top, 4)
            }
            .padding(20).background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(24).overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.05), lineWidth: 1))
        }
        .buttonStyle(ParallaxButtonStyle())
    }
}

// MARK: - ЭКРАН ТЕХНИКИ ВЫПОЛНЕНИЯ
struct ExerciseTechniqueSheet: View {
    let exercise: ProWorkout
    var body: some View {
        ZStack(alignment: .top) {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(exercise.name).font(.system(size: 26, weight: .black, design: .rounded)).foregroundColor(.white)
                        HStack(spacing: 12) {
                            BadgeView(text: exercise.type, color: .purple)
                            BadgeView(text: exercise.rpe, color: .orange)
                        }
                    }.padding(.horizontal, 24).padding(.top, 30)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        HStack { Image(systemName: "figure.strengthtraining.traditional").foregroundColor(.cyan); Text("ПРАВИЛЬНАЯ ТЕХНИКА").font(.system(size: 12, weight: .black)).foregroundColor(.gray) }
                        Text(exercise.technique).font(.system(size: 15, weight: .medium)).foregroundColor(.white).lineSpacing(6)
                    }
                    .padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(24).padding(.horizontal, 24)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        HStack { Image(systemName: "sparkles").foregroundColor(.orange); Text("ИИ ПРО-СОВЕТ").font(.system(size: 12, weight: .black)).foregroundColor(.orange) }
                        Text(exercise.tips).font(.system(size: 15, weight: .medium)).foregroundColor(.white).lineSpacing(4)
                    }
                    .padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Color.orange.opacity(0.1)).overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.orange.opacity(0.3), lineWidth: 1)).cornerRadius(24).padding(.horizontal, 24)
                    
                }.padding(.bottom, 40)
            }
        }
    }
}

struct BadgeView: View {
    let text: String; let color: Color
    var body: some View { Text(text).font(.system(size: 12, weight: .bold)).foregroundColor(color).padding(.horizontal, 10).padding(.vertical, 6).background(color.opacity(0.15)).cornerRadius(8) }
}

// MARK: - ЭКРАН REST
struct RestAnalysisSheet: View {
    @AppStorage("sleepHours") private var sleepHours: Double = 7.5
    @AppStorage("waterCups") private var waterCups: Int = 4
    @AppStorage("cnsScore") private var cnsScore: Double = 85.0
    
    var cnsLoad: Double {
        let sleepFactor = max(0, (8.0 - sleepHours) * 10)
        let waterFactor = max(0, (8 - waterCups) * 2)
        return min(100, 20 + sleepFactor + Double(waterFactor))
    }
    var cnsColor: Color { switch cnsLoad { case 0..<40: return .green; case 40..<75: return .orange; default: return .red } }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 32) {
                        Spacer().frame(height: 70)
                        
                        VStack(spacing: 16) {
                            Text("ИСТОЩЕНИЕ ЦНС").font(.system(size: 12, weight: .black)).foregroundColor(.gray)
                            ZStack {
                                Circle().stroke(Color.white.opacity(0.1), lineWidth: 15).frame(width: 150, height: 150)
                                Circle().trim(from: 0, to: cnsLoad / 100).stroke(cnsColor, style: StrokeStyle(lineWidth: 15, lineCap: .round)).frame(width: 150, height: 150).rotationEffect(.degrees(-90)).animation(.spring(response: 0.6, dampingFraction: 0.7), value: cnsLoad)
                                VStack { Text("\(Int(cnsLoad))%").font(.system(size: 36, weight: .black, design: .rounded).monospacedDigit()).foregroundColor(.white).contentTransition(.numericText()); Text(cnsLoad < 40 ? "Свежий" : (cnsLoad < 75 ? "Усталость" : "Перетрен")).font(.system(size: 14, weight: .bold)).foregroundColor(cnsColor) }
                            }
                        }.frame(maxWidth: .infinity).padding(.bottom, 10)
                        
                        VStack(alignment: .leading, spacing: 20) {
                            Text("БИОМЕТРИЯ").font(.system(size: 12, weight: .black)).foregroundColor(.gray).padding(.horizontal, 24)
                            VStack(spacing: 12) {
                                HStack { Image(systemName: "moon.zzz.fill").foregroundColor(.purple); Text("Сон прошлой ночью").font(.system(size: 16, weight: .medium)).foregroundColor(.white); Spacer(); Text(String(format: "%.1f ч", sleepHours)).font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit()).foregroundColor(.purple) }
                                Slider(value: $sleepHours, in: 3...12, step: 0.5) { _ in HapticManager.shared.selection(); updateCNS() }.tint(.purple)
                            }.padding(20).background(.ultraThinMaterial).cornerRadius(24).padding(.horizontal, 24)
                            
                            VStack(spacing: 12) {
                                HStack { Image(systemName: "drop.fill", variableValue: Double(waterCups)/10.0).foregroundColor(.cyan); Text("Гидратация (стаканы)").font(.system(size: 16, weight: .medium)).foregroundColor(.white); Spacer(); Text("\(waterCups)").font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit()).foregroundColor(.cyan) }
                                Slider(value: Binding(get: { Double(waterCups) }, set: { waterCups = Int($0) }), in: 0...15, step: 1) { _ in HapticManager.shared.selection(); updateCNS() }.tint(.cyan)
                            }.padding(20).background(.ultraThinMaterial).cornerRadius(24).padding(.horizontal, 24)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("ПРОТОКОЛ ВОССТАНОВЛЕНИЯ").font(.system(size: 12, weight: .black)).foregroundColor(.gray).padding(.horizontal, 24)
                            HStack(spacing: 12) {
                                if cnsLoad < 40 {
                                    RecoveryBadge(icon: "flame.fill", text: "Плотный прием углеводов", color: .orange)
                                    RecoveryBadge(icon: "figure.walk", text: "Легкая активность", color: .green)
                                } else if cnsLoad < 75 {
                                    RecoveryBadge(icon: "snowflake", text: "Холодный душ", color: .cyan)
                                    RecoveryBadge(icon: "bed.double.fill", text: "Дневной сон (20м)", color: .purple)
                                } else {
                                    RecoveryBadge(icon: "thermometer.sun.fill", text: "Сауна", color: .red)
                                    RecoveryBadge(icon: "figure.mind.and.body", text: "МФР / Раскатка", color: .blue)
                                }
                            }.padding(.horizontal, 24)
                        }
                        
                    }.padding(.bottom, 40)
                }
                
                VStack { HStack { Text("Восстановление").font(.system(size: 32, weight: .black, design: .rounded)); Spacer() }.padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 10) }.background(.regularMaterial)
            }.navigationBarHidden(true)
        }
    }
    private func updateCNS() { cnsScore = 100 - cnsLoad }
}

struct MicroMetric: View {
    var title: String; var value: String; var unit: String; var color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
            HStack(alignment: .firstTextBaseline, spacing: 2) { Text(value).font(.system(size: 18, weight: .black, design: .rounded).monospacedDigit()).foregroundColor(color); Text(unit).font(.system(size: 10, weight: .medium)).foregroundColor(.gray) }
        }
    }
}

struct RecoveryBadge: View {
    var icon: String; var text: String; var color: Color
    var body: some View {
        HStack(spacing: 8) { Image(systemName: icon).foregroundColor(color); Text(text).font(.system(size: 13, weight: .bold)).foregroundColor(.white) }
        .padding(.horizontal, 16).padding(.vertical, 12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.2), lineWidth: 1))
    }
}

struct AICoachIsland: View {
    var title: String; var icon: String; var color: Color; var action: () -> Void
    var body: some View {
        Button(action: { HapticManager.shared.impact(.medium); action() }) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 22, weight: .medium)).foregroundStyle(LinearGradient(colors: [.white, color], startPoint: .topLeading, endPoint: .bottomTrailing))
                Text(title).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.white)
            }
            .contentShape(Rectangle())
            .frame(maxWidth: .infinity).padding(.vertical, 12).background(color.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 20))
        }.buttonStyle(ScaleButtonStyle())
    }
}
