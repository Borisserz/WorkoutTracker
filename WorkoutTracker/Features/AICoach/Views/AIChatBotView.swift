//
//  AIChatBotView.swift
//  WorkoutTracker
//

internal import SwiftUI
import SwiftData

struct AIChatBotView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Environment(DIContainer.self) private var di
    @Environment(\.colorScheme) private var colorScheme
    
    // Подключаем реальную ViewModel
    @Bindable var viewModel: AICoachViewModel
    @AppStorage(Constants.UserDefaultsKeys.userBodyWeight.rawValue) private var userBodyWeight = 75.0
    
    // Голосовой ввод
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var isPulsingMic = false
    
    // История
    @State private var showHistorySheet = false
    
    // Для автоскролла вниз
    @Namespace private var bottomID
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Фон из дизайна
                themeManager.current.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Зона messages
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 16) {
                                // Приветственное сообщение, если чат пустой
                                if viewModel.chatHistory.isEmpty {
                                    initialGreetingBubble
                                }
                                
                                // Реальные сообщения из БД/ViewModel
                                ForEach(viewModel.chatHistory) { msg in
                                    chatBubble(for: msg)
                                }
                                
                                // Индикатор загрузки ИИ
                                if viewModel.isGenerating {
                                    AILoadingIndicator()
                                        .padding(.horizontal)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                
                                // Якорь для скролла
                                Spacer().frame(height: 10).id(bottomID)
                            }
                            .padding(.top)
                        }
                        .onChange(of: viewModel.chatHistory.count) { _, _ in
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(bottomID, anchor: .bottom)
                            }
                        }
                        .onChange(of: viewModel.isGenerating) { _, isGen in
                            if isGen {
                                withAnimation { proxy.scrollTo(bottomID, anchor: .bottom) }
                            }
                        }
                    }
                    
                    // Зона ввода (Текст + Микрофон + Отправка)
                    HStack(spacing: 12) {
                        
                        // КНОПКА МИКРОФОНА
                        Button {
                            toggleDictation()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(speechRecognizer.isRecording ? Color.green.opacity(0.2) : Color.white.opacity(0.1))
                                    .frame(width: 44, height: 44)
                                
                                if speechRecognizer.isRecording {
                                    Circle()
                                        .stroke(Color.green, lineWidth: 2)
                                        .frame(width: 44, height: 44)
                                        .scaleEffect(isPulsingMic ? 1.1 : 0.9)
                                        .opacity(isPulsingMic ? 0 : 1)
                                }
                                
                                Image(systemName: speechRecognizer.isRecording ? "mic.fill" : "mic")
                                    .font(.system(size: 20))
                                    .foregroundColor(speechRecognizer.isRecording ? .green : .gray)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        // ТЕКСТОВОЕ ПОЛЕ
                        TextField("Ask coach...", text: $viewModel.inputText)
                            .padding(14)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().stroke(speechRecognizer.isRecording ? Color.green.opacity(0.5) : .white.opacity(0.2), lineWidth: 1))
                            .foregroundStyle(.white)
                            .onSubmit { sendMessage() }
                        
                        // КНОПКА ОТПРАВКИ
                        Button {
                            sendMessage()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 38))
                                .foregroundStyle(viewModel.inputText.isEmpty ? .gray : themeManager.current.primaryAccent)
                                .shadow(color: viewModel.inputText.isEmpty ? .clear : themeManager.current.primaryAccent.opacity(0.8), radius: 8)
                        }
                        .disabled(viewModel.inputText.isEmpty || viewModel.isGenerating)
                    }
                    .padding()
                    .background(themeManager.current.background.opacity(0.9)) // Защита от наезжания текста
                }
            }
            .navigationTitle("AI Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Close
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(themeManager.current.primaryAccent)
                        .fontWeight(.bold)
                }
                
                // 👈 ИСПРАВЛЕНИЕ: Кнопка ИСТОРИИ вместо корзины
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        let gen = UIImpactFeedbackGenerator(style: .medium)
                        gen.impactOccurred()
                        showHistorySheet = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .disabled(viewModel.isGenerating)
                }
            }
            .onAppear {
                speechRecognizer.requestPermission()
                if !viewModel.inputText.isEmpty {
                    sendMessage()
                }
            }
            // Синхронизация речи с текстовым полем
            .onChange(of: speechRecognizer.transcript) { _, newText in
                if speechRecognizer.isRecording {
                    viewModel.inputText = newText
                }
            }
            // Анимация пульсации микрофона
            .onChange(of: speechRecognizer.isRecording) { _, isRec in
                if isRec {
                    withAnimation(.easeOut(duration: 0.8).repeatForever(autoreverses: false)) {
                        isPulsingMic = true
                    }
                } else {
                    isPulsingMic = false
                }
            }
            .sheet(isPresented: $showHistorySheet) {
                AIChatHistorySheet(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
    
    // MARK: - Components
    
    private var initialGreetingBubble: some View {
        HStack {
            Text("Привет! Я твой ИИ-тренер. Помогу составить программу, проанализировать усталость или улучшить технику. Чем займемся сегодня?")
                .padding()
                .background(Color.white.opacity(0.1))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.2), lineWidth: 1))
            Spacer()
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func chatBubble(for msg: AIChatMessage) -> some View {
        HStack(alignment: .bottom) {
            if msg.isUser { Spacer(minLength: 40) }
            
            VStack(alignment: msg.isUser ? .trailing : .leading, spacing: 8) {
                // Текст сообщения
                Group {
                    if msg.isUser {
                        Text(msg.text)
                    } else {
                        // Эффект печатания для ИИ
                        TypewriterTextView(fullText: msg.text, isAnimating: msg.isAnimating)
                    }
                }
                .padding()
                // Цвета из дизайна, привязанные к твоей теме
                .background(msg.isUser ? themeManager.current.primaryAccent.opacity(0.8) : Color.white.opacity(0.1))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: msg.isUser ? themeManager.current.primaryAccent.opacity(0.5) : .black.opacity(0.2), radius: 5)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.2), lineWidth: msg.isUser ? 0 : 1))
                
                // Карточка тренировки (если ИИ сгенерировал программу)
                if let workout = msg.proposedWorkout {
                    ProposedWorkoutCardView(workout: workout) {
                        Task {
                            await viewModel.acceptWorkout(dto: workout) { newWorkout in
                                di.appState.returnToActiveWorkoutId = newWorkout.persistentModelID
                                di.appState.selectedTab = 2 // Переход на WorkoutHub
                                dismiss()
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            
            if !msg.isUser { Spacer(minLength: 40) }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Logic
    
    private func toggleDictation() {
        HapticManager.shared.selection()
        if speechRecognizer.isRecording {
            // Выключаем микрофон
            speechRecognizer.stopTranscribing()
            // Если наговорили текст, сразу отправляем запрос ИИ
            if !viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty {
                sendMessage()
            }
        } else {
            // Включаем микрофон
            speechRecognizer.startTranscribing()
        }
    }
    
    private func sendMessage() {
        if speechRecognizer.isRecording {
            speechRecognizer.stopTranscribing()
        }
        
        guard !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        Task {
            await viewModel.sendMessage(userWeight: userBodyWeight)
        }
    }
}

// MARK: - ЭКРАН ИСТОРИИ ЧАТОВ
struct AIChatHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    
    @Bindable var viewModel: AICoachViewModel
    
    // 👈 Получаем реальные чаты из базы
    @Query(sort: \AIChatSession.date, order: .reverse) private var sessions: [AIChatSession]
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Фон
                (colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground))
                    .ignoresSafeArea()
                
                if sessions.isEmpty {
                    EmptyStateView(
                        icon: "bubble.left.and.exclamationmark.bubble.right",
                        title: "No History",
                        message: "You haven't chatted with the coach yet. Start your first conversation!"
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(sessions) { session in
                            Button {
                                let gen = UISelectionFeedbackGenerator()
                                gen.selectionChanged()
                                viewModel.loadSession(session)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(session.title)
                                        .font(.headline)
                                        .foregroundColor(colorScheme == .dark ? .white : .black)
                                        .lineLimit(1)
                                    
                                    HStack {
                                        Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Spacer()
                                        Text("\(session.messages.count) messages")
                                            .font(.caption2)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(themeManager.current.primaryAccent.opacity(0.2))
                                            .foregroundColor(themeManager.current.primaryAccent)
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(colorScheme == .dark ? themeManager.current.surface : Color.white)
                        }
                        .onDelete(perform: deleteSessions)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .padding(.bottom, 80) // Место под кнопку
                }
                
                // Кнопка "Новый Чат"
                Button {
                    let gen = UINotificationFeedbackGenerator()
                    gen.notificationOccurred(.success)
                    viewModel.clearChat()
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "plus.bubble.fill")
                            .font(.title3)
                        Text("Start New Chat")
                            .font(.headline)
                            .bold()
                    }
                    .foregroundColor(themeManager.current.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(themeManager.current.primaryAccent)
                    .cornerRadius(16)
                    .shadow(color: themeManager.current.primaryAccent.opacity(0.4), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .navigationTitle("Chat History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.gray)
                }
            }
        }
    }
    
    private func deleteSessions(offsets: IndexSet) {
        for index in offsets {
            let sessionToDelete = sessions[index]
            // Если удаляем текущий открытый чат — очищаем экран
            if viewModel.currentSession?.id == sessionToDelete.id {
                viewModel.clearChat()
            }
            context.delete(sessionToDelete)
        }
        try? context.save()
    }
}
