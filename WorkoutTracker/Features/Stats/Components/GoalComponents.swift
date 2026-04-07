//
//  GoalComponents.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 6.04.26.
//

internal import SwiftUI
import SwiftData

// MARK: - Active Goal Card UI Redesign
struct ActiveGoalCard: View {
    let goal: UserGoal?
    let currentValue: Double
    let onAddTapped: () -> Void
    let onDeleteTapped: () -> Void
    let onReplaceTapped: () -> Void
    
    @Environment(UnitsManager.self) var unitsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let goal = goal {
                HStack(alignment: .top) {
                    ZStack {
                        Circle().fill(iconColor(for: goal.type).opacity(0.15)).frame(width: 48, height: 48)
                        Image(systemName: icon(for: goal.type)).font(.title3).foregroundColor(iconColor(for: goal.type))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title(for: goal))
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(subtitle(for: goal))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    Menu {
                        Button { onReplaceTapped() } label: { Label(LocalizedStringKey("Replace Goal"), systemImage: "arrow.triangle.2.circlepath") }
                        Button(role: .destructive) { onDeleteTapped() } label: { Label(LocalizedStringKey("Delete Goal"), systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.title3)
                            .foregroundColor(.gray)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                
                let progress = calculateProgress(goal: goal, current: currentValue)
                
                VStack(spacing: 8) {
                    HStack {
                        Text(currentText(goal: goal))
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.primary)
                            .contentTransition(.numericText())
                        Spacer()
                        Text(targetText(goal: goal))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.15))
                                .frame(height: 14)
                            
                            Capsule()
                                .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(0, geo.size.width * CGFloat(progress)), height: 14)
                                .shadow(color: .cyan.opacity(0.4), radius: 5, x: 0, y: 0)
                        }
                    }
                    .frame(height: 14)
                }
                
                HStack {
                    Spacer()
                    Text(daysLeft(from: goal.targetDate))
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }
                
            } else {
                // Empty state
                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizedStringKey("Challenge yourself"))
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(LocalizedStringKey("Define your next goal to lock in."))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        onAddTapped()
                    }) {
                        HStack {
                            Image(systemName: "plus")
                            Text(LocalizedStringKey("Add Goal"))
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
    }

    private func icon(for type: GoalType) -> String {
        switch type { case .strength: return "dumbbell.fill"; case .bodyweight: return "scalemass.fill"; case .consistency: return "flame.fill" }
    }
    private func iconColor(for type: GoalType) -> Color {
        switch type { case .strength: return .blue; case .bodyweight: return .purple; case .consistency: return .orange }
    }
    private func title(for goal: UserGoal) -> LocalizedStringKey {
        switch goal.type { case .strength: return LocalizedStringKey("\(goal.exerciseName ?? "Exercise")"); case .bodyweight: return LocalizedStringKey("Target Bodyweight"); case .consistency: return LocalizedStringKey("Workout Streak") }
    }
    private func subtitle(for goal: UserGoal) -> LocalizedStringKey {
        switch goal.type { case .strength: return LocalizedStringKey("Strength Goal"); case .bodyweight: return LocalizedStringKey("Bodyweight Goal"); case .consistency: return LocalizedStringKey("Consistency Goal") }
    }
    private func daysLeft(from date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        if days < 0 { return String(localized: "Expired") }
        if days == 0 { return String(localized: "Today") }
        return String(localized: "\(days) Days Left")
    }
    private func calculateProgress(goal: UserGoal, current: Double) -> Double {
        if goal.type == .bodyweight {
            let totalDist = abs(goal.targetValue - goal.startingValue)
            let curDist = abs(current - goal.startingValue)
            if totalDist == 0 { return 1.0 }
            return min(1.0, curDist / totalDist)
        } else {
            let totalDist = goal.targetValue - goal.startingValue
            let curDist = current - goal.startingValue
            if totalDist <= 0 { return 1.0 }
            return min(1.0, max(0.0, curDist / totalDist))
        }
    }
    private func currentText(goal: UserGoal) -> String {
        switch goal.type {
        case .strength, .bodyweight: return "\(LocalizationHelper.shared.formatDecimal(unitsManager.convertFromKilograms(currentValue))) \(unitsManager.weightUnitString())"
        case .consistency: return "\(Int(currentValue)) days"
        }
    }
    private func targetText(goal: UserGoal) -> String {
        switch goal.type {
        case .strength: return "\(LocalizationHelper.shared.formatDecimal(unitsManager.convertFromKilograms(goal.targetValue))) \(unitsManager.weightUnitString()) x \(goal.targetReps) reps"
        case .bodyweight: return "\(LocalizationHelper.shared.formatDecimal(unitsManager.convertFromKilograms(goal.targetValue))) \(unitsManager.weightUnitString())"
        case .consistency: return "\(Int(goal.targetValue)) days"
        }
    }
}

// MARK: - Goal Selection Sheet (Без изменений, оставляем для полноты файла)
struct GoalSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    var onGoalCreated: () -> Void
    
    @State private var navigateToStrength = false
    @State private var navigateToBodyweight = false
    @State private var navigateToConsistency = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    goalTypeCard(
                        title: "Strength Goal",
                        subtitle: "Crush your personal records and get stronger!",
                        icon: "dumbbell.fill",
                        color: .blue,
                        action: { navigateToStrength = true }
                    )
                    
                    goalTypeCard(
                        title: "Bodyweight Goal",
                        subtitle: "Transform your body and reach your target weight!",
                        icon: "scalemass.fill",
                        color: .purple,
                        action: { navigateToBodyweight = true }
                    )
                    
                    goalTypeCard(
                        title: "Consistency Goal",
                        subtitle: "Build momentum with workout streaks!",
                        icon: "flame.fill",
                        color: .orange,
                        action: { navigateToConsistency = true }
                    )
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(LocalizedStringKey("New Goal"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Cancel")) { dismiss() }
                }
            }
            .navigationDestination(isPresented: $navigateToStrength) {
                GoalSetupDetailView(type: .strength, onComplete: { dismiss(); onGoalCreated() })
            }
            .navigationDestination(isPresented: $navigateToBodyweight) {
                GoalSetupDetailView(type: .bodyweight, onComplete: { dismiss(); onGoalCreated() })
            }
            .navigationDestination(isPresented: $navigateToConsistency) {
                GoalSetupDetailView(type: .consistency, onComplete: { dismiss(); onGoalCreated() })
            }
        }
        .presentationDetents([.fraction(0.85), .large])
    }
    
    private func goalTypeCard(title: LocalizedStringKey, subtitle: LocalizedStringKey, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
            action()
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 60, height: 60)
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Goal Setup Detail Form
struct GoalSetupDetailView: View {
    let type: GoalType
    var onComplete: () -> Void
    
    @Environment(\.modelContext) private var context
    @Environment(UnitsManager.self) var unitsManager
    @Environment(DashboardViewModel.self) var dashboardViewModel
    
    @AppStorage(Constants.UserDefaultsKeys.userBodyWeight.rawValue) private var currentBodyWeight = 75.0
    
    @State private var targetWeightString: String = ""
    @State private var targetDays: Int = 10
    @State private var targetReps: Int = 1 // ✅ ДОБАВЛЕН STATE ДЛЯ ПОВТОРЕНИЙ
    @State private var targetDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
    @State private var selectedExercise: String = "Bench Press"
    
    var body: some View {
        Form {
            Section(header: Text(LocalizedStringKey("Goal Parameters"))) {
                if type == .strength {
                    Picker(LocalizedStringKey("Exercise"), selection: $selectedExercise) {
                        ForEach(getAvailableExercises(), id: \.self) { ex in
                            Text(LocalizedStringKey(ex)).tag(ex)
                        }
                    }
                    .pickerStyle(.menu) // ✅ ИСПРАВЛЕНИЕ: .menu вместо .navigationLink спасает от бага SwiftUI
                    .tint(.blue)
                }
                if type == .strength || type == .bodyweight {
                    HStack {
                        Text(LocalizedStringKey("Target (\(unitsManager.weightUnitString()))"))
                        Spacer()
                        TextField("0", text: $targetWeightString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.blue)
                            .bold()
                    }
                    
                    // ✅ СТЕППЕР ДЛЯ ПОВТОРЕНИЙ (Только для силы)
                    if type == .strength {
                        Stepper(value: $targetReps, in: 1...50) {
                            HStack {
                                Text(LocalizedStringKey("Target Reps"))
                                Spacer()
                                Text("\(targetReps)")
                                    .foregroundColor(.blue)
                                    .bold()
                            }
                        }
                    }
                } else if type == .consistency {
                    Stepper(value: $targetDays, in: 5...365, step: 5) {
                        HStack {
                            Text(LocalizedStringKey("Target Streak"))
                            Spacer()
                            Text(LocalizedStringKey("\(targetDays) days"))
                                .foregroundColor(.blue)
                                .bold()
                        }
                    }
                }
            }
            
            Section(header: Text(LocalizedStringKey("Deadline")), footer: Text(LocalizedStringKey("Set a realistic date to achieve your goal."))) {
                DatePicker(LocalizedStringKey("Target Date"), selection: $targetDate, in: Date()..., displayedComponents: .date)
            }
            
            Section {
                Button(action: saveGoal) {
                    Text(LocalizedStringKey("Set Goal"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                }
                .listRowBackground(Color.blue)
            }
        }
        .navigationTitle(type.rawValue.capitalized)
        .onAppear {
            setupInitialValues()
        }
    }
    
    private func getAvailableExercises() -> [String] {
        let pool = (Exercise.catalog["Chest"] ?? []) + (Exercise.catalog["Back"] ?? []) + (Exercise.catalog["Legs"] ?? [])
        return Array(Set(pool)).sorted()
    }
    
    private func setupInitialValues() {
        if type == .bodyweight {
            targetWeightString = LocalizationHelper.shared.formatDecimal(unitsManager.convertFromKilograms(currentBodyWeight))
        } else if type == .strength {
            selectedExercise = getAvailableExercises().first ?? "Bench Press"
            let currentMax = dashboardViewModel.personalRecordsCache[selectedExercise] ?? 0.0
            targetWeightString = LocalizationHelper.shared.formatDecimal(unitsManager.convertFromKilograms(currentMax + 5.0))
        }
    }
    
    private func saveGoal() {
        let startingVal: Double
        let targetVal: Double
        
        switch type {
        case .strength:
            startingVal = dashboardViewModel.personalRecordsCache[selectedExercise] ?? 0.0
            targetVal = unitsManager.convertToKilograms(Double(targetWeightString.replacingOccurrences(of: ",", with: ".")) ?? 0)
        case .bodyweight:
            startingVal = currentBodyWeight
            targetVal = unitsManager.convertToKilograms(Double(targetWeightString.replacingOccurrences(of: ",", with: ".")) ?? 0)
        case .consistency:
            startingVal = Double(WidgetDataManager.load().streak)
            targetVal = Double(targetDays)
        }
        
        let newGoal = UserGoal(
            type: type,
            targetValue: targetVal,
            startingValue: startingVal,
            targetDate: targetDate,
            exerciseName: type == .strength ? selectedExercise : nil,
            targetReps: type == .strength ? targetReps : 1 // ✅ Сохраняем повторения
        )
        
        context.insert(newGoal)
        try? context.save()
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        onComplete()
    }
}
