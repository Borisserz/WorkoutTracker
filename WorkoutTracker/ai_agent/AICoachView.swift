// ============================================================
// FILE: WorkoutTracker/ai_agent/AICoachView.swift
// ============================================================
internal import SwiftUI
import SwiftData

struct AICoachView: View {
    @Environment(DIContainer.self) private var di
    
    // ✅ ПОЛУЧАЕМ ГОТОВУЮ ВЬЮМОДЕЛЬ БЕЗ ОПЦИОНАЛОВ И ЗАГРУЗОК
    @Environment(AICoachViewModel.self) private var viewModel
    
    @AppStorage(Constants.UserDefaultsKeys.userBodyWeight.rawValue) private var userBodyWeight = 75.0
    @AppStorage(Constants.UserDefaultsKeys.aiCoachTone.rawValue) private var aiCoachTone = Constants.AIConstants.defaultTone
    
    @FocusState private var isInputFocused: Bool
    
    @State private var navigateToWorkout: Workout?
    @State private var showHistorySheet = false
    @State private var showSmartBuilder = false
    @State private var showAISettings = false
    @State private var showProgressSheet = false
    @State private var showRecoverySheet = false
    
    private var isSendDisabled: Bool {
        let textIsEmpty = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return textIsEmpty || viewModel.isGenerating
    }
    
    private let quickActions: [String] = ["Тренировка", "Прогресс", "Отдых"]
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                // Сразу рисуем UI!
                if viewModel.chatHistory.isEmpty {
                    emptyStateView
                } else {
                    chatScrollView(viewModel: viewModel)
                }
                
                inputArea(viewModel: viewModel)
            }
            .navigationTitle(viewModel.currentSession?.title ?? "AI Тренер")
            .navigationDestination(item: $navigateToWorkout) { workout in
                WorkoutDetailView(workout: workout, viewModel: di.makeWorkoutDetailViewModel())
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showHistorySheet = true } label: { Image(systemName: "clock.arrow.circlepath").foregroundColor(.primary) }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.easeInOut) { viewModel.clearChat() }
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    } label: { Image(systemName: "square.and.pencil").foregroundColor(.primary) }
                    Button {
                        showAISettings = true
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    } label: { Image(systemName: "slider.horizontal.3").foregroundColor(.primary) }
                }
            }
            .sheet(isPresented: $showHistorySheet) {
                ChatHistorySheetView(userRepository: di.userRepository) { selectedSession in
                    withAnimation { viewModel.loadSession(selectedSession) }
                }
            }
            .sheet(isPresented: $showAISettings) {
                NavigationStack {
                    Form {
                        Section(header: Text("Стиль общения"), footer: Text("Выбранный тон будет использоваться во всех ответах ИИ-тренера.")) {
                            Picker("Тон общения", selection: $aiCoachTone) {
                                Text("Мотивационный").tag("Мотивационный")
                                Text("Строгий (Армейский)").tag("Строгий")
                                Text("Дружелюбный").tag("Дружелюбный")
                                Text("Научный / Сухой").tag("Научный")
                            }.pickerStyle(.menu)
                        }
                    }
                    .navigationTitle("Настройки ИИ").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { showAISettings = false } } }
                }.presentationDetents([.medium])
            }
            .sheet(isPresented: $showSmartBuilder) {
                SmartWorkoutBuilderSheet { generatedPrompt in
                    Task { await viewModel.sendMessage(userWeight: userBodyWeight, uiText: "Составь план по моим параметрам", aiPrompt: generatedPrompt) }
                }
            }
            .sheet(isPresented: $showProgressSheet) {
                ProgressAnalysisSheet { generatedPrompt in
                    Task { await viewModel.sendMessage(userWeight: userBodyWeight, uiText: "Оцени мой прогресс", aiPrompt: generatedPrompt) }
                }
            }
            .sheet(isPresented: $showRecoverySheet) {
                RecoveryAdvisorSheet { generatedPrompt in
                    Task { await viewModel.sendMessage(userWeight: userBodyWeight, uiText: "Что рекомендуешь сделать?", aiPrompt: generatedPrompt) }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            ZStack { Circle().fill(Color.blue.opacity(0.1)).frame(width: 80, height: 80); Image(systemName: "brain.head.profile").font(.system(size: 40)).foregroundColor(.blue) }
            Text("Готов помочь").font(.title2).bold().foregroundColor(.primary)
            Text("Задай вопрос о фитнесе или попроси составить план тренировки.").font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal, 32)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(.bottom, 160)
    }
    
    private func chatScrollView(viewModel vm: AICoachViewModel) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(vm.chatHistory) { message in
                        ChatMessageView(message: message, onAcceptWorkout: { dto in
                            Task { await vm.acceptWorkout(dto: dto) { workout in self.navigateToWorkout = workout } }
                        }).id(message.id)
                    }
                    if vm.isGenerating { AILoadingIndicator().id("loading_indicator").frame(maxWidth: .infinity, alignment: .leading).transition(.opacity.combined(with: .scale(scale: 0.9))) }
                    Color.clear.frame(height: 140).id("bottom_spacer")
                }.padding(.horizontal).padding(.top, 20)
            }
            .onChange(of: vm.chatHistory) { _, _ in scrollToBottom(proxy: proxy) }
            .onChange(of: vm.isGenerating) { _, _ in scrollToBottom(proxy: proxy) }
            .onChange(of: isInputFocused) { _, focused in if focused { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { scrollToBottom(proxy: proxy) } } }
            .onTapGesture { isInputFocused = false }
        }
    }
    
    private func inputArea(viewModel vm: AICoachViewModel) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(quickActions, id: \.self) { action in
                    Button(action: {
                        isInputFocused = false
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        if action == "Тренировка" { showSmartBuilder = true } else if action == "Прогресс" { showProgressSheet = true } else if action == "Отдых" { showRecoverySheet = true }
                    }) { Text(action).font(.caption).fontWeight(.medium).lineLimit(1).minimumScaleFactor(0.8).padding(.horizontal, 6).padding(.vertical, 10).frame(maxWidth: .infinity).background(Color(UIColor.systemBackground)).foregroundColor(.primary).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.3), lineWidth: 1)) }
                }
            }.padding(.horizontal, 12).padding(.bottom, 12).disabled(vm.isGenerating).opacity(vm.isGenerating ? 0.5 : 1.0)
            Divider().background(Color.gray.opacity(0.3))
            HStack(alignment: .bottom, spacing: 12) {
                
                TextField("Спроси AI Тренера...", text: Binding(
                    get: { vm.inputText },
                    set: { vm.inputText = $0 }
                ), axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(20)
                    .focused($isInputFocused)
                    .disabled(vm.isGenerating)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                
                if vm.isGenerating { ProgressView().frame(width: 34, height: 34).padding(.trailing, 4) } else {
                    Button {
                        isInputFocused = false
                        Task { await vm.sendMessage(userWeight: userBodyWeight) }
                    } label: { Image(systemName: "arrow.up.circle.fill").font(.system(size: 34)).foregroundColor(isSendDisabled ? .gray.opacity(0.5) : .accentColor) }.disabled(isSendDisabled)
                }
            }.padding(.horizontal).padding(.vertical, 12).background(.ultraThinMaterial)
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom_spacer", anchor: .bottom) } }
}

// MARK: - Chat History Sheet
struct ChatHistorySheetView: View {
    let userRepository: UserRepositoryProtocol
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var sessions: [AIChatSession] = []
    
    let onSelect: (AIChatSession) -> Void
    
    enum SessionGroup: String, CaseIterable, Identifiable {
        case today = "Сегодня"
        case yesterday = "Вчера"
        case previous = "Последние 7 дней"
        case older = "Старые"
        var id: String { self.rawValue }
    }
    
    @State private var expandedSections: [String: Bool] = [
        "Сегодня": false, "Вчера": false, "Последние 7 дней": false, "Старые": false
    ]
    
    private var groupedSessions: [(SessionGroup, [AIChatSession])] {
        var groups: [SessionGroup: [AIChatSession]] = [.today: [], .yesterday: [], .previous: [], .older: []]
        let calendar = Calendar.current
        let now = Date()
        
        for session in sessions {
            if calendar.isDateInToday(session.date) {
                groups[.today]?.append(session)
            } else if calendar.isDateInYesterday(session.date) {
                groups[.yesterday]?.append(session)
            } else if let days = calendar.dateComponents([.day], from: session.date, to: now).day, days <= 7 {
                groups[.previous]?.append(session)
            } else {
                groups[.older]?.append(session)
            }
        }
        
        return SessionGroup.allCases.compactMap { group in
            let items = groups[group] ?? []
            return items.isEmpty ? nil : (group, items)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if sessions.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        Text("История чатов пуста.")
                            .font(.title2).bold()
                            .foregroundColor(.primary)
                        Text("Ваши предыдущие переписки с ИИ-тренером будут отображаться здесь.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 80)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(groupedSessions, id: \.0.id) { group, groupSessions in
                        Section {
                            DisclosureGroup(
                                isExpanded: Binding(
                                    get: { expandedSections[group.rawValue] ?? false },
                                    set: { expandedSections[group.rawValue] = $0 }
                                )
                            ) {
                                ForEach(groupSessions) { session in
                                    Button {
                                        onSelect(session)
                                        dismiss()
                                    } label: {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(session.title)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            
                                            Text(session.date, style: .time)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                                .onDelete { offsets in
                                    Task { await deleteSessions(offsets: offsets, from: groupSessions) }
                                }
                            } label: {
                                Text(group.rawValue)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("История чатов")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .task { await fetchSessions() }
        }
    }
    
    private func fetchSessions() async {
        do {
            sessions = try await userRepository.fetchAIChatSessions()
        } catch {
            print("Error fetching chat sessions: \(error)")
        }
    }
    
    private func deleteSessions(offsets: IndexSet, from groupSessions: [AIChatSession]) async {
        withAnimation {
            for index in offsets {
                let sessionToDelete = groupSessions[index]
                Task {
                    try? await userRepository.deleteAIChatSession(sessionToDelete.persistentModelID)
                    await fetchSessions()
                }
            }
        }
    }
}
