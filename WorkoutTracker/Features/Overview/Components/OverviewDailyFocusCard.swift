internal import SwiftUI

/// Compact sports-science teaser card for the daily workout recommendation.
/// Displays key kinetic target, preview exercises, and opens the full coaching sheet on tap.
struct OverviewDailyFocusCard: View {
    let report: BodyAnalysisReport
    let onTapDetail: () -> Void
    let onGoToWorkout: () -> Void

    init(
        report: BodyAnalysisReport,
        onTapDetail: @escaping () -> Void,
        onGoToWorkout: @escaping () -> Void
    ) {
        self.report = report
        self.onTapDetail = onTapDetail
        self.onGoToWorkout = onGoToWorkout
    }

    private var advice: NextWorkoutAdvice {
        report.nextWorkoutAdvice
    }

    private var cleanSplitTitle: String {
        advice.recommendedSplitTitle.replacingOccurrences(of: "Совет на следующую сессию: ", with: "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // MARK: - Header
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PastelTheme.pastelOat)
                        .frame(width: 28, height: 28)
                        .background(PastelTheme.cardSurfaceSubtle)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(PastelTheme.cardBorder, lineWidth: 1))

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Совет на тренировку")
                            .font(.headline)
                            .foregroundStyle(PastelTheme.textPrimary)

                        Text("Анализ восстановления и кинетической цепи")
                            .font(.caption2)
                            .foregroundStyle(PastelTheme.textSecondary)
                    }
                }

                Spacer()

                HStack(spacing: 5) {
                    Circle()
                        .fill(PastelTheme.pastelSage)
                        .frame(width: 6, height: 6)

                    Text("Физиология")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(PastelTheme.pastelSage)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(PastelTheme.pastelSage.opacity(0.12))
                .clipShape(Capsule())
            }

            // MARK: - Recommended Target Split & Rationale Preview
            VStack(alignment: .leading, spacing: 5) {
                Text(cleanSplitTitle)
                    .font(.subheadline.bold())
                    .foregroundStyle(PastelTheme.pastelOat)

                Text(advice.physiologicalRationale)
                    .font(.caption)
                    .lineLimit(2)
                    .lineSpacing(2)
                    .foregroundStyle(PastelTheme.textSecondary)
            }

            // MARK: - Recommended Exercises Preview Chips
            if !advice.recommendedExercises.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(advice.recommendedExercises.prefix(4), id: \.self) { ex in
                            Text(ex)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(PastelTheme.textPrimary)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(PastelTheme.cardSurfaceSubtle)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1)
                                )
                        }
                    }
                }
            }

            // MARK: - Actionable Teaser Button: Open Full Sheet
            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                onTapDetail()
            } label: {
                HStack {
                    HStack(spacing: 7) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PastelTheme.pastelOat)

                        Text("Подробный разбор и тактика")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PastelTheme.textPrimary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption2.bold())
                        .foregroundStyle(PastelTheme.pastelOat)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(PastelTheme.cardSurfaceSubtle)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(PastelTheme.cardBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .pastelCard(padding: 16)
    }
}
