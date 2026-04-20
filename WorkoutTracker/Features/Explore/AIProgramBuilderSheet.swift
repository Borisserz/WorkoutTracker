// ============================================================
// FILE: WorkoutTracker/Features/Explore/AIProgramBuilderSheet.swift
// ============================================================

internal import SwiftUI

struct AIProgramBuilderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DIContainer.self) private var di
    @Environment(PresetService.self) private var presetService
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme // 👈 ДОБАВЛЕНО
    
    @State private var viewModel: AIProgramBuilderViewModel
    
    init(aiLogicService: AILogicService) {
        _viewModel = State(initialValue: AIProgramBuilderViewModel(aiLogicService: aiLogicService))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 👈 АДАПТАЦИЯ ФОНА (Серый в светлой теме)
                (colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color(UIColor.secondarySystemBackground)).ignoresSafeArea()
                
                switch viewModel.state {
                case .idle, .error:
                    configuratorView
                case .loading:
                    loadingView
                case .success(let dto):
                    resultView(dto: dto)
                }
            }
            .navigationTitle("ИИ архитектор")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
                        .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(viewModel.state.isLoading || viewModel.isSaving)
    }
    
    // MARK: - 1. Configurator View
    private var configuratorView: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                if case .error(let msg) = viewModel.state {
                    Text("Error: \(msg)")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                }
                
                // Physique Goal
                VStack(alignment: .leading, spacing: 12) {
                    Text("Цель телосложения").font(.headline).foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                    Picker("Goal", selection: $viewModel.goal) {
                        ForEach(ProgramGoal.allCases) { goal in
                            Text(LocalizedStringKey(goal.rawValue)).tag(goal)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)
                
                // Customization (Experience, Equipment, Schedule)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Настройка").font(.headline).foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                    
                    VStack(spacing: 0) {
                        Picker("Уровень", selection: $viewModel.level) {
                            ForEach(ProgramLevel.allCases) { lvl in Text(LocalizedStringKey(lvl.rawValue)).tag(lvl) }
                        }
                        .pickerStyle(.menu)
                        .tint(.blue)
                        .padding()
                        
                        Divider().padding(.leading)
                        
                        Picker("Оборудование", selection: $viewModel.equipment) {
                            ForEach(ProgramEquipment.allCases) { eq in Text(LocalizedStringKey(eq.rawValue)).tag(eq) }
                        }
                        .pickerStyle(.menu)
                        .tint(.blue)
                        .padding()
                        
                        Divider().padding(.leading)
                        
                        Stepper(value: $viewModel.daysPerWeek, in: 2...6) {
                            Text("Расписание: \(viewModel.daysPerWeek) дней/неделю")
                        }
                        .padding()
                    }
                    // 👈 АДАПТАЦИЯ КАРТОЧКИ
                    .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.05 : 0.05), radius: 5, x: 0, y: 2)
                }
                .padding(.horizontal)
                
                // Target Areas (Tri-state)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Целевые зоны").font(.headline).foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                        Spacer()
                        Text("Нажмите, чтобы переключить:\nУвеличение / Исключить").font(.caption2).foregroundColor(.purple).multilineTextAlignment(.trailing)
                    }
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                        ForEach(viewModel.availableMuscles, id: \.self) { muscle in
                            muscleTriStateButton(muscle: muscle)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 100)
            }
            .padding(.vertical)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await viewModel.generateProgram() }
            } label: {
                HStack {
                    Image(systemName: "wand.and.stars")
                    Text("Сгенерировать программу").bold()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                .foregroundColor(.white)
                .cornerRadius(16)
                .shadow(color: .purple.opacity(0.4), radius: 10, x: 0, y: 5)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
            .background(
                LinearGradient(colors: [colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color(UIColor.secondarySystemBackground), Color.clear], startPoint: .bottom, endPoint: .top).ignoresSafeArea()
            )
        }
    }
    
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
                if state == .grow { Image(systemName: "flame.fill") }
                if state == .exclude { Image(systemName: "xmark.circle.fill") }
                Text(LocalizedStringKey(muscle)).font(.subheadline).fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            // 👈 АДАПТАЦИЯ КНОПОК МЫШЦ
            .background(triStateBackground(state))
            .foregroundColor(triStateForeground(state))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(triStateBorder(state), lineWidth: 1))
            .shadow(color: state != .neutral ? triStateBorder(state).opacity(0.3) : .clear, radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 2. Loading View
    private var loadingView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 80, height: 80)
                    .modifier(PulsatingEffect())
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }
            Text("Архитектор создает ваш план...")
                .font(.headline)
                .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                .modifier(BlinkingTextModifier())
        }
    }
    
    // MARK: - 3. Result View
    private func resultView(dto: GeneratedProgramDTO) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                    
                    Text(dto.title)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .multilineTextAlignment(.center)
                    
                    Text(dto.description)
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Расписание").font(.headline).foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray).padding(.horizontal)
                    
                    ForEach(dto.schedule, id: \.dayName) { day in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(day.dayName).font(.subheadline).bold().foregroundColor(.blue)
                                Text(day.focus).font(.headline).foregroundColor(colorScheme == .dark ? .white : .black)
                            }
                            Spacer()
                            Text("\(day.exercises.count) упр.")
                                .font(.caption)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Color.blue.opacity(0.15))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                        }
                        .padding()
                        .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.03), radius: 5, y: 2)
                        .padding(.horizontal)
                    }
                }
                
                Spacer(minLength: 100)
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
                HStack {
                    if viewModel.isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.down.fill")
                        Text("Сохранить в мои программы").bold()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(viewModel.isSaving ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(16)
                .shadow(color: .blue.opacity(0.4), radius: 10, x: 0, y: 5)
            }
            .disabled(viewModel.isSaving)
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
            .background(Color(colorScheme == .dark ? UIColor.systemGroupedBackground : UIColor.secondarySystemBackground).shadow(radius: 5, y: -5))
        }
    }
    
    // MARK: - Helpers
    private func triStateBackground(_ state: MuscleTargetState) -> Color {
        switch state {
        case .neutral: return colorScheme == .dark ? themeManager.current.surface : Color.white // 👈
        case .grow: return Color.blue.opacity(0.15)
        case .exclude: return Color.red.opacity(0.15)
        }
    }
    private func triStateForeground(_ state: MuscleTargetState) -> Color {
        switch state {
        case .neutral: return colorScheme == .dark ? .white : .black // 👈
        case .grow: return .blue
        case .exclude: return .red
        }
    }
    private func triStateBorder(_ state: MuscleTargetState) -> Color {
        switch state {
        case .neutral: return colorScheme == .dark ? Color.gray.opacity(0.2) : Color.black.opacity(0.1) // 👈
        case .grow: return .blue
        case .exclude: return .red
        }
    }
}
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
