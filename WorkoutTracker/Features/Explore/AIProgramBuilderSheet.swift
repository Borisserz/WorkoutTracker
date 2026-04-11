// ============================================================
// FILE: WorkoutTracker/Features/Explore/AIProgramBuilderSheet.swift
// ============================================================

internal import SwiftUI

struct AIProgramBuilderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DIContainer.self) private var di
    @Environment(PresetService.self) private var presetService
    @Environment(ThemeManager.self) private var themeManager // <--- ДОБАВЛЕНО: Инъекция темы
    
    @State private var viewModel: AIProgramBuilderViewModel
    
    init(aiLogicService: AILogicService) {
        _viewModel = State(initialValue: AIProgramBuilderViewModel(aiLogicService: aiLogicService))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                switch viewModel.state {
                case .idle, .error:
                    configuratorView
                case .loading:
                    loadingView
                case .success(let dto):
                    resultView(dto: dto)
                }
            }
            .navigationTitle("AI Architect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundColor(themeManager.current.secondaryText)
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
                        .foregroundColor(.red) // Семантический красный, оставляем
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                }
                
                // Physique Goal
                VStack(alignment: .leading, spacing: 12) {
                    Text("Physique Goal").font(.headline).foregroundColor(themeManager.current.secondaryText)
                    Picker("Goal", selection: $viewModel.goal) {
                        ForEach(ProgramGoal.allCases) { goal in
                            Text(goal.rawValue).tag(goal)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)
                
                // Customization (Experience, Equipment, Schedule)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Customization").font(.headline).foregroundColor(themeManager.current.secondaryText)
                    
                    VStack(spacing: 0) {
                        Picker("Experience", selection: $viewModel.level) {
                            ForEach(ProgramLevel.allCases) { lvl in Text(lvl.rawValue).tag(lvl) }
                        }
                        .pickerStyle(.menu)
                        .padding()
                        
                        Divider().padding(.leading)
                        
                        Picker("Equipment", selection: $viewModel.equipment) {
                            ForEach(ProgramEquipment.allCases) { eq in Text(eq.rawValue).tag(eq) }
                        }
                        .pickerStyle(.menu)
                        .padding()
                        
                        Divider().padding(.leading)
                        
                        Stepper(value: $viewModel.daysPerWeek, in: 2...6) {
                            Text("Schedule: \(viewModel.daysPerWeek) Days/Week")
                        }
                        .padding()
                    }
                    .background(themeManager.current.surface)
                    .cornerRadius(16)
                }
                .padding(.horizontal)
                
                // Target Areas (Tri-state)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Target Areas").font(.headline).foregroundColor(themeManager.current.secondaryText)
                        Spacer()
                        Text("Tap to cycle: Grow / Exclude").font(.caption2).foregroundColor(themeManager.current.secondaryAccent)
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
                    Text("Generate Program").bold()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(themeManager.current.premiumGradient) // <--- ИЗМЕНЕНО: [purple, cyan] -> премиальный градиент темы
                .foregroundColor(themeManager.current.background)
                .cornerRadius(16)
                .shadow(color: themeManager.current.deepPremiumAccent.opacity(0.4), radius: 10, x: 0, y: 5) // <--- ИЗМЕНЕНО
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
            .background(Color(UIColor.systemGroupedBackground).shadow(radius: 5, y: -5))
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
                Text(muscle).font(.subheadline).fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(triStateBackground(state))
            .foregroundColor(triStateForeground(state))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(triStateBorder(state), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 2. Loading View
    private var loadingView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(themeManager.current.premiumGradient) // <--- ИЗМЕНЕНО
                    .frame(width: 80, height: 80)
                    .modifier(PulsatingEffect())
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 40))
                    .foregroundColor(themeManager.current.background)
            }
            Text("Architecting your plan...")
                .font(.headline)
                .foregroundStyle(themeManager.current.premiumGradient) // <--- ИЗМЕНЕНО
                .modifier(BlinkingTextModifier())
        }
    }
    
    // MARK: - 3. Result View
    private func resultView(dto: GeneratedProgramDTO) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Card
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(themeManager.current.premiumGradient) // <--- ИЗМЕНЕНО
                    
                    Text(dto.title)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.center)
                    
                    Text(dto.description)
                        .font(.subheadline)
                        .foregroundColor(themeManager.current.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(themeManager.current.surface)
                .cornerRadius(20)
                .padding(.horizontal)
                
                // Days List
                VStack(alignment: .leading, spacing: 16) {
                    Text("Schedule").font(.headline).foregroundColor(themeManager.current.secondaryText).padding(.horizontal)
                    
                    ForEach(dto.schedule, id: \.dayName) { day in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(day.dayName).font(.subheadline).bold().foregroundColor(themeManager.current.deepPremiumAccent) // <--- ИЗМЕНЕНО: purple -> тема
                                Text(day.focus).font(.headline)
                            }
                            Spacer()
                            Text("\(day.exercises.count) Exs")
                                .font(.caption)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(themeManager.current.primaryAccent.opacity(0.15)) // <--- ИЗМЕНЕНО: cyan -> тема
                                .foregroundColor(themeManager.current.primaryAccent) // <--- ИЗМЕНЕНО: cyan -> тема
                                .clipShape(Capsule())
                        }
                        .padding()
                        .background(themeManager.current.surface)
                        .cornerRadius(12)
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
                        Text("Save to My Routines").bold()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(viewModel.isSaving ? Color.gray : themeManager.current.primaryAccent) // <--- ИЗМЕНЕНО: .blue -> тема
                .foregroundColor(themeManager.current.background)
                .cornerRadius(16)
                .shadow(color: themeManager.current.primaryAccent.opacity(0.4), radius: 10, x: 0, y: 5) // <--- ИЗМЕНЕНО
            }
            .disabled(viewModel.isSaving)
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
            .background(Color(UIColor.systemGroupedBackground).shadow(radius: 5, y: -5))
        }
    }
    
    // MARK: - Helpers
    private func triStateBackground(_ state: MuscleTargetState) -> Color {
        switch state {
        case .neutral: return themeManager.current.surface
        case .grow: return themeManager.current.primaryAccent.opacity(0.15) // <--- ИЗМЕНЕНО
        case .exclude: return Color.red.opacity(0.15) // Семантика, оставляем
        }
    }
    private func triStateForeground(_ state: MuscleTargetState) -> Color {
        switch state {
        case .neutral: return .primary
        case .grow: return themeManager.current.primaryAccent // <--- ИЗМЕНЕНО
        case .exclude: return .red // Семантика, оставляем
        }
    }
    private func triStateBorder(_ state: MuscleTargetState) -> Color {
        switch state {
        case .neutral: return Color.gray.opacity(0.2)
        case .grow: return themeManager.current.primaryAccent // <--- ИЗМЕНЕНО
        case .exclude: return .red // Семантика, оставляем
        }
    }
}

extension AIBuilderState {
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}
