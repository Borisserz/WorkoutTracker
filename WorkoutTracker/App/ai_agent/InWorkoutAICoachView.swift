//
//  InWorkoutAICoachView.swift
//  WorkoutTracker
//

internal import SwiftUI
import SwiftData

struct InWorkoutAICoachView: View {
    @Bindable var workout: Workout
    @StateObject private var viewModel = InWorkoutAICoachViewModel()
    @Environment(\.modelContext) private var context
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Зона чата
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(viewModel.chatHistory) { message in
                            InWorkoutChatBubble(message: message, workout: workout)
                                .id(message.id)
                        }
                        
                        if viewModel.isGenerating {
                            AILoadingIndicator() // Берётся из AICoachComponents
                                .id("loading_indicator")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        Color.clear.frame(height: 20).id("bottom_spacer")
                    }
                    .padding(.vertical)
                }
                .onChange(of: viewModel.chatHistory) { _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: isInputFocused) { _, focused in
                    if focused {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                }
            }
            
            // Зона ввода
            HStack(alignment: .bottom, spacing: 12) {
                TextField(LocalizedStringKey("Ask for advice..."), text: $viewModel.inputText, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(20)
                    .focused($isInputFocused)
                
                Button {
                    viewModel.sendMessage(currentWorkout: workout)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundColor(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isGenerating ? .gray.opacity(0.5) : .accentColor)
                }
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isGenerating)
            }
            .padding(.top, 8)
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo("bottom_spacer", anchor: .bottom)
        }
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
                    Circle()
                        .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 32, height: 32)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                Text(LocalizedStringKey(message.text))
                    .font(.body)
                    .foregroundColor(message.isUser ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(message.isUser ? Color.accentColor : Color(UIColor.secondarySystemBackground))
                    .clipShape(ChatBubbleShape(isUser: message.isUser)) // Берется из AICoachComponents
                
                if let adjustment = message.adjustment {
                    WorkoutAdjustmentCardView(adjustment: adjustment, workout: workout)
                        .padding(.top, 4)
                }
            }
            
            if !message.isUser { Spacer(minLength: 40) }
        }
    }
}

// MARK: - Glassmorphism Action Card
struct WorkoutAdjustmentCardView: View {
    let adjustment: InWorkoutResponseDTO
    @Bindable var workout: Workout
    
    @State private var isApplied = false
    @Environment(\.modelContext) private var context
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .foregroundColor(.yellow)
                Text(LocalizedStringKey("AI Suggestion"))
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let target = adjustment.targetExerciseName {
                        Text(target)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    
                    Text(actionDescription)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
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
                    Text(isApplied ? LocalizedStringKey("Applied") : LocalizedStringKey("Apply Changes"))
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isApplied ? Color.green.opacity(0.8) : Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isApplied)
        }
        .padding()
        // СТИЛЬ GLASSMORPHISM
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        .frame(maxWidth: 320)
    }
    
    private var actionDescription: String {
        switch adjustment.actionType {
        case "dropWeight":
            return "Drop next set weight by \(Int(adjustment.valuePercentage ?? 0))%"
        case "addSet":
            return "Add a burnout set: \(adjustment.valueReps ?? 0) reps @ \(Int(adjustment.valueWeightKg ?? 0))kg"
        case "replaceExercise":
            return "Substitute with \(adjustment.replacementExerciseName ?? "another exercise")"
        default:
            return "Update workout plan"
        }
    }
    
    // МУТАЦИЯ АКТИВНОЙ ТРЕНИРОВКИ
    private func applyChanges() {
        guard !isApplied else { return }
        guard let targetName = adjustment.targetExerciseName else { return }
        
        // Ищем упражнение в текущей тренировке
        if let targetExercise = workout.exercises.first(where: { $0.name.lowercased() == targetName.lowercased() }) {
            
            switch adjustment.actionType {
            case "dropWeight":
                if let nextSet = targetExercise.setsList.sorted(by: { $0.index < $1.index }).first(where: { !$0.isCompleted }) {
                    if let currentWeight = nextSet.weight, let percentage = adjustment.valuePercentage {
                        let newWeight = currentWeight * (1.0 - (percentage / 100.0))
                        nextSet.weight = round(newWeight / 2.5) * 2.5
                    }
                }
                
            case "addSet":
                let newIndex = (targetExercise.setsList.map { $0.index }.max() ?? 0) + 1
                let newSet = WorkoutSet(
                    index: newIndex,
                    weight: adjustment.valueWeightKg,
                    reps: adjustment.valueReps,
                    isCompleted: false,
                    type: .normal
                )
                context.insert(newSet)
                targetExercise.setsList.append(newSet)
                
            case "replaceExercise":
                if let newName = adjustment.replacementExerciseName {
                    let newExercise = Exercise(name: newName, muscleGroup: targetExercise.muscleGroup, type: .strength, sets: 3, reps: 10, weight: 0)
                    context.insert(newExercise)
                    if let idx = workout.exercises.firstIndex(of: targetExercise) {
                        workout.exercises.insert(newExercise, at: idx + 1)
                    }
                }
            default: break
            }
            
            targetExercise.updateAggregates()
            try? context.save()
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            withAnimation {
                isApplied = true
            }
        }
    }
}
