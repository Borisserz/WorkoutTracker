//
//  AICoachView.swift
//  WorkoutTracker
//

internal import SwiftUI
import SwiftData

struct AICoachView: View {
    @EnvironmentObject var workoutViewModel: WorkoutViewModel
    @Environment(\.modelContext) private var modelContext
    @AppStorage("userBodyWeight") private var userBodyWeight = 75.0
    
    @StateObject private var viewModel = AICoachViewModel()
    @FocusState private var isInputFocused: Bool
    
    // Для навигации в новую тренировку
    @State private var navigateToWorkout: Workout?
    
    // Выносим сложную логику проверки из верстки
    private var isSendDisabled: Bool {
        let textIsEmpty = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return textIsEmpty || viewModel.isGenerating
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                chatScrollView
                
                inputArea
            }
            .navigationTitle(LocalizedStringKey("AI Coach"))
            .navigationBarTitleDisplayMode(.inline)
            // Переход на экран тренировки
            .navigationDestination(item: $navigateToWorkout) { workout in
                WorkoutDetailView(workout: workout)
            }
        }
    }
    
    // 1. Оставляем здесь только логику скролла и модификаторы
    private var chatScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                chatContent // Вставляем вынесенный контент
            }
            // ИСПОЛЬЗУЕМ СИНТАКСИС iOS 17+ ДЛЯ ВСЕХ onChange (_, _)
            .onChange(of: viewModel.chatHistory) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isGenerating) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: isInputFocused) { _, focused in
                if focused {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        scrollToBottom(proxy: proxy)
                    }
                }
            }
            .onTapGesture { isInputFocused = false }
        }
    }
    
    // 3. Выносим внутреннее содержимое в отдельную View-переменную
    private var chatContent: some View {
        VStack(spacing: 16) {
            ForEach(viewModel.chatHistory) { message in
                // ИСПРАВЛЕНИЕ ЗДЕСЬ: Явно указываем onAcceptWorkout
                ChatMessageView(message: message, onAcceptWorkout: { dto in
                    viewModel.acceptWorkout(dto: dto, container: modelContext.container) { workout in
                        self.navigateToWorkout = workout
                    }
                })
                .id(message.id)
            }
            
            if viewModel.isGenerating {
                AILoadingIndicator()
                    .id("loading_indicator")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
            
            Color.clear.frame(height: 100).id("bottom_spacer")
        }
        .padding(.horizontal)
        .padding(.top, 20)
    }
    
    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider().background(Color.gray.opacity(0.3))
            
            HStack(alignment: .bottom, spacing: 12) {
                TextField(LocalizedStringKey("Ask AI Coach..."), text: $viewModel.inputText, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(20)
                    .focused($isInputFocused)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                
                Button {
                    viewModel.sendMessage(workoutViewModel: workoutViewModel, userWeight: userBodyWeight)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundColor(isSendDisabled ? .gray.opacity(0.5) : .accentColor)
                }
                .disabled(isSendDisabled)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo("bottom_spacer", anchor: .bottom)
        }
    }
}
