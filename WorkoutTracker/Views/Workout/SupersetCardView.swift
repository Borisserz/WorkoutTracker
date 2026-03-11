internal import SwiftUI
import SwiftData

// Перечисление для уровней рекордов с цветами в стиле Apple Fitness
enum PRLevel {
    case bronze, silver, gold, diamond
    
    var angularColors: [Color] {
        switch self {
        case .bronze: return [.brown, .orange, .brown, .orange, .brown]
        case .silver: return [.gray, .white, .gray, .white, .gray]
        case .gold: return [.yellow, .orange, .yellow, .orange, .yellow]
        case .diamond: return [.cyan, .white, .purple, .blue, .cyan]
        }
    }
    
    var title: LocalizedStringKey {
        switch self {
        case .bronze: return LocalizedStringKey("Bronze Record!")
        case .silver: return LocalizedStringKey("Silver Record!")
        case .gold: return LocalizedStringKey("Gold Record!")
        case .diamond: return LocalizedStringKey("Diamond Record!")
        }
    }
}

// НОВАЯ ВЬЮ ДЛЯ РЕКОРДА (ВЫНЕСЛИ ИЗ КАРТОЧКИ, ЧТОБЫ ИСПОЛЬЗОВАТЬ ГЛОБАЛЬНО)
struct PRCelebrationView: View {
    let prLevel: PRLevel
    @State private var isAnimatingPR = false
    
    var body: some View {
        ZStack {
            // Эффект матового стекла на весь экран
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                ZStack {
                    // Внутреннее легкое свечение
                    Circle()
                        .fill(
                            RadialGradient(gradient: Gradient(colors: [Color.white.opacity(0.2), Color.clear]), center: .center, startRadius: 10, endRadius: 60)
                        )
                        .frame(width: 140, height: 140)
                    
                    // Светящаяся переливающаяся рамка уровня (Apple Fitness Style)
                    Circle()
                        .strokeBorder(
                            AngularGradient(gradient: Gradient(colors: prLevel.angularColors), center: .center),
                            lineWidth: 12
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: prLevel.angularColors.first!.opacity(0.8), radius: isAnimatingPR ? 15 : 5)
                    
                    // Иконка
                    Image(systemName: prLevel == .diamond ? "sparkles" : "trophy.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(colors: prLevel.angularColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                }
                .scaleEffect(isAnimatingPR ? 1.05 : 0.95)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimatingPR)
                
                // Плашка с текстом уровня
                VStack(spacing: 4) {
                    Text(prLevel.title)
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                    
                    Text(LocalizedStringKey("New Personal Best!"))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.6))
                        .overlay(
                            Capsule().stroke(LinearGradient(colors: prLevel.angularColors, startPoint: .leading, endPoint: .trailing), lineWidth: 1.5)
                        )
                )
                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 5)
            }
        }
        .onAppear {
            isAnimatingPR = true
        }
        .onDisappear {
            isAnimatingPR = false
        }
    }
}

struct SupersetCardView: View {
    @Bindable var superset: Exercise // SwiftData модель
    @Environment(\.modelContext) private var modelContext 
    @EnvironmentObject var viewModel: WorkoutViewModel
    
    var currentWorkoutId: UUID
    var onDelete: () -> Void
    var isWorkoutCompleted: Bool = false
    
    @Binding var isExpanded: Bool
    var onExerciseFinished: (() -> Void)? = nil
    var isCurrentExercise: Bool = false
    
    // ДОБАВЛЕНО: Замыкание для передачи события о рекорде наверх
    var onPRSet: ((PRLevel) -> Void)? = nil
    
    @State private var showEffortSheet = false
    
    private var isActiveExercise: Bool {
        isCurrentExercise && !superset.isCompleted
    }
    
    var body: some View {
        // ИСПРАВЛЕНИЕ: Обернули в ZStack, чтобы .sheet прикреплялся к стабильному 
        // элементу, который не меняет свои модификаторы фона/тени при завершении упражнения.
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                
                headerView
                
                if isExpanded {
                    exerciseListView
                    
                    finishButton
                } else {
                    collapsedInfoSection
                }
            }
            .padding()
            .background(
                isActiveExercise
                    ? Color.blue.opacity(0.08)
                    : Color(UIColor.secondarySystemBackground)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isActiveExercise ? Color.blue.opacity(0.5) : Color.clear,
                        lineWidth: isActiveExercise ? 2 : 0
                    )
            )
            .shadow(
                color: isActiveExercise ? Color.blue.opacity(0.2) : Color.clear,
                radius: isActiveExercise ? 8 : 0,
                x: 0,
                y: 2
            )
        }
        .sheet(isPresented: $showEffortSheet, onDismiss: {
            if superset.isCompleted {
                onExerciseFinished?()
            }
        }) {
            EffortInputView(effort: $superset.effort)
        }
    }
    
    var headerView: some View {
        HStack {
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.gray)
                .font(.caption)
                .frame(width: 20, height: 20)
                
            HStack {
                Image(systemName: "link").foregroundColor(.purple)
                Text(LocalizedStringKey("Superset")).font(.headline).foregroundColor(.purple)
            }
            Spacer()
            Menu {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label(LocalizedStringKey("Remove Superset"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis").foregroundColor(.gray).padding(10)
            }
            .highPriorityGesture(TapGesture().onEnded { })
        }
        .padding(.bottom, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }
    }
    
    private var collapsedInfoSection: some View {
        HStack {
            Spacer()
            Text(LocalizedStringKey("Tap to expand"))
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    var exerciseListView: some View {
        ForEach(Array(superset.subExercises.enumerated()), id: \.element.id) { index, exercise in
            let isLast = index == superset.subExercises.count - 1
            VStack(spacing: 0) {
                ExerciseCardView(
                    exercise: exercise,
                    currentWorkoutId: currentWorkoutId,
                    onDelete: {
                        withAnimation {
                            if let removeIndex = superset.subExercises.firstIndex(where: { $0.id == exercise.id }) {
                                let removedExercise = superset.subExercises.remove(at: removeIndex)
                                modelContext.delete(removedExercise)
                            }
                        }
                    },
                    isEmbeddedInSuperset: true,
                    isWorkoutCompleted: isWorkoutCompleted,
                    isExpanded: .constant(true),
                    isCurrentExercise: false 
                )
                .background(Color.clear)
                .shadow(color: .clear, radius: 0)
                .padding(.horizontal, -16)
                .padding(.vertical, -8)
                
                if !isLast {
                    Divider().padding(.leading, 16).padding(.vertical, 8)
                }
            }
        }
    }
    
    var finishButton: some View {
        Button(action: finishSuperset) {
            Text(LocalizedStringKey("Finish Superset"))
                .font(.subheadline).bold()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.green.opacity(0.1))
                .foregroundColor(.green)
                .cornerRadius(8)
        }
        .padding(.top, 12)
        .buttonStyle(BorderlessButtonStyle())
        .disabled(superset.isCompleted || isWorkoutCompleted)
    }
    
    func finishSuperset() {
        guard !superset.isCompleted && !isWorkoutCompleted else { return }
        
        // ИСПРАВЛЕНИЕ: Удаляем незавершенные подходы во всем суперсете
        for sub in superset.subExercises {
            let uncompletedSets = sub.setsList.filter { !$0.isCompleted }
            for set in uncompletedSets {
                if let index = sub.setsList.firstIndex(where: { $0.id == set.id }) {
                    sub.setsList.remove(at: index)
                }
                modelContext.delete(set)
            }
            
            let remainingSets = sub.sortedSets
            for (i, set) in remainingSets.enumerated() {
                set.index = i + 1
            }
            sub.isCompleted = true
        }
        
        superset.isCompleted = true
        try? modelContext.save()
        
        var newRecordWasSet = false
        var maxIncreasePercent: Double = 0.0
        
        for subExercise in superset.subExercises {
            if subExercise.type == .strength {
                let lastData = viewModel.lastPerformancesCache[subExercise.name]
                
                if let _ = lastData {
                    let oldRecord = viewModel.personalRecordsCache[subExercise.name] ?? 0.0
                    let maxWeight = subExercise.setsList.compactMap { $0.weight }.max() ?? 0.0
                    
                    if maxWeight > oldRecord {
                        newRecordWasSet = true
                        
                        let increase = oldRecord > 0 ? (maxWeight - oldRecord) / oldRecord : 0.0
                        if increase > maxIncreasePercent {
                            maxIncreasePercent = increase
                        }
                    }
                }
            }
        }
        
        if newRecordWasSet {
            let calculatedPRLevel: PRLevel
            
            if maxIncreasePercent >= 0.20 {
                calculatedPRLevel = .diamond
            } else if maxIncreasePercent >= 0.10 {
                calculatedPRLevel = .gold
            } else if maxIncreasePercent >= 0.05 {
                calculatedPRLevel = .silver
            } else {
                calculatedPRLevel = .bronze
            }
            
            onPRSet?(calculatedPRLevel)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                self.showEffortSheet = true
            }
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } else {
            self.showEffortSheet = true
        }
    }
    
    func markAllSetsInSupersetCompleted() {
        for sub in superset.subExercises {
            for set in sub.setsList {
                set.isCompleted = true
            }
        }
    }
}
