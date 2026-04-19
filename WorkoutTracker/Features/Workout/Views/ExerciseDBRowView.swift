// ============================================================
// FILE: WorkoutTracker/Features/Workout/Views/ExerciseDBRowView.swift
// ============================================================

internal import SwiftUI

struct ExerciseDBRowView: View {
    let exercise: ExerciseDBItem
    var isSelectionMode: Bool = true // true для поиска (плюсик), false для каталога (стрелочка)
    
    @Environment(ThemeManager.self) private var themeManager
    @StateObject private var colorManager = MuscleColorManager.shared
    
    var body: some View {
        // ✅ ИСПРАВЛЕНИЕ: Берем конкретную мышцу и переводим в базовую группу (как в диаграмме)
        let rawMuscle = exercise.primaryMuscles?.first ?? "Other"
        let broadCategory = MuscleCategoryMapper.getBroadCategory(for: rawMuscle)
        let muscleColor = colorManager.getColor(for: broadCategory)
        
        HStack(spacing: 16) {
            // Светящаяся точка правильного цвета!
            Circle()
                .fill(muscleColor)
                .frame(width: 14, height: 14)
                .shadow(color: muscleColor.opacity(0.8), radius: 5)
            
            // Название упражнения
            Text(LocalizationHelper.shared.translateName(exercise.name))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Spacer()
            
            // Иконка действия
            if isSelectionMode {
                Image(systemName: "plus.circle")
                    .font(.title2)
                    .foregroundStyle(themeManager.current.primaryAccent)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(Color.white.opacity(0.3))
            }
        }
        .padding()
        // Стеклянная подложка
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
    }
}
