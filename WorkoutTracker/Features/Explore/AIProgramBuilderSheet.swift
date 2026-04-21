// ============================================================
// FILE: WorkoutTracker/Features/Explore/AIProgramBuilderSheet.swift
// ============================================================

internal import SwiftUI

// Вспомогательные расширения для UI
extension ProgramGoal {
    var icon: String {
        switch self {
        case .buildMuscle: return "figure.strengthtraining.traditional"
        case .getStronger: return "dumbbell.fill"
        case .loseWeight: return "flame.fill"
        }
    }
    var color: Color {
        switch self {
        case .buildMuscle: return .blue
        case .getStronger: return .purple
        case .loseWeight: return .orange
        }
    }
}

struct AIProgramBuilderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DIContainer.self) private var di
    @Environment(PresetService.self) private var presetService
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme // 👈 Адаптация
    
    @State private var viewModel: AIProgramBuilderViewModel
    
    init(aiLogicService: AILogicService) {
        _viewModel = State(initialValue: AIProgramBuilderViewModel(aiLogicService: aiLogicService))
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Адаптивный фон: темно-серый в светлой теме, глубокий фон в темной
                (colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground))
                    .ignoresSafeArea()
                
                switch viewModel.state {
                case .idle, .error:
                    configuratorView
                case .loading:
                    loadingView
                case .success(let dto):
                    resultView(dto: dto)
                }
            }
            .navigationTitle("ИИ Архитектор")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let gen = UIImpactFeedbackGenerator(style: .light)
                        gen.impactOccurred()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.3))
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(viewModel.state.isLoading || viewModel.isSaving)
    }
    
    // MARK: - 1. CONFIGURATOR VIEW (Control Panel)
    private var configuratorView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 32) {
                
                // Заголовок
                VStack(alignment: .leading, spacing: 8) {
                    Text("Create Your Split")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    Text("Set parameters and AI will build your perfect multi-day program.")
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                if case .error(let msg) = viewModel.state {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Error: \(msg)")
                    }
                    .font(.caption).foregroundColor(.red)
                    .padding().frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1)).cornerRadius(12)
                    .padding(.horizontal, 20)
                }
                
                // БЛОК 1: ЦЕЛЬ (Карточки)
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader(title: "1. Main Goal", icon: "target")
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            Spacer().frame(width: 8)
                            ForEach(ProgramGoal.allCases) { goal in
                                GoalSelectionCard(
                                    goal: goal,
                                    isSelected: viewModel.goal == goal
                                ) {
                                    UISelectionFeedbackGenerator().selectionChanged()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { viewModel.goal = goal }
                                }
                            }
                            Spacer().frame(width: 8)
                        }
                    }
                }
                
                // БЛОК 2: ПАРАМЕТРЫ (Тактильные кнопки)
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader(title: "2. Parameters", icon: "slider.horizontal.3")
                    
                    VStack(alignment: .leading, spacing: 20) {
                        // Расписание
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Days per Week").font(.subheadline).foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .gray)
                            HStack(spacing: 10) {
                                ForEach(2...6, id: \.self) { day in
                                    let isSelected = viewModel.daysPerWeek == day
                                    Button {
                                        UISelectionFeedbackGenerator().selectionChanged()
                                        withAnimation { viewModel.daysPerWeek = day }
                                    } label: {
                                        Text("\(day)")
                                            .font(.title3).bold()
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(isSelected ? themeManager.current.primaryAccent : (colorScheme == .dark ? Color.white.opacity(0.05) : Color(UIColor.systemGray6)))
                                            .foregroundColor(isSelected ? .white : (colorScheme == .dark ? .white : .black))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        Divider().opacity(0.5)
                        
                        // Уровень
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Experience Level").font(.subheadline).foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .gray)
                            HStack {
                                ForEach(ProgramLevel.allCases) { lvl in
                                    let isSelected = viewModel.level == lvl
                                    Button {
                                        UISelectionFeedbackGenerator().selectionChanged()
                                        withAnimation { viewModel.level = lvl }
                                    } label: {
                                        Text(LocalizedStringKey(lvl.rawValue))
                                            .font(.caption).fontWeight(isSelected ? .bold : .medium)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(isSelected ? Color.blue.opacity(0.15) : Color.clear)
                                            .foregroundColor(isSelected ? .blue : (colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8)))
                                            .cornerRadius(10)
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Color.blue : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)), lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        Divider().opacity(0.5)
                        
                        // Equipment
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Equipment").font(.subheadline).foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .gray)
                            HStack {
                                ForEach(ProgramEquipment.allCases) { eq in
                                    let isSelected = viewModel.equipment == eq
                                    Button {
                                        UISelectionFeedbackGenerator().selectionChanged()
                                        withAnimation { viewModel.equipment = eq }
                                    } label: {
                                        VStack(spacing: 6) {
                                            Image(systemName: eq.icon).font(.title3)
                                            Text(LocalizedStringKey(eq.rawValue)).font(.caption2).fontWeight(isSelected ? .bold : .medium).lineLimit(1).minimumScaleFactor(0.5)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(isSelected ? Color.purple.opacity(0.15) : Color.clear)
                                        .foregroundColor(isSelected ? .purple : (colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8)))
                                        .cornerRadius(12)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color.purple : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)), lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.05 : 0.05), radius: 10, y: 5)
                    .padding(.horizontal, 20)
                }
                
                // БЛОК 3: МЫШЦЫ (Светофор)
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        sectionHeader(title: "3. Muscle Focus", icon: "figure.arms.open")
                        Spacer()
                    }
                    
                    Text("Tap muscle groups. One tap: focus (growth), two taps: exclude (injury).")
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? .gray : .secondary)
                        .padding(.horizontal, 20)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                        ForEach(viewModel.availableMuscles, id: \.self) { muscle in
                            muscleTriStateButton(muscle: muscle)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer(minLength: 120)
            }
        }
        // ПЛАВАЮЩАЯ КНОПКА ГЕНЕРАЦИИ
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await viewModel.generateProgram() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars").font(.title3)
                    Text("Generate Program").font(.headline).bold()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(themeManager.current.primaryGradient)
                .foregroundColor(.white)
                .clipShape(Capsule())
                .shadow(color: themeManager.current.deepPremiumAccent.opacity(0.4), radius: 15, x: 0, y: 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .background(
                LinearGradient(colors: [colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground), .clear], startPoint: .bottom, endPoint: .top)
                    .frame(height: 100)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            )
        }
    }
    
    // Вспомогательный заголовок секции
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(themeManager.current.primaryAccent)
            Text(title).font(.headline).foregroundColor(colorScheme == .dark ? .white : .black)
        }
        .padding(.horizontal, 20)
    }
    
    // Карточка цели
    private struct GoalSelectionCard: View {
        let goal: ProgramGoal
        let isSelected: Bool
        let action: () -> Void
        @Environment(\.colorScheme) private var colorScheme
        @Environment(ThemeManager.self) private var themeManager
        
        var body: some View {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 12) {
                    ZStack {
                        Circle().fill(goal.color.opacity(isSelected ? 1.0 : 0.15)).frame(width: 40, height: 40)
                        Image(systemName: goal.icon).foregroundColor(isSelected ? .white : goal.color).font(.title3)
                    }
                    Text(LocalizedStringKey(goal.rawValue))
                        .font(.subheadline).bold()
                        .foregroundColor(isSelected ? (colorScheme == .dark ? .white : .black) : .gray)
                }
                .padding(16)
                .frame(width: 140, alignment: .leading)
                .background(isSelected ? goal.color.opacity(0.1) : (colorScheme == .dark ? themeManager.current.surface : Color.white))
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(isSelected ? goal.color : (colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05)), lineWidth: isSelected ? 2 : 1))
                .shadow(color: isSelected ? goal.color.opacity(0.2) : .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
        }
    }
    
    // Кнопка выбора мышц
    @ViewBuilder
    private func muscleTriStateButton(muscle: String) -> some View {
        let state = viewModel.muscleStates[muscle] ?? .neutral
        
        Button {
            let gen = UISelectionFeedbackGenerator()
            gen.selectionChanged()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.muscleStates[muscle]?.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                if state == .grow { Image(systemName: "arrow.up.right").font(.caption.bold()) }
                if state == .exclude { Image(systemName: "xmark").font(.caption.bold()) }
                Text(LocalizedStringKey(muscle))
                    .font(.subheadline)
                    .fontWeight(state != .neutral ? .bold : .medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(triStateBackground(state))
            .foregroundColor(triStateForeground(state))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(triStateBorder(state), lineWidth: 1.5))
            .shadow(color: state != .neutral ? triStateBorder(state).opacity(0.3) : .clear, radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 2. LOADING VIEW
    private var loadingView: some View {
        VStack(spacing: 30) {
            ZStack {
                Circle()
                    .fill(themeManager.current.primaryGradient)
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)
                    .modifier(PulsatingGlowEffect()) // Твой эффект из других экранов
                
                Image(systemName: "cpu")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 8) {
                Text("Анализирую данные...")
                    .font(.title2).bold()
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                Text("Подбираю оптимальные упражнения и балансирую объем под ваши цели.")
                    .font(.subheadline)
                    .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
    
    // MARK: - 3. RESULT VIEW
    private func resultView(dto: GeneratedProgramDTO) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                
                // Успех
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(themeManager.current.primaryGradient)
                        .shadow(color: themeManager.current.deepPremiumAccent.opacity(0.5), radius: 15, y: 5)
                    
                    Text(dto.title)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .multilineTextAlignment(.center)
                    
                    Text(dto.description)
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 30)
                
                // Дни расписания
                VStack(alignment: .leading, spacing: 16) {
                    Text("Расписание")
                        .font(.title3).bold()
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .padding(.horizontal, 24)
                    
                    VStack(spacing: 12) {
                        ForEach(Array(dto.schedule.enumerated()), id: \.element.dayName) { index, day in
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle().fill(themeManager.current.primaryAccent.opacity(0.15)).frame(width: 46, height: 46)
                                    Text("\(index + 1)").font(.system(size: 16, weight: .black, design: .rounded)).foregroundColor(themeManager.current.primaryAccent)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(day.dayName).font(.subheadline).bold().foregroundColor(themeManager.current.primaryAccent)
                                    Text(day.focus).font(.headline).foregroundColor(colorScheme == .dark ? .white : .black)
                                }
                                Spacer()
                                Text("\(day.exercises.count) exercises")
                                    .font(.caption).bold()
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color(UIColor.systemGray6))
                                    .foregroundColor(colorScheme == .dark ? .white : .gray)
                                    .clipShape(Capsule())
                            }
                            .padding(16)
                            .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
                            .cornerRadius(20)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05), lineWidth: 1))
                            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 8, y: 4)
                            .padding(.horizontal, 20)
                        }
                    }
                }
                
                Spacer(minLength: 120)
            }
            .padding(.vertical)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                Task {
                    await viewModel.saveProgram(presetService: presetService, dto: dto)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    dismiss()
                }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.down.fill").font(.title3)
                        Text("Save to My Programs").font(.headline).bold()
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(viewModel.isSaving ? Color.gray : themeManager.current.primaryAccent)
                .clipShape(Capsule())
                .shadow(color: viewModel.isSaving ? .clear : themeManager.current.primaryAccent.opacity(0.4), radius: 15, x: 0, y: 8)
            }
            .disabled(viewModel.isSaving)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .background(
                LinearGradient(colors: [colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground), .clear], startPoint: .bottom, endPoint: .top)
                    .frame(height: 100)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            )
        }
    }
    
    // MARK: - Helpers
    private func triStateBackground(_ state: MuscleTargetState) -> Color {
        switch state {
        case .neutral: return colorScheme == .dark ? themeManager.current.surface : Color.white
        case .grow: return Color.green.opacity(0.15) // Акцент на рост
        case .exclude: return Color.red.opacity(0.15) // Исключить
        }
    }
    private func triStateForeground(_ state: MuscleTargetState) -> Color {
        switch state {
        case .neutral: return colorScheme == .dark ? .white : .black
        case .grow: return .green
        case .exclude: return .red
        }
    }
    private func triStateBorder(_ state: MuscleTargetState) -> Color {
        switch state {
        case .neutral: return colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05)
        case .grow: return .green
        case .exclude: return .red
        }
    }
}
// MARK: - Helper Extensions & Models

extension AIBuilderState {
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

public struct GeneratedProgramDTO: Codable, Sendable {
    let title: String
    let description: String
    let durationWeeks: Int
    let schedule: [GeneratedRoutineDTO]
}

public struct GeneratedRoutineDTO: Codable, Sendable {
    let dayName: String
    let focus: String
    let exercises: [GeneratedExerciseDTO]
}
