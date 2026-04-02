internal import SwiftUI
import SwiftData

struct InWorkoutAICoachView: View {
    @Bindable var workout: Workout
    @Environment(CatalogViewModel.self) var catalogViewModel
    
    // ✅ ИСПРАВЛЕНИЕ: Используем @Bindable вместо @ObservedObject
    @Bindable var viewModel: InWorkoutAICoachViewModel
    
    @Environment(\.modelContext) private var context
    @Environment(WorkoutViewModel.self) var workoutViewModel
    
    @FocusState private var isInputFocused: Bool
    
    private var isSendDisabled: Bool {
        let textIsEmpty = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return textIsEmpty || viewModel.isGenerating
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Зона чата
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        if viewModel.chatHistory.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 40))
                                    .foregroundColor(.blue)
                                Text(workout.isActive ? "Я слежу за тренировкой." : "Тренировка завершена.")
                                    .font(.headline)
                                Text(workout.isActive ? "Напиши мне, если нужна корректировка веса или замена упражнения." : "Спроси меня про аналитику, объем или советы на будущее.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 60)
                        } else {
                            ForEach(viewModel.chatHistory) { message in
                                InWorkoutChatBubble(message: message, workout: workout)
                                    .id(message.id)
                            }
                        }
                        
                        if viewModel.isGenerating {
                            AILoadingIndicator()
                                .id("loading_indicator")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        Color.clear.frame(height: 20).id("bottom_spacer")
                    }
                    .padding(.vertical)
                }
                .onTapGesture { isInputFocused = false }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.chatHistory.count) { _, _ in scrollToBottom(proxy: proxy) }
                .onChange(of: isInputFocused) { _, focused in
                    if focused {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { scrollToBottom(proxy: proxy) }
                    }
                }
            }
            
            inputArea
        }
    }
    
    // MARK: - Input Area
    private var inputArea: some View {
        VStack(spacing: 0) {
            let quickActions = workout.isActive ? [
                "Замени следующее упражнение",
                "Тяжело, снизь веса",
                "Слишком легко",
                "Мало времени, сократи тренировку"
            ] : [
                "Оцени эту тренировку",
                "Какие мышцы отстают?",
                "Дай совет на следующий раз"
            ]
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickActions, id: \.self) { action in
                        Button {
                            isInputFocused = false
                            viewModel.inputText = action
                            viewModel.sendMessage(currentWorkout: workout, catalog: catalogViewModel.combinedCatalog)
                        } label: {
                            Text(LocalizedStringKey(action))
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(UIColor.systemBackground))
                                .foregroundColor(.primary)
                                .cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        }
                        .disabled(viewModel.isGenerating)
                        .opacity(viewModel.isGenerating ? 0.5 : 1.0)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 12)
            
            HStack(alignment: .bottom, spacing: 12) {
                TextField(LocalizedStringKey("Спроси тренера..."), text: $viewModel.inputText, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                    .focused($isInputFocused)
                    .disabled(viewModel.isGenerating)
                    .onSubmit {
                        isInputFocused = false
                        viewModel.sendMessage(currentWorkout: workout, catalog: catalogViewModel.combinedCatalog)
                    }
                
                if viewModel.isGenerating {
                    ProgressView().frame(width: 34, height: 34).padding(.trailing, 4)
                } else {
                    Button {
                        isInputFocused = false
                        viewModel.sendMessage(currentWorkout: workout, catalog: catalogViewModel.combinedCatalog)
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 34))
                            .foregroundColor(isSendDisabled ? .gray.opacity(0.5) : .accentColor)
                    }
                    .disabled(isSendDisabled)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground).shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: -5))
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom_spacer", anchor: .bottom) }
    }
}

// MARK: - Bubble & Card
struct InWorkoutChatBubble: View {
    let message: InWorkoutChatMessage
    @Bindable var workout: Workout
    
    var body: some View {
        HStack(alignment: .bottom) {
            if message.isUser { Spacer(minLength: 40) }
            else {
                ZStack {
                    Circle().fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 32, height: 32)
                    Image(systemName: "brain.head.profile").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                }
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                Text(LocalizedStringKey(message.text))
                    .font(.body)
                    .foregroundColor(message.isUser ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(message.isUser ? Color.accentColor : Color(UIColor.secondarySystemBackground))
                    .clipShape(ChatBubbleShape(isUser: message.isUser))
                
                if let adjustment = message.adjustment, workout.isActive {
                    WorkoutAdjustmentCardView(adjustment: adjustment, workout: workout)
                        .padding(.top, 4)
                }
            }
            
            if !message.isUser { Spacer(minLength: 40) }
        }
    }
}

struct WorkoutAdjustmentCardView: View {
    let adjustment: InWorkoutResponseDTO
    @Bindable var workout: Workout
    
    @State private var isApplied = false
    @Environment(\.modelContext) private var context
    @Environment(WorkoutViewModel.self) var workoutViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wand.and.stars").foregroundColor(.yellow)
                Text(LocalizedStringKey("AI Suggestion")).font(.headline).foregroundColor(.white)
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let target = adjustment.targetExerciseName {
                        Text(target).font(.subheadline).fontWeight(.semibold).foregroundColor(.white)
                    }
                    Text(actionDescription).font(.caption).foregroundColor(.white.opacity(0.7))
                }
                Spacer()
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            
            Button {
                applyChanges()
            } label: {
                HStack {
                    Image(systemName: isApplied ? "checkmark" : "bolt.fill")
                    Text(isApplied ? LocalizedStringKey("Applied") : LocalizedStringKey("Apply Changes")).bold()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isApplied ? Color.green.opacity(0.8) : Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isApplied || !workout.isActive)
        }
        .padding()
        .background(.ultraThinMaterial).environment(\.colorScheme, .dark)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.2), lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        .frame(maxWidth: 320)
    }
    
    // ✅ ИСПРАВЛЕНИЕ: Используем Enum вместо строковых значений
    private var actionDescription: String {
        switch adjustment.actionType {
        case .dropWeight:
            return "Снизить вес на \(Int(adjustment.valuePercentage ?? 0))%"
        case .reduceRemainingLoad:
            return "Снизить оставшиеся веса на \(Int(adjustment.valuePercentage ?? 0))%"
        case .addSet:
            return "Добавить добивочный подход: \(adjustment.valueReps ?? 0) повт."
        case .replaceExercise:
            return "Заменить на: \(adjustment.replacementExerciseName ?? "другое упражнение")"
        case .skipExercise:
            return "Пропустить оставшиеся подходы"
        case .none, .unknown:
            return "Обновить план тренировки"
        }
    }
    
    private func applyChanges() {
        guard !isApplied, workout.isActive else { return }
        workoutViewModel.applyAIAdjustment(adjustment, to: workout)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        withAnimation { isApplied = true }
    }
}
