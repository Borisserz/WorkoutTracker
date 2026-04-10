internal import SwiftUI

struct ExerciseDBRowView: View {
    let exercise: ExerciseDBItem
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(equipmentColor.opacity(0.15))
                    .frame(width: 54, height: 54)
                
                if UIImage(named: equipmentIcon) != nil {
                    // 1. Отрисовка ВАШИХ кастомных картинок из Assets
                    Image(equipmentIcon)
                        .renderingMode(.template) // Обязательно для перекраски
                        .resizable()
                        .scaledToFit()
                        // 👇 Используем новую переменную для размера
                        .frame(width: iconSize, height: iconSize)
                        .foregroundColor(equipmentColor)
                } else {
                    // 2. Отрисовка СИСТЕМНЫХ SF Symbols (если картинка вдруг не найдется)
                    Image(systemName: equipmentIcon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(equipmentColor)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(LocalizationHelper.shared.translateName(exercise.name))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    if let level = exercise.level {
                        tagView(text: level.capitalized, icon: levelIcon(level), color: levelColor(level))
                    }
                    if let primary = exercise.primaryMuscles?.first {
                        tagView(text: primary.capitalized, icon: "figure.strengthtraining.traditional", color: .blue)
                    }
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundColor(Color(UIColor.tertiaryLabel))
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.primary.opacity(0.05), lineWidth: 1))
        .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 3)
    }
    
    private func tagView(text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            
            Text(LocalizedStringKey(text))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .lineLimit(1)            // 👈 Запрещаем перенос на новую строку
                .minimumScaleFactor(0.7) // 👈 Разрешаем тексту сжаться до 70% от оригинала, если не влезает
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
    
    // MARK: - Иконки и Цвета
    
    // 👇 НОВАЯ ПЕРЕМЕННАЯ: Удобное управление размерами кастомных иконок
    private var iconSize: CGFloat {
        switch equipmentIcon {
        case "person-standing":
            return 44 // Размер для человечка
        case "barbell-2":
            return 44 // Размер для штанги (можете сделать 40 или 46, если нужно)
        default:
            return 30 // Стандартный размер для всех остальных (гантели, тренажеры и т.д.)
        }
    }
    
    private var equipmentIcon: String {
        let eq = exercise.equipment?.lowercased() ?? "body only"
        
        if eq.contains("barbell") { return "barbell-2" }
        if eq.contains("dumbbell") { return "dumbbell" }
        if eq.contains("machine") || eq.contains("cable") { return "gym" }
        if eq.contains("kettlebell") { return "kettlebell" }
        if eq.contains("band") { return "fitness" }
        if eq.contains("ball") { return "ball" }
        if eq.contains("foam roll") { return "matress" }
        
        // Если ничего не подошло (свой вес)
        return "person-standing"
    }
     
    private var equipmentColor: Color {
        let eq = exercise.equipment?.lowercased() ?? "bodyweight"
        
        if eq.contains("barbell") { return .blue }
        if eq.contains("dumbbell") { return .cyan }
        if eq.contains("machine") || eq.contains("cable") { return .purple }
        if eq.contains("kettlebell") { return .orange }
        if eq.contains("band") { return .pink }
        if eq.contains("ball") { return .yellow }
        if eq.contains("foam roll") { return .red }
        
        return .green // Свой вес
    }
    
    private func levelColor(_ level: String) -> Color {
        let lvl = level.lowercased()
        if lvl == "beginner" { return .green }
        if lvl == "intermediate" { return .orange }
        if lvl == "expert" || lvl == "advanced" { return .red }
        return .gray
    }
    
    private func levelIcon(_ level: String) -> String {
        let lvl = level.lowercased()
        if lvl == "beginner" { return "1.circle.fill" }
        if lvl == "intermediate" { return "2.circle.fill" }
        return "3.circle.fill"
    }
}
