

internal import SwiftUI

struct ExerciseDBRowView: View {
    let exercise: ExerciseDBItem
    var isSelectionMode: Bool = true 

    @Environment(ThemeManager.self) private var themeManager
    @StateObject private var colorManager = MuscleColorManager.shared
    @Environment(\.colorScheme) private var colorScheme 

    var body: some View {
        let rawMuscle = exercise.primaryMuscles?.first ?? "Other"
        let broadCategory = MuscleCategoryMapper.getBroadCategory(for: rawMuscle)
        let muscleColor = colorManager.getColor(for: broadCategory)

        HStack(spacing: 16) {

            Circle()
                .fill(muscleColor)
                .frame(width: 14, height: 14)
                .shadow(color: muscleColor.opacity(0.8), radius: 5)

            Text(LocalizationHelper.shared.translateName(exercise.name))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(colorScheme == .dark ? .white : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer()

            if isSelectionMode {
                Image(systemName: "plus.circle")
                    .font(.title2)
                    .foregroundStyle(themeManager.current.primaryAccent)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.3))
            }
        }
        .padding()

        .background(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color(UIColor.secondarySystemGroupedBackground)), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(LinearGradient(colors: [colorScheme == .dark ? .white.opacity(0.3) : .black.opacity(0.1), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 5, x: 0, y: 2)
    }
}
