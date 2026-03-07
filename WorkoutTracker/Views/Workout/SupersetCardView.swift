internal import SwiftUI
import SwiftData

struct SupersetCardView: View {
    @Bindable var superset: Exercise // SwiftData модель
    @Environment(\.modelContext) private var modelContext // ДОБАВЛЕНО: Контекст для удаления
    @EnvironmentObject var viewModel: WorkoutViewModel
    
    var currentWorkoutId: UUID
    var onDelete: () -> Void
    var isWorkoutCompleted: Bool = false
    
    @State private var showEffortSheet = false
    @State private var showPRCelebration = false
    @State private var showDeleteAlert = false
    
    var body: some View {
        ZStack { // Обертка для оверлея рекорда
            VStack(alignment: .leading, spacing: 0) {
                
                headerView
                
                exerciseListView
                
                finishButton
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .sheet(isPresented: $showEffortSheet) {
                EffortInputView(effort: $superset.effort)
            }
            .alert(LocalizedStringKey("Delete Superset?"), isPresented: $showDeleteAlert) {
                Button(LocalizedStringKey("Delete"), role: .destructive) {
                    onDelete()
                }
                Button(LocalizedStringKey("Cancel"), role: .cancel) { }
            } message: {
                Text(LocalizedStringKey("Are you sure you want to delete this superset? This action cannot be undone."))
            }
            .blur(radius: showPRCelebration ? 5 : 0)
            
            // Оверлей рекорда
            if showPRCelebration {
                recordOverlay
            }
        }
    }
    
    var headerView: some View {
        HStack {
            HStack {
                Image(systemName: "link").foregroundColor(.purple)
                Text(LocalizedStringKey("Superset")).font(.headline).foregroundColor(.purple)
            }
            Spacer()
            Menu {
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label(LocalizedStringKey("Remove Superset"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis").foregroundColor(.gray).padding(10)
            }
        }
        .padding(.bottom, 10)
    }
    
    var exerciseListView: some View {
        // ИСПРАВЛЕНИЕ: Используем safeSubExercises
        ForEach(Array(superset.safeSubExercises.enumerated()), id: \.element.id) { index, exercise in
            let isLast = index == superset.safeSubExercises.count - 1
            VStack(spacing: 0) {
                // Для вложенных упражнений в суперсете передаем сам объект (reference type)
                ExerciseCardView(
                    exercise: exercise,
                    currentWorkoutId: currentWorkoutId,
                    onDelete: {
                        withAnimation {
                            if let removeIndex = superset.subExercises.firstIndex(where: { $0.id == exercise.id }) {
                                let removedExercise = superset.subExercises.remove(at: removeIndex)
                                // Явно удаляем из контекста базы данных, чтобы не плодить "сирот"
                                modelContext.delete(removedExercise)
                            }
                        }
                    },
                    isEmbeddedInSuperset: true,
                    isWorkoutCompleted: isWorkoutCompleted,
                    isExpanded: .constant(true), // Вложенные упражнения всегда раскрыты
                    isCurrentExercise: false // Вложенные упражнения в суперсете не выделяются отдельно
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
    
    var recordOverlay: some View {
        VStack {
            Image(systemName: "trophy.fill").font(.system(size: 50)).foregroundColor(.yellow)
            Text(LocalizedStringKey("New Record!")).font(.title).bold()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.4))
        .cornerRadius(12)
        .transition(.opacity.combined(with: .scale))
    }
    
    func finishSuperset() {
        guard !superset.isCompleted && !isWorkoutCompleted else { return }
        
        markAllSetsInSupersetCompleted()
        superset.isCompleted = true
        
        // Явно сохраняем состояние в базу перед проверкой рекордов
        try? modelContext.save()
        
        var newRecordWasSet = false
        
        for subExercise in superset.safeSubExercises {
            if subExercise.type == .strength {
                let lastData = viewModel.lastPerformancesCache[subExercise.name]
                
                if let _ = lastData {
                    let oldRecord = viewModel.personalRecordsCache[subExercise.name] ?? 0.0
                    // ИСПРАВЛЕНИЕ: Используем safeSetsList
                    let maxWeight = subExercise.safeSetsList.compactMap { $0.weight }.max() ?? 0.0
                    if maxWeight > oldRecord {
                        newRecordWasSet = true
                    }
                }
            }
        }
        
        if newRecordWasSet {
            withAnimation { showPRCelebration = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { showPRCelebration = false }
            }
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
        
        showEffortSheet = true
    }
    
    func markAllSetsInSupersetCompleted() {
        // ИСПРАВЛЕНИЕ: Используем безопасные массивы для прохода по элементам
        for sub in superset.safeSubExercises {
            for set in sub.safeSetsList {
                set.isCompleted = true
            }
        }
    }
}
