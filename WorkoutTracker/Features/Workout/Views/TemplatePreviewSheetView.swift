//
//  TemplatePreviewSheetView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 7.04.26.
//

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
    @Environment(\.colorScheme) private var colorScheme
    
    // Стейт для навигации
    @State private var selectedHistoryExercise: String? = nil
    
    let item: PreviewItem
    let onStart: () -> Void
    
    // Динамическое извлечение уникальных групп мышц
    private var targetMuscles: [String] {
        let allMuscles = item.exercises.map { $0.muscleGroup }
        return Array(Set(allMuscles)).sorted()
    }
    
        @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Премиальный фон
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        headerSection
                        tagsSection
                        
                        Divider()
                            .padding(.horizontal)
                            .opacity(0.5)
                        
                        exercisesListSection
                    }
                    .padding(.bottom, 120) // Место под плавающую кнопку старта
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
                            .foregroundStyle(.secondary, Color(UIColor.tertiarySystemFill))
                    }
                }
            }
            // Плавающая кнопка старта с градиентом-подложкой
            .safeAreaInset(edge: .bottom) {
                startWorkoutButton
            }
            // ВАЖНО: Модификатор навигации должен быть ВНУТРИ NavigationStack
            .navigationDestination(item: $selectedHistoryExercise) { exName in
                ExerciseHistoryView(exerciseName: exName)
            }
        }
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - UI Components
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Иконка с неоновым сине-голубым свечением
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [themeManager.current.primaryAccent, themeManager.current.primaryAccent.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 80, height: 80)
                    .blur(radius: 25)
                    .opacity(0.5)
                
                ZStack {
                    Circle()
                        .fill(themeManager.current.surface)
                        .frame(width: 88, height: 88)
                        .overlay(Circle().stroke(Color.gray.opacity(0.15), lineWidth: 1))
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    
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
            
            // Название и детали
            VStack(spacing: 6) {
                Text(LocalizedStringKey(item.title))
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(themeManager.current.primaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text(LocalizedStringKey("\(item.exercises.count) exercises"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(themeManager.current.secondaryText)
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
                            .foregroundColor(themeManager.current.primaryAccent) // Текст в цвет акцента
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(themeManager.current.primaryAccent.opacity(0.15)) // Полупрозрачный фон акцента
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
                .foregroundColor(themeManager.current.secondaryText)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(item.exercises) { exercise in
                    Button {
                        selectedHistoryExercise = exercise.name
                    } label: {
                        HStack(spacing: 16) {
                            // Иконка упражнения
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(themeManager.current.primaryAccent.opacity(0.1))
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: exercise.type == .cardio ? "figure.run" : "dumbbell.fill")
                                    .foregroundColor(themeManager.current.primaryAccent)
                                    .font(.title3)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(LocalizationHelper.shared.translateName(exercise.name))
                                    .font(.headline)
                                    .foregroundColor(themeManager.current.primaryText)
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
                                .foregroundColor(themeManager.current.secondaryText)
                            }
                            
                            Spacer()
                        }
                        .padding(12)
                        .background(themeManager.current.surface)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(themeManager.current.surfaceVariant, lineWidth: 1)
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
            
            // Задержка для плавного закрытия шторки
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
            .foregroundColor(themeManager.current.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(colors: [themeManager.current.primaryAccent, themeManager.current.primaryAccent.opacity(0.5)], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(20)
            .shadow(color: .blue.opacity(0.4), radius: 15, x: 0, y: 8)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .background(
            // Плавный градиент (фейд) снизу вверх
            LinearGradient(colors: [Color(UIColor.systemGroupedBackground), Color(UIColor.systemGroupedBackground).opacity(0.0)], startPoint: .bottom, endPoint: .top)
                .ignoresSafeArea()
        )
    }
}
