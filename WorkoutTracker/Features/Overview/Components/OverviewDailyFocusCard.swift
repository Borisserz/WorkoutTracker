internal import SwiftUI

/// Sports-science coach advisory card for the upcoming workout session.
/// Formed through physiological analysis of recently fatigued muscles vs restored kinetic chains.
struct OverviewDailyFocusCard: View {
    let report: BodyAnalysisReport
    let onGoToWorkout: () -> Void
    let onOpenCatalog: () -> Void

    init(
        report: BodyAnalysisReport,
        onGoToWorkout: @escaping () -> Void,
        onOpenCatalog: @escaping () -> Void
    ) {
        self.report = report
        self.onGoToWorkout = onGoToWorkout
        self.onOpenCatalog = onOpenCatalog
    }

    private var advice: NextWorkoutAdvice {
        report.nextWorkoutAdvice
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            
            // MARK: - Section Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Совет на следующую тренировку")
                        .font(.headline)
                        .foregroundStyle(PastelTheme.textPrimary)

                    Text("Анализ предыдущих нагрузок и готовности")
                        .font(.caption)
                        .foregroundStyle(PastelTheme.textSecondary)
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

            // MARK: - Main Advisory Card
            VStack(alignment: .leading, spacing: 14) {
                
                // 1. Fatigue Context / Previous Muscle Strain Analysis
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PastelTheme.pastelSlate)

                        Text("Анализ задействованных мышц")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PastelTheme.pastelSlate)
                    }

                    Text(advice.recentStrainSummary)
                        .font(.subheadline)
                        .lineSpacing(4)
                        .foregroundStyle(PastelTheme.textPrimary)
                }
                .padding(12)
                .background(PastelTheme.cardSurfaceSubtle)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(PastelTheme.cardBorder, lineWidth: 1)
                )

                // 2. Prescribed Target Split
                VStack(alignment: .leading, spacing: 6) {
                    Text(advice.recommendedSplitTitle)
                        .font(.subheadline.bold())
                        .foregroundStyle(PastelTheme.pastelOat)

                    Text(advice.physiologicalRationale)
                        .font(.caption)
                        .lineSpacing(3)
                        .foregroundStyle(PastelTheme.textSecondary)
                }

                // 3. Actionable Tactical Tips
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(advice.actionableTips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(PastelTheme.pastelSage)
                                .frame(width: 4, height: 4)
                                .padding(.top, 6)

                            Text(tip)
                                .font(.caption)
                                .foregroundStyle(PastelTheme.textSecondary)
                        }
                    }
                }

                // 4. Suggested Exercises Chips
                if !advice.recommendedExercises.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Рекомендуемые движения:")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(PastelTheme.textTertiary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(advice.recommendedExercises, id: \.self) { ex in
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
                }

                // 5. Caution / Sparing Notes
                if !advice.cautionNotes.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 13))
                            .foregroundStyle(PastelTheme.pastelAmber)
                            .padding(.top, 1)

                        Text(advice.cautionNotes)
                            .font(.caption)
                            .foregroundStyle(PastelTheme.textSecondary)
                            .lineLimit(2)
                    }
                    .padding(10)
                    .background(PastelTheme.pastelAmber.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(PastelTheme.pastelAmber.opacity(0.2), lineWidth: 1)
                    )
                }

                // Divider line
                Rectangle()
                    .fill(PastelTheme.cardBorder)
                    .frame(height: 1)
                    .padding(.vertical, 2)

                // Actions: Primary Go to Workout + Secondary Catalog
                HStack(spacing: 12) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onGoToWorkout()
                    } label: {
                        HStack(spacing: 8) {
                            Text("Перейти к тренировкам")
                                .font(.subheadline.bold())
                            Image(systemName: "arrow.right")
                                .font(.caption.bold())
                        }
                        .foregroundStyle(PastelTheme.textOnOat)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(PastelTheme.pastelOat)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onOpenCatalog()
                    } label: {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(PastelTheme.pastelOat)
                            .frame(width: 44, height: 44)
                            .background(PastelTheme.cardSurfaceSubtle)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .pastelCard(padding: 16)
        }
    }
}
