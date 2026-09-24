internal import SwiftUI

/// Editorial daily training recommendation card derived from physiological readiness.
/// Replaces static 'top exercises' with an actionable, intelligent training focus for the day.
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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            
            // MARK: - Section Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today's Focus")
                        .font(.headline)
                        .foregroundStyle(PastelTheme.textPrimary)

                    Text("Optimal split based on recovery")
                        .font(.caption)
                        .foregroundStyle(PastelTheme.textSecondary)
                }

                Spacer()

                HStack(spacing: 5) {
                    Circle()
                        .fill(PastelTheme.pastelSage)
                        .frame(width: 6, height: 6)

                    Text("Live Split")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(PastelTheme.pastelSage)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(PastelTheme.pastelSage.opacity(0.12))
                .clipShape(Capsule())
            }

            // MARK: - Main Recommendation Card
            VStack(alignment: .leading, spacing: 14) {
                
                // Target Title & Icon
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(PastelTheme.cardSurfaceSubtle)
                            .frame(width: 42, height: 42)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
                            )

                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 20))
                            .foregroundStyle(PastelTheme.pastelOat)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(report.recommendedTargetTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PastelTheme.textPrimary)

                        Text("Primed muscle tissue with low residual fatigue")
                            .font(.caption)
                            .foregroundStyle(PastelTheme.textSecondary)
                    }
                }

                // Prime Muscle Chips
                if !report.primeMuscles.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(report.primeMuscles.prefix(4)) { item in
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(PastelTheme.pastelSage)
                                        .frame(width: 5, height: 5)

                                    Text(item.name)
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(PastelTheme.textPrimary)

                                    Text("\(item.percentage)%")
                                        .font(.caption2.bold())
                                        .foregroundStyle(PastelTheme.pastelSage)
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(PastelTheme.cardSurfaceSubtle)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1))
                            }
                        }
                    }
                }

                // Restriction / Caution Note
                if !report.recommendedRestrictions.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13))
                            .foregroundStyle(PastelTheme.pastelAmber)
                            .padding(.top, 1)

                        Text(report.recommendedRestrictions)
                            .font(.caption)
                            .foregroundStyle(PastelTheme.textSecondary)
                            .lineLimit(2)
                    }
                    .padding(10)
                    .background(PastelTheme.cardSurfaceSubtle.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                            Text("Open Workout Plan")
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
