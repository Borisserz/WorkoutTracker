// ============================================================
// FILE: WorkoutTracker/Features/Workout/Views/TemplatePreviewSheetView.swift
// ============================================================

internal import SwiftUI
import SwiftData

// MARK: - 1. Universal Preview Item
enum PreviewItem: Identifiable, Hashable {
    case preset(WorkoutPreset)
    case favorite(Workout)
    
    var id: String {
        switch self {
        case .preset(let p): return "preset_\(p.persistentModelID.hashValue)"
        case .favorite(let w): return "fav_\(w.persistentModelID.hashValue)"
        }
    }
    
    var title: String {
        switch self {
        case .preset(let p): return p.name
        case .favorite(let w): return w.title
        }
    }
    
    var icon: String {
        switch self {
        case .preset(let p): return p.icon
        case .favorite(let w): return w.icon
        }
    }
    
    var exercises: [Exercise] {
        switch self {
        case .preset(let p): return p.exercises
        case .favorite(let w): return w.exercises
        }
    }
    
    var isSystemIcon: Bool {
        switch self {
        case .preset(let p): return p.isSystem
        case .favorite: return true
        }
    }
}

// MARK: - 2. Premium Preview Sheet View
struct TemplatePreviewSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UnitsManager.self) private var unitsManager
    @Environment(\.colorScheme) private var colorScheme // 👈 АДАПТАЦИЯ
    @Environment(ThemeManager.self) private var themeManager

    @State private var selectedHistoryExercise: String? = nil
    
    let item: PreviewItem
    let onStart: () -> Void
    
    private var targetMuscles: [String] {
        let allMuscles = item.exercises.map { $0.muscleGroup }
        return Array(Set(allMuscles)).sorted()
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // 👈 АДАПТАЦИЯ ФОНА
                (colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color(UIColor.secondarySystemBackground)).ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        headerSection
                        tagsSection
                        
                        Divider()
                            .padding(.horizontal)
                            .opacity(0.5)
                        
                        exercisesListSection
                    }
                    .padding(.bottom, 120)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(colorScheme == .dark ? Color(UIColor.tertiarySystemFill) : .gray.opacity(0.5)) // 👈
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                startWorkoutButton
            }
            .navigationDestination(item: $selectedHistoryExercise) { exName in
                ExerciseHistoryView(exerciseName: exName)
            }
        }
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - UI Components
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [themeManager.current.primaryAccent, themeManager.current.primaryAccent.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 80, height: 80)
                    .blur(radius: 25)
                    .opacity(0.5)
                
                ZStack {
                    Circle()
                        .fill(colorScheme == .dark ? themeManager.current.surface : Color.white) // 👈
                        .frame(width: 88, height: 88)
                        .overlay(Circle().stroke(Color.gray.opacity(0.15), lineWidth: 1))
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.1 : 0.05), radius: 10, x: 0, y: 5)
                    
                    if item.isSystemIcon {
                        Image(systemName: item.icon)
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(LinearGradient(colors: [themeManager.current.primaryAccent, themeManager.current.primaryAccent.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    } else if UIImage(named: item.icon) != nil {
                        Image(item.icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 44, height: 44)
                    } else {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundColor(themeManager.current.primaryAccent)
                    }
                }
            }
            .padding(.top, 24)
            
            VStack(spacing: 6) {
                // 👈 АДАПТАЦИЯ ТЕКСТА
                Text(LocalizedStringKey(item.title))
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .black)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text(LocalizedStringKey("\(item.exercises.count) exercises"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
            }
        }
    }
    
    @ViewBuilder
    private var tagsSection: some View {
        if !targetMuscles.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Spacer().frame(width: 10)
                    
                    ForEach(targetMuscles, id: \.self) { muscle in
                        Text(LocalizedStringKey(muscle))
                            .font(.caption)
                            .fontWeight(.bold)
                            .textCase(.uppercase)
                            .foregroundColor(themeManager.current.primaryAccent)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(themeManager.current.primaryAccent.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    
                    Spacer().frame(width: 10)
                }
            }
        }
    }
    
    private var exercisesListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedStringKey("Workout Structure"))
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(item.exercises) { exercise in
                    Button {
                        selectedHistoryExercise = exercise.name
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(themeManager.current.primaryAccent.opacity(0.1))
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: exercise.type == .cardio ? "figure.run" : "dumbbell.fill")
                                    .foregroundColor(themeManager.current.primaryAccent)
                                    .font(.title3)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                // 👈 АДАПТАЦИЯ ИМЕНИ УПРАЖНЕНИЯ
                                Text(LocalizationHelper.shared.translateName(exercise.name))
                                    .font(.headline)
                                    .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .black)
                                    .lineLimit(1)
                                
                                HStack(spacing: 6) {
                                    Text(LocalizedStringKey("\(exercise.setsCount) sets"))
                                    Text("×")
                                    Text(LocalizedStringKey("\(exercise.firstSetReps) reps"))
                                    
                                    if exercise.type == .strength && exercise.firstSetWeight > 0 {
                                        Text("•")
                                        let weight = unitsManager.convertFromKilograms(exercise.firstSetWeight)
                                        Text("\(LocalizationHelper.shared.formatFlexible(weight)) \(unitsManager.weightUnitString())")
                                            .foregroundColor(themeManager.current.primaryAccent)
                                            .bold()
                                    }
                                }
                                .font(.subheadline)
                                .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                            }
                            
                            Spacer()
                        }
                        .padding(12)
                        // 👈 АДАПТАЦИЯ ФОНА КАРТОЧКИ
                        .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(colorScheme == .dark ? themeManager.current.surfaceVariant : Color.black.opacity(0.05), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var startWorkoutButton: some View {
        Button {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            dismiss()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onStart()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.title3)
                Text(LocalizedStringKey("Start Workout"))
                    .font(.title3)
                    .fontWeight(.bold)
            }
            .foregroundColor(.white) // 👈 Всегда белый
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(themeManager.current.primaryAccent) // 👈 Сплошной цвет (без градиента)
            .cornerRadius(20)
            .shadow(color: themeManager.current.primaryAccent.opacity(0.4), radius: 15, x: 0, y: 8)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .background(
            // 👈 АДАПТАЦИЯ НИЖНЕГО ГРАДИЕНТА
            LinearGradient(colors: [(colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color(UIColor.secondarySystemBackground)), (colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color(UIColor.secondarySystemBackground)).opacity(0.0)], startPoint: .bottom, endPoint: .top)
                .ignoresSafeArea()
        )
    }
}
