// ============================================================
// FILE: WatchApp/Views/WatchActiveWorkoutView.swift
// ============================================================
internal import SwiftUI
import SwiftData

// Enum для колесика (переключатель между весом и повторениями)
enum CrownFocus { case weight, reps }

// MARK: - 1. ГЛАВНЫЙ ЭКРАН ТРЕНИРОВКИ
struct WatchActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WatchWorkoutManager.self) private var workoutManager
    @Bindable var viewModel: WatchActiveWorkoutViewModel
    
    @State private var startDate = Date()
    @State private var finalDuration: TimeInterval = 0
    @State private var showSummary = false
    @State private var showExerciseList = false
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 12) {
                    hudSection
                    
                    if viewModel.exercises.isEmpty {
                        Text("No exercises yet.\nTap + to add one.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 10)
                    } else {
                        ForEach(viewModel.exercises.indices, id: \.self) { index in
                            NavigationLink {
                                WatchExerciseSetView(viewModel: viewModel, exerciseIndex: index)
                            } label: {
                                exerciseRow(for: viewModel.exercises[index])
                            }
                        }
                    }
                    
                    Button {
                        showExerciseList = true
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add Exercise")
                        }
                        .foregroundColor(.blue)
                    }
                    .background(Color.blue.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    HStack(spacing: 8) {
                        Button(role: .destructive) {
                            Task {
                                await viewModel.cancelWorkout()
                                await workoutManager.endWorkout()
                                dismiss()
                            }
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .background(Color.red.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        Button {
                            Task {
                                finalDuration = Date().timeIntervalSince(startDate)
                                await workoutManager.endWorkout()
                                await viewModel.finishWorkout()
                                showSummary = true
                            }
                        } label: {
                            Text("Finish").bold()
                        }
                        .background(Color.green)
                        .foregroundColor(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .navigationBarHidden(true)
        .task {
            await workoutManager.startWorkout()
            await viewModel.initializeWorkout()
        }
        .onAppear { startDate = Date() }
        .sheet(isPresented: $showExerciseList) {
            WatchExerciseSelectionView { exerciseName in
                // ✅ ИСПРАВЛЕНИЕ ЗДЕСЬ
                Task {
                    await viewModel.addExercise(name: exerciseName)
                }
                showExerciseList = false
            }
        }
        .fullScreenCover(isPresented: $showSummary) {
            WatchSummaryView(
                duration: finalDuration,
                totalVolume: viewModel.totalVolume,
                totalSets: viewModel.totalSets
            ) { dismiss() }
        }
    }
    
    private var hudSection: some View {
        HStack {
            TimelineView(.periodic(from: startDate, by: 1.0)) { context in
                let elapsed = context.date.timeIntervalSince(startDate)
                Text(Duration.seconds(elapsed), format: .time(pattern: .minuteSecond))
                    .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundColor(.yellow)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Text("\(Int(workoutManager.heartRate))")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 12))
                    .symbolEffect(.pulse, options: .repeating, isActive: workoutManager.isRunning)
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
    }
    
    private func exerciseRow(for exercise: ExerciseDTO) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(exercise.name).font(.headline).lineLimit(1)
                
                // ✅ ИСПРАВЛЕНИЕ: Безопасное обращение к опциональному массиву
                let setsCount = (exercise.setsList ?? []).count
                Text("\(setsCount) sets completed")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }}

// MARK: - 2. ЭКРАН ДОБАВЛЕНИЯ СЕТА
struct WatchExerciseSetView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: WatchActiveWorkoutViewModel
    let exerciseIndex: Int
    
    @State private var weight: Double = 20.0
    @State private var reps: Double = 10.0
    @State private var focus: CrownFocus = .weight
    
    private var crownBinding: Binding<Double> {
        Binding(
            get: { focus == .weight ? weight : reps },
            set: { newValue in
                if focus == .weight { weight = max(0, newValue) } else { reps = max(1, newValue) }
            }
        )
    }
    
    var body: some View {
        let exerciseName = viewModel.exercises[exerciseIndex].name
        
        VStack(spacing: 12) {
            Text(exerciseName)
                .font(.headline)
                .foregroundColor(.blue)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            HStack(spacing: 8) {
                inputButton(title: "WEIGHT", value: String(format: "%.1f", weight), type: .weight, color: .blue)
                inputButton(title: "REPS", value: "\(Int(reps))", type: .reps, color: .orange)
            }
            
            Button {
                Task {
                    await viewModel.logSet(for: exerciseIndex, weight: weight, reps: Int(reps))
                    dismiss()
                }
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Save Set").bold()
                }
            }
            .background(Color.green)
            .foregroundColor(.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .focusable()
        .digitalCrownRotation(
            crownBinding,
            from: 0, through: 500, by: focus == .weight ? 2.5 : 1.0,
            sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true
        )
    }
    
    private func inputButton(title: String, value: String, type: CrownFocus, color: Color) -> some View {
        let isFocused = focus == type
        return Button {
            withAnimation { focus = type }
        } label: {
            VStack {
                Text(title).font(.system(size: 10, weight: .bold)).foregroundColor(isFocused ? color : .gray)
                Text(value).font(.system(size: 24, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(isFocused ? color.opacity(0.2) : Color.white.opacity(0.1))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isFocused ? color : Color.clear, lineWidth: 2))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 3. СПИСОК УПРАЖНЕНИЙ
struct WatchExerciseSelectionView: View {
    var onSelect: (String) -> Void
    
    // ✅ 1. Заменяем статический массив на @State
    @State private var allExercises: [String] = []

    var body: some View {
        NavigationStack {
            // ✅ 2. Используем @State
            List(allExercises, id: \.self) { name in
                Button(action: { onSelect(name) }) {
                    Text(name)
                        .padding(.vertical, 4)
                }
            }
            .navigationTitle("Exercises")
            // ✅ 3. Асинхронно загружаем данные при появлении
            .task {
                let catalog = await ExerciseDatabaseService.shared.getCatalog()
                // Превращаем словарь в плоский отсортированный массив
                self.allExercises = Array(Set(catalog.values.flatMap { $0 })).sorted()
            }
        }
    }
}

// MARK: - 4. ФИНАЛЬНЫЙ ЭКРАН
struct WatchSummaryView: View {
    let duration: TimeInterval
    let totalVolume: Double
    let totalSets: Int
    var onDismiss: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.yellow)
                    .padding(.top, 10)
                
                Text("Workout Complete!")
                    .font(.title3)
                    .bold()
                
                VStack(spacing: 8) {
                    summaryRow(title: "Time", value: formattedDuration(duration))
                    summaryRow(title: "Sets", value: "\(totalSets)")
                    summaryRow(title: "Volume", value: "\(Int(totalVolume)) kg")
                }
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(12)
                
                Button(action: onDismiss) {
                    Text("Done")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(16)
                .padding(.top, 10)
            }
            .padding(.horizontal)
        }
        .navigationBarHidden(true)
    }
    
    private func summaryRow(title: String, value: String) -> some View {
        HStack {
            Text(title).foregroundColor(.secondary)
            Spacer()
            Text(value).bold()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
    
    private func formattedDuration(_ time: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: time) ?? "0m"
    }
}
