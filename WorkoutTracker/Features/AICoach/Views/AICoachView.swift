// ============================================================
// FILE: WorkoutTracker/ai_agent/AICoachView.swift
// ============================================================
internal import SwiftUI
import SwiftData

struct AICoachView: View {
    @Environment(DIContainer.self) private var di
    @Environment(AICoachViewModel.self) private var viewModel
    @Environment(ThemeManager.self) private var themeManager // <--- ДОБАВЛЕНО
    
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
    
    private let quickActions: [String] = ["Workout", "Progress", "Rest"]
    
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
            .navigationTitle(viewModel.currentSession?.title ?? "AI Coach")
            .navigationDestination(item: $navigateToWorkout) { workout in
                WorkoutDetailView(workout: workout, viewModel: di.makeWorkoutDetailViewModel())
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showHistorySheet = true } label: { Image(systemName: "clock.arrow.circlepath").foregroundColor(themeManager.current.primaryText) }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.easeInOut) { viewModel.clearChat() }
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    } label: { Image(systemName: "square.and.pencil").foregroundColor(themeManager.current.primaryText) }
                    Button {
                        showAISettings = true
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    } label: { Image(systemName: "slider.horizontal.3").foregroundColor(themeManager.current.primaryText) }
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
                        Section(header: Text("Communication Style"), footer: Text("The selected tone will be used in all AI coach responses.")) {
                            Picker("Tone", selection: $aiCoachTone) {
                                Text("Motivational").tag("Motivational")
                                Text("Strict ").tag("Strict")
                                Text("Friendly").tag("Friendly")
                                Text("Scientific").tag("Scientific")
                            }.pickerStyle(.menu)
                        }
                    }
                    .navigationTitle("AI Settings").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showAISettings = false } } }
                }.presentationDetents([.medium])
            }
            .sheet(isPresented: $showSmartBuilder) {
                SmartWorkoutBuilderSheet { generatedPrompt in
                    Task { await viewModel.sendMessage(userWeight: userBodyWeight, uiText: "Create a plan based on my parameters", aiPrompt: generatedPrompt) }
                }
            }
            .sheet(isPresented: $showProgressSheet) {
                ProgressAnalysisSheet { generatedPrompt in
                    Task { await viewModel.sendMessage(userWeight: userBodyWeight, uiText: "Rate my Progress", aiPrompt: generatedPrompt) }
                }
            }
            .sheet(isPresented: $showRecoverySheet) {
                RecoveryAdvisorSheet { generatedPrompt in
                    Task { await viewModel.sendMessage(userWeight: userBodyWeight, uiText: "What do you recommend doing?", aiPrompt: generatedPrompt) }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
          VStack(spacing: 16) {
              ZStack {
                  Circle()
                      .fill(themeManager.current.primaryAccent.opacity(0.1)) // <--- ИЗМЕНЕНО
                      .frame(width: 80, height: 80)
                  Image(systemName: "brain.head.profile")
                      .font(.system(size: 40))
                      .foregroundColor(themeManager.current.primaryAccent) // <--- ИЗМЕНЕНО
              }
              Text("Ready to help").font(.title2).bold().foregroundColor(themeManager.current.primaryText)
              Text("Ask a fitness question or request a workout plan.").font(.subheadline).foregroundColor(themeManager.current.secondaryText).multilineTextAlignment(.center).padding(.horizontal, 32)
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
                        if action == "Workout" { showSmartBuilder = true } else if action == "Progress" { showProgressSheet = true } else if action == "Rest" { showRecoverySheet = true }
                    }) { Text(action).font(.caption).fontWeight(.medium).lineLimit(1).minimumScaleFactor(0.8).padding(.horizontal, 6).padding(.vertical, 10).frame(maxWidth: .infinity).background(themeManager.current.background).foregroundColor(themeManager.current.primaryText).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.3), lineWidth: 1)) }
                }
            }.padding(.horizontal, 12).padding(.bottom, 12).disabled(vm.isGenerating).opacity(vm.isGenerating ? 0.5 : 1.0)
            Divider().background(Color.gray.opacity(0.3))
            HStack(alignment: .bottom, spacing: 12) {
                
                TextField("Ask AI Coach...", text: Binding(
                    get: { vm.inputText },
                    set: { vm.inputText = $0 }
                ), axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(themeManager.current.surface)
                    .cornerRadius(20)
                    .focused($isInputFocused)
                    .disabled(vm.isGenerating)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                
                if vm.isGenerating { ProgressView().frame(width: 34, height: 34).padding(.trailing, 4) } else {
                    Button {
                        isInputFocused = false
                        Task { await vm.sendMessage(userWeight: userBodyWeight) }
                    } label: { Image(systemName: "arrow.up.circle.fill").font(.system(size: 34)) .foregroundColor(isSendDisabled ? .gray.opacity(0.5) : themeManager.current.primaryAccent)  }.disabled(isSendDisabled)
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
    @Environment(ThemeManager.self) private var themeManager // <--- ДОБАВЛЕНО
    
    @State private var sessions: [AIChatSession] = []
    
    let onSelect: (AIChatSession) -> Void
    
    enum SessionGroup: String, CaseIterable, Identifiable {
        case today = "Today"
        case yesterday = "Yesterday"
        case previous = "Last 7 days"
        case older = "Older"
        var id: String { self.rawValue }
    }
    
    @State private var expandedSections: [String: Bool] = [
        "Today": false, "Yesterday": false, "Last 7 days": false, "Older": false
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
                            .foregroundStyle(themeManager.current.premiumGradient) // <--- ИЗМЕНЕНО
                        Text("Chat history is empty.")
                            .font(.title2).bold()
                            .foregroundColor(themeManager.current.primaryText)
                        Text("Your previous conversations with the AI coach will appear here.")
                            .font(.subheadline)
                            .foregroundColor(themeManager.current.secondaryText)
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
                                                .foregroundColor(themeManager.current.primaryText)
                                                .lineLimit(1)
                                            
                                            Text(session.date, style: .time)
                                                .font(.caption)
                                                .foregroundColor(themeManager.current.secondaryText)
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
                                    .foregroundColor(themeManager.current.primaryText)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Chat History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
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
