internal import SwiftUI

/// Compact sports-science teaser card for the daily workout recommendation.
/// Features a framed inner block with accent indicator, highlighted typography, and quick sheet trigger.
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
        VStack(alignment: .leading, spacing: 14) {
            
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

            // MARK: - Highlighted Recommendation Frame / Inner Box
            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                onTapDetail()
            } label: {
                HStack(alignment: .top, spacing: 0) {
                    // Left Accent Indicator Bar (Sage Gradient)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [PastelTheme.pastelSage, PastelTheme.pastelSage.opacity(0.45)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 4)
                        .padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 9) {
                        // Title & Chevron
                        HStack(alignment: .center) {
                            Text(cleanSplitTitle)
                                .font(.subheadline.bold())
                                .foregroundStyle(PastelTheme.pastelOat)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption2.bold())
                                .foregroundStyle(PastelTheme.pastelOat.opacity(0.85))
                        }

                        // Rationale text
                        Text(advice.physiologicalRationale)
                            .font(.caption)
                            .lineLimit(2)
                            .lineSpacing(3)
                            .foregroundStyle(PastelTheme.textSecondary)

                        // Exercise preview chips inside the framed block
                        if !advice.recommendedExercises.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(advice.recommendedExercises.prefix(4), id: \.self) { ex in
                                        HStack(spacing: 5) {
                                            Circle()
                                                .fill(PastelTheme.pastelSage.opacity(0.8))
                                                .frame(width: 4, height: 4)

                                            Text(ex)
                                                .font(.caption2.weight(.medium))
                                                .foregroundStyle(PastelTheme.textPrimary)
                                        }
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 5)
                                        .background(PastelTheme.cardSurface)
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1)
                                        )
                                    }
                                }
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding(.leading, 12)
                    .padding(.trailing, 4)
                }
                .padding(14)
                .background(PastelTheme.cardSurfaceSubtle)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(PastelTheme.cardBorderFocused, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // MARK: - Actionable Teaser Button: Open Full Sheet
            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                onTapDetail()
            } label: {
                HStack {
                    HStack(spacing: 7) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PastelTheme.pastelSage)

                        Text("Подробный тактический разбор")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PastelTheme.textPrimary)
                    }

                    Spacer()

                    Text("Открыть")
                        .font(.caption2.bold())
                        .foregroundStyle(PastelTheme.pastelOat)

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PastelTheme.pastelOat)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(PastelTheme.cardSurfaceSubtle)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(PastelTheme.cardBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: PastelTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PastelTheme.cardRadius, style: .continuous)
                .stroke(PastelTheme.cardBorderFocused, lineWidth: 1)
        )
        .shadow(color: PastelTheme.pastelSage.opacity(0.04), radius: 10, y: 3)
    }
}
