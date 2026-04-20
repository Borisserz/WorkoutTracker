// ============================================================
// FILE: WorkoutTracker/Features/AICoach/Views/AICoachView.swift
// ============================================================

internal import SwiftUI
import SwiftData

// MARK: - Модели данных для UI
struct CoachSheetItem: Identifiable {
    let id: String
}

enum CoachMuscleGroup: String, CaseIterable, Identifiable {
    case chest = "Грудь", back = "Спина", legs = "Ноги", shoulders = "Плечи", arms = "Руки", abs = "Пресс"
    var id: String { self.rawValue }
    
    // Маппинг для движка генерации
    var engineName: String {
        switch self {
        case .chest: return "Chest"
        case .back: return "Back"
        case .legs: return "Legs"
        case .shoulders: return "Shoulders"
        case .arms: return "Arms"
        case .abs: return "Core"
        }
    }
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
    @Environment(\.colorScheme) private var colorScheme // 👈 АДАПТАЦИЯ
    
    @State private var showChatView = false
    @State private var showWorkoutSheet = false
    @State private var showProgressSheet = false
    @State private var showRestSheet = false
    @State private var showAISettings = false
    
    @State private var isBreathing = false
    @State private var isLevitating = false
    @State private var userQuery: String = ""
    
    @State private var showSyncToast = false
    @State private var readinessValue: CGFloat = 0.0
    @State private var sphereDragOffset: CGSize = .zero
    @State private var shimmerOffset: CGFloat = -1.0
    
    @AppStorage("cnsScore") private var cnsScore: Double = 85.0
    @AppStorage("sleepHours") private var sleepHours: Double = 7.5
    @AppStorage(Constants.UserDefaultsKeys.userName.rawValue) private var userName = ""
    
    @StateObject private var speechRecognizer = SpeechRecognizer()
    
    let quickPrompts = ["Как пробить плато?", "Биомеханика жима", "Восстановление ЦНС", "Сплит на массу"]
    
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour { case 6..<12: return "Доброе утро,"; case 12..<18: return "Добрый день,"; case 18..<24: return "Фокус на вечер,"; default: return "Время восстановления," }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 👈 АДАПТИВНЫЙ ФОН
                if colorScheme == .dark {
                    HistoryBreathingBackground(cnsScore: cnsScore)
                    DotGridBackground()
                    FloatingParticles()
                } else {
                    Color(UIColor.secondarySystemBackground).ignoresSafeArea()
                }
                
                VStack {
                    if showSyncToast {
                        HStack(spacing: 12) {
                            Image(systemName: "waveform.path.ecg").foregroundColor(.cyan).symbolEffect(.pulse, options: .repeating)
                            Text("Биометрия синхронизирована").font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(colorScheme == .dark ? LinearGradient(colors: [.cyan.opacity(0.5), .purple.opacity(0.2)], startPoint: .leading, endPoint: .trailing) : LinearGradient(colors: [.cyan.opacity(0.3), .clear], startPoint: .leading, endPoint: .trailing), lineWidth: 1))
                        .shadow(color: .cyan.opacity(0.2), radius: 15, y: 5)
                        .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale))
                        .zIndex(2)
                    }
                    Spacer()
                }
                .padding(.top, 10)
                
                VStack {
                    // ХЕДЕР
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(greeting).font(.system(size: 14, weight: .medium, design: .rounded)).foregroundColor(.gray)
                            Text(userName.isEmpty ? "Атлет" : userName)
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundColor(colorScheme == .dark ? .white : .black) // 👈 АДАПТАЦИЯ
                                .overlay(
                                    LinearGradient(colors: [.clear, colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.5), .clear], startPoint: .leading, endPoint: .trailing)
                                        .offset(x: shimmerOffset * 150)
                                        .mask(Text(userName.isEmpty ? "Атлет" : userName).font(.system(size: 32, weight: .black, design: .rounded)))
                                )
                        }
                        Spacer()
                        
                        Button(action: {
                            HapticManager.shared.impact(.light)
                            showAISettings = true
                        }) {
                            ZStack {
                                Circle().fill(LinearGradient(colors: [.purple, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 48, height: 48)
                                Image(systemName: "brain.head.profile").font(.system(size: 20)).foregroundColor(.white)
                            }
                            .shadow(color: .purple.opacity(0.3), radius: 8, y: 4)
                            .padding(.leading, 8)
                        }
                        .buttonStyle(.plain)
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
                                    .shadow(color: .cyan.opacity(0.4), radius: 5)
                                Text("\(Int(readinessValue * 100))").font(.system(size: 14, weight: .black).monospacedDigit())
                                    .foregroundColor(colorScheme == .dark ? .white : .black) // 👈 АДАПТАЦИЯ
                                    .contentTransition(.numericText())
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("ИНДЕКС ЦНС").font(.system(size: 11, weight: .black)).foregroundColor(.gray)
                                    Circle().fill(cnsScore > 50 ? .green : .red).frame(width: 6, height: 6).modifier(PulseEffect())
                                }
                                Text(cnsScore > 50 ? "Оптимально для гипертрофии" : "Требуется восстановление")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(colorScheme == .dark ? .white : .black) // 👈 АДАПТАЦИЯ
                            }
                            Spacer()
                        }
                        Divider().background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                        HStack {
                            MicroMetric(title: "HRV", value: "68", unit: "ms", color: .cyan)
                            Spacer()
                            MicroMetric(title: "RHR", value: "52", unit: "bpm", color: .purple)
                            Spacer()
                            MicroMetric(title: "Сон", value: String(format: "%.1f", sleepHours), unit: "ч", color: .orange)
                        }
                    }
                    // 👈 АДАПТИВНАЯ КАРТОЧКА
                    .padding(16)
                    .background(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white))
                    .cornerRadius(24)
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05), lineWidth: 1))
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 10, y: 5)
                    .padding(.horizontal, 24).padding(.top, 10)
                    
                    Spacer()
                    
                    // ✅ ИИ СФЕРА И ПОИСК С ГОЛОСОВЫМ ВВОДОМ
                    let isListening = speechRecognizer.isRecording
                    let spherePrimary: Color = isListening ? .green : (cnsScore > 50 ? .purple : .orange)
                    let sphereSecondary: Color = isListening ? .cyan : (cnsScore > 50 ? .blue : .red)
                    
                    VStack(spacing: 16) {
                        Button(action: {
                            HapticManager.shared.impact(.rigid)
                            if isListening {
                                speechRecognizer.stopTranscribing()
                                if !speechRecognizer.transcript.isEmpty {
                                    viewModel.inputText = speechRecognizer.transcript
                                    showChatView = true
                                    speechRecognizer.transcript = ""
                                }
                            } else {
                                speechRecognizer.startTranscribing()
                            }
                        }) {
                            ZStack {
                                Circle().fill(spherePrimary.opacity(colorScheme == .dark ? 0.3 : 0.15))
                                    .frame(width: 160, height: 160).blur(radius: isBreathing ? 30 : 15)
                                    .scaleEffect(isBreathing ? 1.2 : 0.8)
                                
                                Circle().fill(LinearGradient(colors: [spherePrimary, sphereSecondary], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 120, height: 120).scaleEffect(isBreathing ? (isListening ? 1.1 : 1.05) : 0.95)
                                
                                Circle().fill(.ultraThinMaterial).frame(width: 100, height: 100).overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                                
                                Image(systemName: isListening ? "mic.fill" : "aqi.high")
                                    .font(.system(size: 44, weight: .light))
                                    .foregroundColor(isListening ? .green : .white)
                                    .symbolEffect(.bounce, value: isListening)
                            }
                            .shadow(color: spherePrimary.opacity(0.4), radius: isBreathing ? 25 : 15)
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
                            Text(isListening ? "Слушаю вас..." : "Нейро-тренер активен")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundColor(colorScheme == .dark ? .white : .black) // 👈 АДАПТАЦИЯ
                                .contentTransition(.numericText())
                            
                            if isListening {
                                Text(speechRecognizer.transcript.isEmpty ? "Говорите..." : speechRecognizer.transcript)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.green)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .padding(.horizontal, 30)
                            } else {
                                Text("Нажмите на сферу, чтобы сказать")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                        }
                        .frame(height: 60)
                        
                        // 👈 АДАПТИВНЫЙ ПОИСК
                        HStack {
                            Image(systemName: "sparkle.magnifyingglass").foregroundColor(.cyan)
                            TextField("План питания, техника...", text: $userQuery)
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                                .submitLabel(.send)
                                .onSubmit {
                                    if !userQuery.isEmpty {
                                        viewModel.inputText = userQuery
                                        userQuery = ""
                                        showChatView = true
                                    }
                                }
                            if !userQuery.isEmpty {
                                Button(action: { userQuery = "" }) {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(16)
                        .background(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white))
                        .cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05), lineWidth: 1))
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 5, y: 2)
                        .padding(.horizontal, 24)

                        // 👈 АДАПТИВНЫЕ ЧИПСЫ
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 12) {
                                Spacer().frame(width: 12)
                                ForEach(quickPrompts, id: \.self) { prompt in
                                    Button(action: {
                                        HapticManager.shared.selection()
                                        viewModel.inputText = prompt
                                        showChatView = true
                                    }) {
                                        Text(prompt)
                                            .font(.system(size: 13, weight: .bold))
                                            .padding(.horizontal, 16).padding(.vertical, 10)
                                            .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white)
                                            .foregroundColor(colorScheme == .dark ? .white : .black)
                                            .cornerRadius(16)
                                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05), lineWidth: 1))
                                            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.03), radius: 3, y: 2)
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
                    // 👈 АДАПТИВНЫЙ DOCK
                    .background(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.05), lineWidth: 1))
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.08), radius: 20, x: 0, y: 10)
                    .padding(.horizontal, 24).padding(.bottom, 24)
                }
            }
            .navigationBarHidden(true)
            .dynamicTypeSize(.medium ... .accessibility1)
            .onAppear {
                speechRecognizer.requestPermission()
                
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
            .sheet(isPresented: $showAISettings) { AISettingsSheet().presentationDetents([.medium]).presentationDragIndicator(.visible) }
            .fullScreenCover(isPresented: $showChatView) { AIChatBotView(viewModel: viewModel) }
        }
    }
}

// MARK: - ЭКРАН НАСТРОЕК ИИ
struct AISettingsSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AICoachViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme
    
    @AppStorage(Constants.UserDefaultsKeys.aiCoachTone.rawValue) private var aiTone = Constants.AIConstants.defaultTone
    let tones = ["Motivational", "Strict", "Friendly", "Scientific"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Стиль общения тренера"), footer: Text("Влияет на ответы в чате и генерацию тренировок.")) {
                    Picker("Тон", selection: $aiTone) {
                        ForEach(tones, id: \.self) { tone in
                            Text(LocalizedStringKey(tone)).tag(tone)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(themeManager.current.primaryAccent)
                }
                
                Section {
                    Button(role: .destructive) {
                        viewModel.clearChat()
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Очистить текущий чат")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Настройки ИИ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
}

// MARK: - ЭКРАН WORKOUT CONFIG (План)
struct WorkoutConfigSheet: View {
    @Environment(\.colorScheme) private var colorScheme // 👈 АДАПТАЦИЯ
    let levels: [(String, WorkoutDifficulty)] = [("Базовый", .beginner), ("Продвинутый", .intermediate), ("Атлет PRO", .advanced)]
    
    @State private var selectedLevel: WorkoutDifficulty = .intermediate
    @State private var selectedMuscle: CoachMuscleGroup? = nil
    @State private var showExercises = false
    
    func synergyFor(_ muscle: CoachMuscleGroup) -> String? {
        switch muscle {
        case .chest: return "Трицепс, Передняя дельта"
        case .back: return "Бицепс, Трапеция"
        case .legs: return "Ягодицы, Икры"
        case .shoulders: return nil
        case .arms: return nil
        case .abs: return nil
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // 👈 АДАПТИВНЫЙ ФОН
                (colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.11) : Color(UIColor.secondarySystemBackground))
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 32) {
                        
                        Text("Конструктор")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? .white : .black) // 👈 АДАПТАЦИЯ
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                        
                        // БЛОК: ИНТЕНСИВНОСТЬ
                        VStack(alignment: .leading, spacing: 16) {
                            Text("ИНТЕНСИВНОСТЬ")
                                .font(.system(size: 13, weight: .black))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 24)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 12) {
                                    Spacer().frame(width: 12)
                                    ForEach(levels, id: \.0) { level in
                                        let isSelected = selectedLevel == level.1
                                        Button(action: {
                                            HapticManager.shared.impact(.light)
                                            selectedLevel = level.1
                                        }) {
                                            Text(level.0)
                                                .font(.system(size: 15, weight: .bold))
                                                .padding(.horizontal, 20).padding(.vertical, 12)
                                                // 👈 АДАПТАЦИЯ КНОПОК
                                                .background(isSelected ? (colorScheme == .dark ? Color.white : Color.blue) : (colorScheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.16) : Color.white))
                                                .foregroundColor(isSelected ? (colorScheme == .dark ? .black : .white) : (colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8)))
                                                .cornerRadius(12)
                                                .shadow(color: isSelected && colorScheme == .light ? Color.blue.opacity(0.3) : .clear, radius: 5, y: 2)
                                        }
                                    }
                                    Spacer().frame(width: 12)
                                }
                            }
                            .scrollBounceBehavior(.basedOnSize)
                        }
                        
                        // БЛОК: ГЛАВНЫЙ ФОКУС
                        VStack(alignment: .leading, spacing: 16) {
                            Text("ГЛАВНЫЙ ФОКУС")
                                .font(.system(size: 13, weight: .black))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 24)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                ForEach(CoachMuscleGroup.allCases) { muscle in
                                    Button(action: {
                                        HapticManager.shared.impact(.medium)
                                        selectedMuscle = muscle
                                        Task { try? await Task.sleep(nanoseconds: 100_000_000); showExercises = true }
                                    }) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Text(muscle.rawValue)
                                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                                    .foregroundColor(colorScheme == .dark ? .white : .black) // 👈 АДАПТАЦИЯ
                                                
                                                Spacer()
                                                
                                                ZStack {
                                                    Circle()
                                                        .fill(Color(red: 0.7, green: 0.1, blue: 0.8)) // Яркий фиолетовый
                                                        .frame(width: 24, height: 24)
                                                    Image(systemName: "chevron.right")
                                                        .font(.system(size: 12, weight: .bold))
                                                        .foregroundColor(.white)
                                                }
                                            }
                                            
                                            // Синергия
                                            if let syn = synergyFor(muscle) {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "link")
                                                        .font(.system(size: 11, weight: .bold))
                                                    Text(syn)
                                                        .font(.system(size: 12, weight: .medium))
                                                }
                                                .foregroundColor(Color.cyan)
                                                .lineLimit(1)
                                            } else {
                                                Text("Изоляция")
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        .padding(16)
                                        // 👈 АДАПТАЦИЯ КАРТОЧКИ
                                        .background(colorScheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.16) : Color.white)
                                        .cornerRadius(20)
                                        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 5, y: 2)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showExercises) {
                if let m = selectedMuscle {
                    BestExercisesSheet(muscleGroup: m, difficulty: selectedLevel)
                        .presentationDetents([.fraction(0.9), .large])
                        .presentationCornerRadius(35)
                        .presentationDragIndicator(.visible)
                }
            }
        }
    }
}

// MARK: - ЭКРАН ТОП-УПРАЖНЕНИЙ (РЕАЛЬНАЯ ГЕНЕРАЦИЯ)
struct BestExercisesSheet: View {
    @Environment(\.colorScheme) private var colorScheme // 👈 АДАПТАЦИЯ
    let muscleGroup: CoachMuscleGroup
    let difficulty: WorkoutDifficulty
    
    @Environment(DashboardViewModel.self) private var dashboard
    @Environment(WorkoutService.self) private var workoutService
    @Environment(UnitsManager.self) private var unitsManager
    @Environment(DIContainer.self) private var di
    @Environment(\.dismiss) private var dismiss
    
    @State private var isGenerating = true
    @State private var aiErrorMessage: String? = nil
    
    @State private var generatedWorkout: GeneratedWorkoutDTO? = nil
    @State private var aiCoachMessage: String = "Анализирую биометрию..."
    @State private var estimatedTonnage: Double = 0.0
    
    @State private var selectedExercise: GeneratedExerciseDTO? = nil
    @State private var isStarting = false
    @State private var isPulsing = false
    
    private var dummyExercises: [GeneratedExerciseDTO] {
        return (0..<5).map { _ in
            GeneratedExerciseDTO(name: "Загрузка упражнения...", muscleGroup: "Группа", type: "Strength", sets: 3, reps: 10, recommendedWeightKg: 50.0, restSeconds: 90)
        }
    }
    
    var body: some View {
        ZStack {
            // 👈 АДАПТИВНЫЙ ФОН
            (colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color(UIColor.secondarySystemBackground)).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(isGenerating ? "Нейросеть думает..." : "Протокол: \(muscleGroup.rawValue)")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : .black) // 👈
                    Spacer()
                    if !isGenerating && aiErrorMessage == nil {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.cyan)
                            .font(.title2)
                            .symbolEffect(.bounce, options: .nonRepeating)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 30)
                .padding(.bottom, 10)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        
                        // Сообщение от ИИ или Ошибка
                        if !isGenerating {
                            if let errorMsg = aiErrorMessage {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                                    Text(errorMsg).font(.subheadline).foregroundColor(colorScheme == .dark ? .white : .black)
                                    Spacer()
                                }
                                .padding(16)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                            } else {
                                let msg = generatedWorkout?.aiMessage ?? aiCoachMessage
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "brain.head.profile")
                                        .font(.title2)
                                        .foregroundStyle(LinearGradient(colors: [.purple, .cyan], startPoint: .top, endPoint: .bottom))
                                    
                                    Text(msg)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.9)) // 👈
                                        .lineSpacing(4)
                                    Spacer()
                                }
                                .padding(16)
                                // 👈 АДАПТИВНЫЙ ФОН ПУЗЫРЯ
                                .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white)
                                .cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.05), lineWidth: 1))
                                .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 5, y: 2)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        
                        // Инфографика
                        if aiErrorMessage == nil {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Эстимейт Объем").font(.system(size: 12, weight: .bold)).foregroundColor(.gray)
                                    Text("\(Int(estimatedTonnage)) \(unitsManager.weightUnitString())")
                                        .font(.system(size: 20, weight: .black).monospacedDigit())
                                        .foregroundColor(.purple)
                                        .contentTransition(.numericText())
                                }
                                Spacer()
                                Divider().background(Color.gray.opacity(0.2)).frame(height: 30)
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("Сложность").font(.system(size: 12, weight: .bold)).foregroundColor(.gray)
                                    Text(difficulty.rawValue).font(.system(size: 16, weight: .black)).foregroundColor(.cyan)
                                }
                            }
                            .padding(20)
                            // 👈 АДАПТИВНЫЙ ФОН ИНФОГРАФИКИ
                            .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white)
                            .cornerRadius(20)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black.opacity(0.05), lineWidth: 1))
                            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 5, y: 2)
                            .redacted(reason: isGenerating ? .placeholder : [])
                            .opacity(isGenerating ? (isPulsing ? 0.6 : 1.0) : 1.0)
                        }
                        
                        // СПИСОК УПРАЖНЕНИЙ
                        if isGenerating {
                            ForEach(Array(dummyExercises.enumerated()), id: \.offset) { index, dummy in
                                AIExerciseRowView(index: index, exercise: dummy, unitsManager: unitsManager) { }
                                    .redacted(reason: .placeholder)
                                    .scaleEffect(isPulsing ? 1.02 : 0.98)
                                    .opacity(isPulsing ? 0.5 : 1.0)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(Double(index) * 0.1), value: isPulsing)
                            }
                        } else if let workout = generatedWorkout, !workout.exercises.isEmpty {
                            ForEach(Array(workout.exercises.enumerated()), id: \.offset) { index, dto in
                                AIExerciseRowView(index: index, exercise: dto, unitsManager: unitsManager) {
                                    HapticManager.shared.impact(.medium)
                                    selectedExercise = dto
                                }
                                .transition(.opacity.combined(with: .scale))
                            }
                        } else if !isGenerating {
                            Text("Не удалось создать программу. Попробуйте еще раз.")
                                .foregroundColor(.gray)
                                .padding(.top, 20)
                        }
                        
                        // Кнопка СТАРТ
                        if !isGenerating && generatedWorkout != nil && !(generatedWorkout?.exercises.isEmpty ?? true) {
                            Button(action: startGeneratedWorkout) {
                                HStack {
                                    if isStarting {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("Начать протокол").font(.system(size: 16, weight: .bold))
                                        Image(systemName: "bolt.fill")
                                    }
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(LinearGradient(colors: [.purple, .cyan], startPoint: .leading, endPoint: .trailing))
                                .foregroundColor(.white).cornerRadius(20)
                                .shadow(color: .cyan.opacity(0.4), radius: 15, y: 5)
                            }
                            .padding(.top, 10)
                            .buttonStyle(ParallaxButtonStyle())
                            .disabled(isStarting)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
                }
            }
        }
        .onAppear { isPulsing = true }
        .task { await generateRealAIRoutine() }
        .sheet(item: Binding(
            get: { selectedExercise.map { IdentifiableGeneratedEx(dto: $0) } },
            set: { selectedExercise = $0?.dto }
        )) { wrapper in
            let tempDTO = ExerciseDTO(name: wrapper.dto.name, muscleGroup: wrapper.dto.muscleGroup, type: .strength, category: .other, effort: 8, isCompleted: false)
            ExerciseTechniqueSheet(exercise: tempDTO)
                .presentationDetents([.medium])
                .presentationCornerRadius(35)
                .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - REAL GEMINI AI LOGIC
    private func generateRealAIRoutine() async {
        await MainActor.run {
            self.isGenerating = true
            self.aiErrorMessage = nil
            self.generatedWorkout = nil
        }
        
        let prCache = dashboard.personalRecordsCache
        let tone = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.aiCoachTone.rawValue) ?? Constants.AIConstants.defaultTone
        let bodyWeight = UserDefaults.standard.double(forKey: Constants.UserDefaultsKeys.userBodyWeight.rawValue)
        
        let relevantExercises = await ExerciseDatabaseService.shared.getRelevantExercisesContext(
            for: muscleGroup.engineName,
            equipmentPref: "full gym",
            limit: 20
        )
        
        let userContext = UserProfileContext(
            weightKg: UnitsManager.shared.convertToKilograms(bodyWeight),
            experienceLevel: difficulty.rawValue,
            favoriteMuscles: [muscleGroup.engineName],
            recentPRs: prCache,
            language: "Russian",
            workoutsThisWeek: 0,
            currentStreak: dashboard.streakCount,
            fatiguedMuscles: [],
            availableExercises: relevantExercises,
            aiCoachTone: tone,
            weightUnit: unitsManager.weightUnitString()
        )
        
        let prompt = """
        Твоя задача: сгенерировать силовую тренировку на мышечную группу: \(muscleGroup.rawValue).
        Уровень подготовки пользователя: \(difficulty.rawValue).
        ОБЯЗАТЕЛЬНЫЕ ТРЕБОВАНИЯ К JSON:
        1. "hasWorkout" установи строго в true.
        2. "workoutTitle" установи в "Протокол: \(muscleGroup.rawValue)".
        3. Сгенерируй ровно 4 или 5 упражнений в массив "exercises". Выбирай только из списка доступных.
        4. "aiMessage": напиши энергичное, мотивирующее приветствие на русском языке.
        """
        
        do {
            let response = try await di.aiLogicService.generateWorkoutPlan(userRequest: prompt, userProfile: userContext)
            
            await MainActor.run {
                if let workout = response.workout, !workout.exercises.isEmpty {
                    self.generatedWorkout = workout
                    self.aiCoachMessage = response.text
                    
                    var tonnage = 0.0
                    for ex in workout.exercises {
                        let w = ex.recommendedWeightKg ?? 0.0
                        let s = Double(ex.sets)
                        let r = Double(ex.reps)
                        tonnage += w * s * r
                    }
                    self.estimatedTonnage = unitsManager.convertFromKilograms(tonnage)
                } else {
                    self.aiErrorMessage = "ИИ ответил, но забыл добавить упражнения. Нажмите Отмена и попробуйте еще раз."
                }
                withAnimation(.easeOut(duration: 0.4)) { self.isGenerating = false }
            }
        } catch {
            await MainActor.run {
                self.aiErrorMessage = "Ошибка связи с ИИ: \(error.localizedDescription)"
                withAnimation(.easeOut(duration: 0.4)) { self.isGenerating = false }
            }
        }
    }
    
    private func startGeneratedWorkout() {
        guard !isStarting, let dto = generatedWorkout else { return }
        isStarting = true
        HapticManager.shared.impact(.heavy)
        
        Task {
            await workoutService.startGeneratedWorkout(dto)
            if let newWorkout = await workoutService.fetchLatestWorkout() {
                di.appState.returnToActiveWorkoutId = newWorkout.persistentModelID
                di.appState.selectedTab = 2 // Workout Hub
            }
            dismiss()
        }
    }
}

// Строка для GeneratedExerciseDTO
struct AIExerciseRowView: View {
    let index: Int
    let exercise: GeneratedExerciseDTO?
    let unitsManager: UnitsManager
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme // 👈 АДАПТАЦИЯ
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                HStack(alignment: .top) {
                    Text(String(format: "%02d", index + 1))
                        .font(.system(size: 24, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.2) : .black.opacity(0.15)) // 👈
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise != nil ? LocalizationHelper.shared.translateName(exercise!.name) : "Загрузка упражнения...")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : .black) // 👈
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        Text(exercise?.muscleGroup ?? "Мышечная группа")
                            .font(.system(size: 13))
                            .foregroundColor(.cyan)
                    }
                    .padding(.leading, 8)
                    
                    Spacer()
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(.purple.opacity(0.8))
                }
                
                Divider().background(Color.gray.opacity(0.2)) // 👈
                
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.2.squarepath")
                            .foregroundColor(.purple)
                        Text("\(exercise?.sets ?? 3)х\(exercise?.reps ?? 10)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : .black) // 👈
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "scalemass.fill")
                            .foregroundColor(.cyan)
                        let w = unitsManager.convertFromKilograms(exercise?.recommendedWeightKg ?? 0.0)
                        Text(w > 0 ? "\(Int(w)) \(unitsManager.weightUnitString())" : "Свой вес")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : .black) // 👈
                    }
                }.padding(.top, 4)
            }
            .padding(20)
            // 👈 АДАПТИВНЫЙ ФОН
            .background(colorScheme == .dark ? Color(UIColor.secondarySystemGroupedBackground) : Color.white)
            .cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.black.opacity(0.05), lineWidth: 1))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 5, y: 2)
        }
        .buttonStyle(ParallaxButtonStyle())
    }
}

struct ExerciseRowView: View {
    let index: Int
    let exercise: ExerciseDTO?
    let unitsManager: UnitsManager
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme // 👈 АДАПТАЦИЯ
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                HStack(alignment: .top) {
                    Text(String(format: "%02d", index + 1))
                        .font(.system(size: 24, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.2) : .black.opacity(0.15)) // 👈
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizationHelper.shared.translateName(exercise?.name ?? "Exercise Name"))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : .black) // 👈
                            .lineLimit(1)
                        Text(exercise?.type.rawValue ?? "Type")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                    .padding(.leading, 8)
                    
                    Spacer()
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(.purple.opacity(0.8))
                }
                
                Divider().background(Color.gray.opacity(0.2)) // 👈
                
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "flame")
                            .foregroundColor(.orange)
                        Text("RPE \(exercise?.effort ?? 8)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : .black) // 👈
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.2.squarepath")
                            .foregroundColor(.purple)
                        Text("\(exercise?.sets ?? 3)х\(exercise?.reps ?? 10)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : .black) // 👈
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "scalemass.fill")
                            .foregroundColor(.cyan)
                        let w = unitsManager.convertFromKilograms(exercise?.recommendedWeightKg ?? 0.0)
                        Text(w > 0 ? "\(Int(w)) \(unitsManager.weightUnitString())" : "BW")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : .black) // 👈
                    }
                }.padding(.top, 4)
            }
            .padding(20)
            // 👈 АДАПТИВНЫЙ ФОН
            .background(colorScheme == .dark ? Color(UIColor.secondarySystemGroupedBackground) : Color.white)
            .cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.black.opacity(0.05), lineWidth: 1))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 5, y: 2)
        }
        .buttonStyle(ParallaxButtonStyle())
    }
}

// MARK: - ЭКРАН ТЕХНИКИ ВЫПОЛНЕНИЯ
struct ExerciseTechniqueSheet: View {
    let exercise: ExerciseDTO
    @Environment(\.colorScheme) private var colorScheme // 👈 АДАПТАЦИЯ
    
    var body: some View {
        ZStack(alignment: .top) {
            // 👈 АДАПТИВНЫЙ ФОН
            (colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color(UIColor.secondarySystemBackground)).ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Хедер
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizationHelper.shared.translateName(exercise.name))
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? .white : .black) // 👈
                        
                        HStack(spacing: 12) {
                            BadgeView(text: exercise.muscleGroup, color: .purple)
                            BadgeView(text: "RPE \(exercise.effort)", color: .orange)
                        }
                    }.padding(.horizontal, 24).padding(.top, 30)
                    
                    // Инструкции
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "figure.strengthtraining.traditional").foregroundColor(.cyan)
                            Text("ПРАВИЛЬНАЯ ТЕХНИКА").font(.system(size: 12, weight: .black)).foregroundColor(.gray)
                        }
                        Text(TechniqueHelper.getDescription(for: exercise.category))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(colorScheme == .dark ? .white : .black) // 👈
                            .lineSpacing(6)
                    }
                    .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                    // 👈 АДАПТИВНЫЙ ФОН
                    .background(colorScheme == .dark ? Color(UIColor.secondarySystemGroupedBackground) : Color.white)
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 5, y: 2)
                    .padding(.horizontal, 24)
                    
                    // Советы
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "sparkles").foregroundColor(.orange)
                            Text("ИИ ПРО-СОВЕТ").font(.system(size: 12, weight: .black)).foregroundColor(.orange)
                        }
                        
                        let tips = TechniqueHelper.getTips(for: exercise.category)
                        ForEach(tips, id: \.self) { tip in
                            HStack(alignment: .top) {
                                Text("•").foregroundColor(.orange)
                                Text(tip)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(colorScheme == .dark ? .white : .black) // 👈
                            }
                        }
                    }
                    .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                    .cornerRadius(24).padding(.horizontal, 24)
                    
                }.padding(.bottom, 40)
            }
        }
    }
}
// MARK: - ЭКРАН ПРОГРЕССА
struct ProgressAnalysisSheet: View {
    @Environment(DIContainer.self) private var di
    @Environment(ThemeManager.self) private var themeManager
    @Environment(UnitsManager.self) private var unitsManager
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var colorManager = MuscleColorManager.shared
    
    @Query(filter: #Predicate<Workout> { $0.endTime != nil }, sort: \.date, order: .reverse)
    private var allWorkouts: [Workout]
    
    let periods = ["Последние 7 дней", "Мезоцикл (4 нед.)", "Макроцикл (12 нед.)"]
    let focuses = ["Дисбаланс мышц", "Лидеры роста"]
    
    @State private var selectedPeriod = "Мезоцикл (4 нед.)"
    @State private var selectedFocus = "Дисбаланс мышц"
    
    @State private var stats: [MuscleStats] = []
    @State private var activeSegment: UUID? = nil
    
    @State private var isAnalyzing = true
    @State private var impulseValue: Int = 0
    @State private var impulseMuscle: String = "Грудь"
    @State private var aiConclusion: String = "Нейросеть анализирует ваш мышечный баланс..."
    
    @State private var appearAnimate = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Адаптивный фон
                (colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color(UIColor.secondarySystemBackground)).ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 30) {
                        Spacer().frame(height: 70)
                        
                        if isAnalyzing && stats.isEmpty {
                            loadingView
                        } else if stats.isEmpty {
                            emptyDataView
                        } else {
                            aiPredictorSection
                            analyticsParamsSection
                            chartsSection
                            aiConclusionSection
                        }
                    }
                    .padding(.bottom, 40)
                }
                
                // Плавающий хедер
                floatingHeader
            }
            .navigationBarHidden(true)
            .task(id: selectedPeriod) { await loadDataAndAnalyze() }
            .task(id: selectedFocus) { await generateAIConclusion() }
            .onAppear {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) { appearAnimate = true }
            }
        }
    }
    
    // MARK: - View Sub-Components (Разбито для помощи компилятору)
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView().scaleEffect(1.5).tint(.cyan)
            Text("Собираю данные из базы...").font(.headline).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity).padding(.top, 100)
    }
    
    private var emptyDataView: some View {
        EmptyStateView(
            icon: "chart.pie.fill",
            title: "Недостаточно данных",
            message: "Для анализа за этот период нужно завершить хотя бы несколько тренировок."
        )
        .padding(.top, 50)
    }
    
    @ViewBuilder
    private var aiPredictorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "cpu").foregroundColor(.purple)
                Text("ИИ-ПРЕДИКТОР").font(.system(size: 12, weight: .black)).foregroundColor(.gray)
            }
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Импульс роста").font(.system(size: 14, weight: .medium)).foregroundColor(.gray)
                    HStack(alignment: .firstTextBaseline) {
                        Text(impulseValue > 0 ? "+\(impulseValue)%" : "\(impulseValue)%")
                            .font(.system(size: 38, weight: .black, design: .rounded).monospacedDigit())
                            .foregroundColor(impulseValue > 0 ? .cyan : (impulseValue < 0 ? .orange : .gray))
                            .contentTransition(.numericText())
                        Text("к объему").font(.system(size: 16, weight: .bold)).foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                }
                Spacer()
                ZStack {
                    Circle().stroke(Color.cyan.opacity(0.3), lineWidth: 2).frame(width: 60, height: 60)
                    Circle().fill(Color.cyan.opacity(0.1)).frame(width: 60, height: 60)
                    Image(systemName: impulseValue >= 0 ? "arrow.up.forward" : "arrow.down.right")
                        .font(.title2)
                        .foregroundColor(impulseValue >= 0 ? .cyan : .orange)
                        .offset(x: appearAnimate ? 5 : -5, y: appearAnimate ? -5 : 5)
                }.modifier(PulseEffect())
            }
            Text("При текущем объеме, ожидается прорыв в силовых на **\(impulseMuscle)** в ближайшее время.")
                .font(.system(size: 14)).foregroundColor(.gray)
        }
        .padding(20)
        .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(LinearGradient(colors: [.purple.opacity(0.4), .cyan.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.05 : 0.05), radius: 10, y: 5)
        .padding(.horizontal, 24)
    }
    
    @ViewBuilder
    private var analyticsParamsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ДЕТАЛЬНАЯ АНАЛИТИКА").font(.system(size: 12, weight: .black)).foregroundColor(.gray).padding(.horizontal, 24)
            VStack(spacing: 2) {
                Menu {
                    ForEach(periods, id: \.self) { p in
                        Button(p) { selectedPeriod = p }
                    }
                } label: {
                    HStack {
                        Text("Период").foregroundColor(.gray)
                        Spacer()
                        Text(selectedPeriod).fontWeight(.bold).foregroundColor(colorScheme == .dark ? .white : .black)
                        Image(systemName: "chevron.up.chevron.down").foregroundColor(.cyan).font(.caption)
                    }
                    .padding()
                    .background(colorScheme == .dark ? Color(UIColor.secondarySystemGroupedBackground) : Color.white)
                }
                
                Divider().background(Color.gray.opacity(0.2)).padding(.horizontal)
                
                Menu {
                    ForEach(focuses, id: \.self) { f in
                        Button(f) { selectedFocus = f }
                    }
                } label: {
                    HStack {
                        Text("Акцент").foregroundColor(.gray)
                        Spacer()
                        Text(selectedFocus).fontWeight(.bold).foregroundColor(colorScheme == .dark ? .white : .black)
                        Image(systemName: "chevron.up.chevron.down").foregroundColor(.purple).font(.caption)
                    }
                    .padding()
                    .background(colorScheme == .dark ? Color(UIColor.secondarySystemGroupedBackground) : Color.white)
                }
            }
            .cornerRadius(20)
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.03 : 0.05), radius: 5, y: 2)
            .padding(.horizontal, 24)
        }
    }
    
    @ViewBuilder
    private var chartsSection: some View {
        VStack(alignment: .center, spacing: 24) {
            ZStack {
                CustomDonutChart(data: stats.map { ($0.pastShare, $0.color.opacity(0.3), $0.id) }, thickness: 10, activeId: $activeSegment)
                    .frame(width: 150, height: 150)
                
                CustomDonutChart(data: stats.map { ($0.currentShare, $0.color, $0.id) }, thickness: 18, activeId: $activeSegment)
                    .frame(width: 210, height: 210)
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 5)
                
                VStack {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 34))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }
            }
            .scaleEffect(appearAnimate ? 1 : 0.8).opacity(appearAnimate ? 1 : 0)
            .padding(.vertical, 10)
            
            VStack(spacing: 16) {
                ForEach(stats) { stat in
                    StatRowView(stat: stat, appearAnimate: appearAnimate, isSelected: activeSegment == stat.id)
                        .onTapGesture {
                            withAnimation(.spring()) { activeSegment = (activeSegment == stat.id) ? nil : stat.id }
                        }
                }
            }
        }.frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var aiConclusionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ИИ ВЫВОД").font(.system(size: 12, weight: .black)).foregroundColor(.purple).padding(.horizontal, 24)
            
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "sparkles.tv")
                    .font(.title)
                    .foregroundStyle(LinearGradient(colors: [.purple, .cyan], startPoint: .top, endPoint: .bottom))
                
                VStack(alignment: .leading, spacing: 8) {
                    if isAnalyzing {
                        ProgressView().tint(.purple)
                    } else {
                        Text(aiConclusion)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .lineSpacing(4)
                            .transition(.opacity)
                    }
                }
                Spacer()
            }
            .padding(20)
            .background(colorScheme == .dark ? Color(UIColor.secondarySystemGroupedBackground) : Color.white)
            .cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.purple.opacity(0.2), lineWidth: 1))
            .shadow(color: .purple.opacity(0.05), radius: 10, y: 5)
            .padding(.horizontal, 24)
        }
    }
    
    private var floatingHeader: some View {
        VStack {
            HStack {
                Text("Прогресс")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                Spacer()
            }
            .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 10)
        }
        .background(.regularMaterial)
    }
    
    // MARK: - Logic Methods
    
    private func loadDataAndAnalyze() async {
        isAnalyzing = true
        let calendar = Calendar.current
        let now = Date()
        
        let days: Int
        switch selectedPeriod {
        case "Последние 7 дней": days = 7
        case "Мезоцикл (4 нед.)": days = 28
        case "Макроцикл (12 нед.)": days = 84
        default: days = 28
        }
        
        let currentStart = calendar.date(byAdding: .day, value: -days, to: now)!
        let previousStart = calendar.date(byAdding: .day, value: -(days * 2), to: now)!
        
        var currentSets: [String: Double] = [:]
        var previousSets: [String: Double] = [:]
        var currentVolume = 0.0
        var previousVolume = 0.0
        
        for workout in allWorkouts {
            let isCurrent = workout.date >= currentStart && workout.date <= now
            let isPrev = workout.date >= previousStart && workout.date < currentStart
            if !isCurrent && !isPrev { continue }
            
            for ex in workout.exercises {
                let targets = ex.isSuperset ? ex.subExercises : [ex]
                for sub in targets where sub.type == .strength {
                    let completedSets = sub.setsList.filter { $0.isCompleted && $0.type != .warmup }
                    if !completedSets.isEmpty {
                        let broadCategory = MuscleCategoryMapper.getBroadCategory(for: sub.muscleGroup)
                        if broadCategory != "Other" {
                            let vol = completedSets.reduce(0.0) { result, set in
                                result + ((set.weight ?? 0) * Double(set.reps ?? 0))
                            }
                            if isCurrent {
                                currentSets[broadCategory, default: 0] += Double(completedSets.count)
                                currentVolume += vol
                            } else {
                                previousSets[broadCategory, default: 0] += Double(completedSets.count)
                                previousVolume += vol
                            }
                        }
                    }
                }
            }
        }
        
        let totalCurrent = currentSets.values.reduce(0, +)
        let totalPrevious = previousSets.values.reduce(0, +)
        
        var newStats: [MuscleStats] = []
        let allKeys = Set(currentSets.keys).union(Set(previousSets.keys))
        
        var maxSets = 0.0
        var topCurrentMuscleEnglish = "Chest"
        
        for key in allKeys {
            let cShare = totalCurrent > 0 ? (currentSets[key] ?? 0) / totalCurrent * 100.0 : 0
            let pShare = totalPrevious > 0 ? (previousSets[key] ?? 0) / totalPrevious * 100.0 : 0
            if (currentSets[key] ?? 0) > maxSets {
                maxSets = currentSets[key] ?? 0
                topCurrentMuscleEnglish = key
            }
            let color = colorManager.getColor(for: key)
            let localizedName = localizeMuscle(key)
            newStats.append(MuscleStats(name: localizedName, currentShare: cShare, pastShare: pShare, color: color))
        }
        
        newStats.sort { $0.currentShare > $1.currentShare }
        
        let impulse: Int
        if previousVolume > 0 {
            impulse = Int(((currentVolume - previousVolume) / previousVolume) * 100.0)
        } else if currentVolume > 0 {
            impulse = 100
        } else {
            impulse = 0
        }
        
        let topCurrentMuscleLocalized = localizeMuscle(topCurrentMuscleEnglish)
        
        await MainActor.run {
            self.stats = Array(newStats.prefix(6))
            self.impulseValue = impulse
            self.impulseMuscle = topCurrentMuscleLocalized
            
            if !self.stats.isEmpty {
                Task { await generateAIConclusion() }
            } else {
                self.isAnalyzing = false
            }
        }
    }
    
    private func generateAIConclusion() async {
        guard !stats.isEmpty else { return }
        isAnalyzing = true
        
        var contextStr = "Моя статистика за период:\n"
        for stat in stats {
            let diff = stat.currentShare - stat.pastShare
            let sign = diff >= 0 ? "+" : ""
            contextStr += "- \(stat.name): Было \(Int(stat.pastShare))%, Стало \(Int(stat.currentShare))% (Тенденция: \(sign)\(Int(diff))%)\n"
        }
        
        let prompt = """
        Ты профессиональный ИИ-тренер.
        Пользователь смотрит на аналитику распределения нагрузки по мышцам.
        Его акцент сейчас: "\(selectedFocus)".
        Проанализируй предоставленные данные и напиши короткий, мотивирующий и прямой вывод-совет на РУССКОМ ЯЗЫКЕ (максимум 2-3 предложения).
        Укажи на явные дисбалансы или похвали за фокус. Не используй Markdown-форматирование (никаких звездочек и жирного шрифта).
        """
        
        let userContext = UserProfileContext(weightKg: 80, experienceLevel: "Pro", favoriteMuscles: [], recentPRs: [:], language: "Russian", workoutsThisWeek: 0, currentStreak: 0, fatiguedMuscles: [], availableExercises: [], aiCoachTone: "Strict", weightUnit: "kg")
        
        do {
            let stream = try await di.aiLogicService.streamChatResponse(userRequest: prompt + "\n\n" + contextStr, userProfile: userContext)
            
            var fullResponse = ""
            for try await chunk in stream {
                fullResponse += chunk
                await MainActor.run {
                    self.aiConclusion = fullResponse
                }
            }
            await MainActor.run { self.isAnalyzing = false }
        } catch {
            await MainActor.run {
                self.aiConclusion = "Не удалось связаться с сервером. Но судя по цифрам, вам стоит обратить внимание на отстающие группы мышц."
                self.isAnalyzing = false
            }
        }
    }
    
    private func localizeMuscle(_ englishName: String) -> String {
        switch englishName {
        case "Chest": return "Грудь"
        case "Back": return "Спина"
        case "Legs": return "Ноги"
        case "Shoulders": return "Плечи"
        case "Arms": return "Руки"
        case "Core": return "Пресс"
        case "Cardio": return "Кардио"
        default: return englishName
        }
    }
}

// MARK: - ЭКРАН REST (ЦНС)
struct RestAnalysisSheet: View {
    @AppStorage("sleepHours") private var sleepHours: Double = 7.5
    @AppStorage("waterCups") private var waterCups: Int = 4
    @AppStorage("cnsScore") private var cnsScore: Double = 85.0
    @Environment(\.colorScheme) private var colorScheme // 👈
    
    var cnsLoad: Double {
        let sleepFactor = max(0, (8.0 - sleepHours) * 10)
        let waterFactor = max(0, (8 - waterCups) * 2)
        return min(100, 20 + sleepFactor + Double(waterFactor))
    }
    var cnsColor: Color { switch cnsLoad { case 0..<40: return .green; case 40..<75: return .orange; default: return .red } }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Адаптивный фон
                (colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color(UIColor.secondarySystemBackground)).ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 32) {
                        Spacer().frame(height: 70)
                        
                        VStack(spacing: 16) {
                            Text("ИСТОЩЕНИЕ ЦНС").font(.system(size: 12, weight: .black)).foregroundColor(.gray)
                            ZStack {
                                Circle().stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05), lineWidth: 15).frame(width: 150, height: 150)
                                Circle().trim(from: 0, to: cnsLoad / 100).stroke(cnsColor, style: StrokeStyle(lineWidth: 15, lineCap: .round)).frame(width: 150, height: 150).rotationEffect(.degrees(-90)).animation(.spring(response: 0.6, dampingFraction: 0.7), value: cnsLoad)
                                VStack { Text("\(Int(cnsLoad))%").font(.system(size: 36, weight: .black, design: .rounded).monospacedDigit()).foregroundColor(colorScheme == .dark ? .white : .black).contentTransition(.numericText()); Text(cnsLoad < 40 ? "Свежий" : (cnsLoad < 75 ? "Усталость" : "Перетрен")).font(.system(size: 14, weight: .bold)).foregroundColor(cnsColor) }
                            }
                        }.frame(maxWidth: .infinity).padding(.bottom, 10)
                        
                        VStack(alignment: .leading, spacing: 20) {
                            Text("БИОМЕТРИЯ").font(.system(size: 12, weight: .black)).foregroundColor(.gray).padding(.horizontal, 24)
                            VStack(spacing: 12) {
                                HStack { Image(systemName: "moon.zzz.fill").foregroundColor(.purple); Text("Сон прошлой ночью").font(.system(size: 16, weight: .medium)).foregroundColor(colorScheme == .dark ? .white : .black); Spacer(); Text(String(format: "%.1f ч", sleepHours)).font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit()).foregroundColor(.purple) }
                                Slider(value: $sleepHours, in: 3...12, step: 0.5) { _ in HapticManager.shared.selection(); updateCNS() }.tint(.purple)
                            }
                            .padding(20)
                            .background(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white))
                            .cornerRadius(24)
                            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 5, y: 2)
                            .padding(.horizontal, 24)
                            
                            VStack(spacing: 12) {
                                HStack { Image(systemName: "drop.fill", variableValue: Double(waterCups)/10.0).foregroundColor(.cyan); Text("Гидратация (стаканы)").font(.system(size: 16, weight: .medium)).foregroundColor(colorScheme == .dark ? .white : .black); Spacer(); Text("\(waterCups)").font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit()).foregroundColor(.cyan) }
                                Slider(value: Binding(get: { Double(waterCups) }, set: { waterCups = Int($0) }), in: 0...15, step: 1) { _ in HapticManager.shared.selection(); updateCNS() }.tint(.cyan)
                            }
                            .padding(20)
                            .background(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white))
                            .cornerRadius(24)
                            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 5, y: 2)
                            .padding(.horizontal, 24)
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
                
                VStack { HStack { Text("Восстановление").font(.system(size: 32, weight: .black, design: .rounded)).foregroundColor(colorScheme == .dark ? .white : .black); Spacer() }.padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 10) }.background(.regularMaterial)
            }.navigationBarHidden(true)
        }
    }
    private func updateCNS() { cnsScore = 100 - cnsLoad }
}

// MARK: - ВСПОМОГАТЕЛЬНЫЕ КОМПОНЕНТЫ

struct MicroMetric: View {
    var title: String
    var value: String
    var unit: String
    var color: Color
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 18, weight: .black, design: .rounded).monospacedDigit()).foregroundColor(color)
                Text(unit).font(.system(size: 10, weight: .medium)).foregroundColor(.gray)
            }
        }
    }
}

struct AICoachIsland: View {
    var title: String
    var icon: String
    var color: Color
    var action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.medium)
            action()
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(LinearGradient(colors: [colorScheme == .dark ? .white : color, color], startPoint: .topLeading, endPoint: .bottomTrailing))
                Text(title).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(colorScheme == .dark ? .white : .black)
            }
            .contentShape(Rectangle())
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(colorScheme == .dark ? color.opacity(0.1) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(colorScheme == .dark ? Color.clear : Color.black.opacity(0.05), lineWidth: 1))
            .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.05), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct StatRowView: View {
    let stat: MuscleStats
    let appearAnimate: Bool
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        let diff = stat.currentShare - stat.pastShare
        let diffStr = diff > 0 ? "+\(String(format: "%.1f", diff))%" : "\(String(format: "%.1f", diff))%"
        VStack(spacing: 6) {
            HStack {
                Circle().fill(stat.color).frame(width: 8, height: 8).scaleEffect(isSelected ? 1.5 : 1.0)
                Text(stat.name).font(.system(size: 15, weight: .bold)).foregroundColor(colorScheme == .dark ? .white : .black)
                Spacer()
                Text(diffStr).font(.system(size: 13, weight: .bold).monospacedDigit()).foregroundColor(diff > 0 ? .green : (diff < 0 ? .red : .gray))
                Text("\(String(format: "%.1f", stat.currentShare))%").font(.system(size: 16, weight: .black).monospacedDigit()).foregroundColor(colorScheme == .dark ? .white : .black).frame(width: 55, alignment: .trailing)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.15)).frame(height: 6)
                    Capsule()
                        .fill(LinearGradient(colors: [stat.color.opacity(0.5), stat.color], startPoint: .leading, endPoint: .trailing))
                        .frame(width: appearAnimate ? geo.size.width * (stat.currentShare / 40.0) : 0, height: 6)
                }
            }.frame(height: 6)
        }.padding(.horizontal, 30)
    }
}

struct RecoveryBadge: View {
    var icon: String
    var text: String
    var color: Color
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(color)
            Text(text).font(.system(size: 13, weight: .bold)).foregroundColor(colorScheme == .dark ? .white : .black)
        }
        .padding(.horizontal, 16).padding(.vertical, 12).frame(maxWidth: .infinity, alignment: .leading)
        .background(colorScheme == .dark ? Color(UIColor.secondarySystemGroupedBackground) : Color.white)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(colorScheme == .dark ? color.opacity(0.2) : Color.black.opacity(0.05), lineWidth: 1))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 5, y: 2)
    }
}

struct BadgeView: View {
    let text: String; let color: Color
    var body: some View { Text(text).font(.system(size: 12, weight: .bold)).foregroundColor(color).padding(.horizontal, 10).padding(.vertical, 6).background(color.opacity(0.15)).cornerRadius(8) }
}

// ✅ ДОБАВЛЕНА СТРУКТУРА-ОБЕРТКА ДЛЯ ИСПРАВЛЕНИЯ ВТОРОЙ ОШИБКИ КОМПИЛЯЦИИ
struct IdentifiableGeneratedEx: Identifiable {
    let id = UUID()
    let dto: GeneratedExerciseDTO
}
