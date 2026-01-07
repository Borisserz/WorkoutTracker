internal import SwiftUI

struct SupersetCardView: View {
    @Binding var superset: Exercise
    @EnvironmentObject var viewModel: WorkoutViewModel
    var currentWorkoutId: UUID     // Callbacks & States
    var onDelete: () -> Void
    var isWorkoutCompleted: Bool = false // Флаг завершения тренировки
    @State private var showEffortSheet = false
    @State private var showPRCelebration = false
    @State private var showDeleteAlert = false
    
    var body: some View {
        ZStack { // Обертка для оверлея рекорда
            VStack(alignment: .leading, spacing: 0) {
                
                // 1. ЗАГОЛОВОК
                headerView
                
                // 2. СПИСОК УПРАЖНЕНИЙ
                exerciseListView
                
                // 3. КНОПКА ЗАВЕРШЕНИЯ
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
    
    // --- ВЫНЕСЕННЫЕ ЧАСТИ ---
    
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
        ForEach($superset.subExercises.indices, id: \.self) { index in
            let isLast = index == superset.subExercises.count - 1
            VStack(spacing: 0) {
                // Для вложенных упражнений в суперсете всегда раскрыты
                ExerciseCardView(
                    exercise: $superset.subExercises[index],
                    currentWorkoutId: currentWorkoutId,
                    onDelete: {
                        withAnimation {
                            if index < superset.subExercises.count {
                                superset.subExercises.remove(at: index)
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
        Button(action: finishSuperset) { // <--- ИЗМЕНЕНО
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
        .disabled(superset.isCompleted || isWorkoutCompleted) // Запрещаем завершать, если суперсет или тренировка завершены
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
    
    // --- ЛОГИКА ---
    
    func finishSuperset() {
          // Запрещаем завершать, если суперсет или тренировка завершены
          guard !superset.isCompleted && !isWorkoutCompleted else { return }
          
          markAllSetsInSupersetCompleted()
          superset.isCompleted = true // Помечаем суперсет как завершенный
          
          var newRecordWasSet = false
          
          for subExercise in superset.subExercises {
              if subExercise.type == .strength {
                  // ВАЖНО: onlyCompleted: true
                  let oldRecord = viewModel.getPersonalRecord(for: subExercise.name, onlyCompleted: true)
                  
                  let maxWeight = subExercise.setsList.compactMap { $0.weight }.max() ?? 0
                  if maxWeight > oldRecord {
                      newRecordWasSet = true
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
        for i in 0..<superset.subExercises.count {
            for j in 0..<superset.subExercises[i].setsList.count {
                superset.subExercises[i].setsList[j].isCompleted = true
            }
        }
    }
}
