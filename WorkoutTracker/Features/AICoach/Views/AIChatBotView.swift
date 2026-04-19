//
//  AIChatBotView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 18.04.26.
//

internal import SwiftUI
import SwiftData

struct AIChatBotView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Environment(DIContainer.self) private var di
    
    // Подключаем реальную ViewModel
    @Bindable var viewModel: AICoachViewModel
    @AppStorage(Constants.UserDefaultsKeys.userBodyWeight.rawValue) private var userBodyWeight = 75.0
    
    // Для автоскролла вниз
    @Namespace private var bottomID
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Фон из дизайна
                themeManager.current.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Зона сообщений
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
                                    AILoadingIndicator() // Твой индикатор из AICoachComponents
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
                    
                    // Зона ввода (твой дизайн)
                    HStack {
                        TextField("Напиши тренеру...", text: $viewModel.inputText)
                            .padding(14)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
                            .foregroundStyle(.white)
                            .onSubmit { sendMessage() }
                        
                        Button {
                            sendMessage()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(viewModel.inputText.isEmpty ? .gray : themeManager.current.primaryAccent)
                                .shadow(color: viewModel.inputText.isEmpty ? .clear : themeManager.current.primaryAccent.opacity(0.8), radius: 8)
                        }
                        .disabled(viewModel.inputText.isEmpty || viewModel.isGenerating)
                    }
                    .padding()
                    .background(themeManager.current.background.opacity(0.8)) // Защита от наезжания текста
                }
            }
            .navigationTitle("ИИ Тренер")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
                        .foregroundStyle(themeManager.current.primaryAccent)
                        .fontWeight(.bold)
                }
                
                // Опционально: кнопка очистки чата
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        let gen = UIImpactFeedbackGenerator(style: .rigid)
                        gen.impactOccurred()
                        viewModel.clearChat()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .disabled(viewModel.isGenerating || viewModel.chatHistory.isEmpty)
                }
            }
            .onAppear {
                // Если чат открыли с уже вбитым текстом (например из поиска главного меню)
                if !viewModel.inputText.isEmpty {
                    sendMessage()
                }
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
                        // Логика принятия тренировки
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
    
    private func sendMessage() {
        guard !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        Task {
            // Вызываем РЕАЛЬНУЮ функцию твоего ИИ из ViewModel
            await viewModel.sendMessage(userWeight: userBodyWeight)
        }
    }
}
