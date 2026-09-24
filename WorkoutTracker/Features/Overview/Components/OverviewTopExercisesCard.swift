internal import SwiftUI

/// Minimalist horizontal cards displaying the user's most trained exercises.
struct OverviewTopExercisesCard: View {
    let topExercises: [ExerciseCountDTO]
    let onSeeAllTap: () -> Void
    let onExerciseTap: (String) -> Void

    init(
        topExercises: [ExerciseCountDTO],
        onSeeAllTap: @escaping () -> Void,
        onExerciseTap: @escaping (String) -> Void
    ) {
        self.topExercises = topExercises
        self.onSeeAllTap = onSeeAllTap
        self.onExerciseTap = onExerciseTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Top Exercises")
                    .font(.headline)
                    .foregroundStyle(PastelTheme.textPrimary)

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onSeeAllTap()
                } label: {
                    Text("ALL")
                        .font(.caption.bold())
                        .foregroundStyle(PastelTheme.pastelOat)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(PastelTheme.cardSurface)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            if topExercises.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.title3)
                        .foregroundStyle(PastelTheme.pastelSlate)

                    Text("Complete a workout to see top exercises")
                        .font(.subheadline)
                        .foregroundStyle(PastelTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .pastelCard(padding: 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(topExercises.prefix(5).enumerated()), id: \.offset) { index, item in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onExerciseTap(item.name)
                            } label: {
                                HStack(spacing: 10) {
                                    Text("\(index + 1)")
                                        .font(.caption.bold())
                                        .foregroundStyle(PastelTheme.pastelOat)
                                        .frame(width: 22, height: 22)
                                        .background(PastelTheme.cardSurfaceSubtle)
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(PastelTheme.textPrimary)
                                            .lineLimit(1)

                                        Text("\(item.count) sets logged")
                                            .font(.caption2)
                                            .foregroundStyle(PastelTheme.textSecondary)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(PastelTheme.cardSurface)
                                .clipShape(RoundedRectangle(cornerRadius: PastelTheme.chipRadius, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: PastelTheme.chipRadius, style: .continuous)
                                        .stroke(PastelTheme.cardBorder, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}
