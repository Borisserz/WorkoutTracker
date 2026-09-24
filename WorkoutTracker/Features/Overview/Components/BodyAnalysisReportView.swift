internal import SwiftUI

/// Deep physiological and neuromuscular readiness report.
/// Sports-science editorial design with calm pastel tones and zero emojis.
struct BodyAnalysisReportView: View {
    let report: BodyAnalysisReport
    @Environment(\.dismiss) private var dismiss

    init(report: BodyAnalysisReport) {
        self.report = report
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PastelTheme.canvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // MARK: - Executive Assessment
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Executive Assessment")
                                    .font(.headline)
                                    .foregroundStyle(PastelTheme.textPrimary)
                                Spacer()
                                Text("\(report.overallReadiness)% Ready")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(PastelTheme.pastelSage)
                            }

                            Text(report.executiveAssessment)
                                .font(.subheadline)
                                .lineSpacing(5)
                                .foregroundStyle(PastelTheme.textSecondary)
                        }
                        .pastelCard()

                        // MARK: - Recommended Focus Today
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recommended Focus Today")
                                .font(.headline)
                                .foregroundStyle(PastelTheme.textPrimary)

                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top, spacing: 10) {
                                    Circle()
                                        .fill(PastelTheme.pastelSage)
                                        .frame(width: 8, height: 8)
                                        .padding(.top, 5)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Target Protocol")
                                            .font(.caption)
                                            .foregroundStyle(PastelTheme.textTertiary)
                                        Text(report.recommendedTargetTitle)
                                            .font(.subheadline.bold())
                                            .foregroundStyle(PastelTheme.textPrimary)
                                    }
                                }

                                Divider()
                                    .background(PastelTheme.separator)

                                HStack(alignment: .top, spacing: 10) {
                                    Circle()
                                        .fill(PastelTheme.pastelPeach)
                                        .frame(width: 8, height: 8)
                                        .padding(.top, 5)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Prescribed Restrictions")
                                            .font(.caption)
                                            .foregroundStyle(PastelTheme.textTertiary)
                                        Text(report.recommendedRestrictions)
                                            .font(.subheadline)
                                            .foregroundStyle(PastelTheme.textSecondary)
                                    }
                                }
                            }
                        }
                        .padding(18)
                        .background(PastelTheme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: PastelTheme.cardRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: PastelTheme.cardRadius, style: .continuous)
                                .stroke(PastelTheme.pastelOat.opacity(0.25), lineWidth: 1.2)
                        )

                        // MARK: - Two-Column Muscle Split (Prime vs Recovery)
                        HStack(alignment: .top, spacing: 14) {
                            // Prime for Strain
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Prime for Strain")
                                    .font(.footnote.bold())
                                    .foregroundStyle(PastelTheme.textPrimary)

                                if report.primeMuscles.isEmpty {
                                    Text("All muscle groups currently undergoing rest.")
                                        .font(.caption)
                                        .foregroundStyle(PastelTheme.textTertiary)
                                } else {
                                    ForEach(report.primeMuscles) { item in
                                        HStack {
                                            Text(item.name)
                                                .font(.caption.weight(.medium))
                                                .foregroundStyle(PastelTheme.textPrimary)
                                            Spacer()
                                            Text("\(item.percentage)%")
                                                .font(.caption.bold())
                                                .foregroundStyle(PastelTheme.textOnOat)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(PastelTheme.pastelSage)
                                                .clipShape(Capsule())
                                        }
                                        .padding(10)
                                        .background(PastelTheme.cardSurfaceSubtle)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .pastelCard(padding: 14)

                            // Recovery Required
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Recovery Required")
                                    .font(.footnote.bold())
                                    .foregroundStyle(PastelTheme.textPrimary)

                                if report.recoveringMuscles.isEmpty {
                                    Text("Zero accumulated fatigue across tracked groups.")
                                        .font(.caption)
                                        .foregroundStyle(PastelTheme.textTertiary)
                                } else {
                                    ForEach(report.recoveringMuscles) { item in
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(item.name)
                                                    .font(.caption.weight(.medium))
                                                    .foregroundStyle(PastelTheme.textPrimary)
                                                Spacer()
                                                Text("\(item.percentage)%")
                                                    .font(.caption.bold())
                                                    .foregroundStyle(PastelTheme.textOnOat)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(PastelTheme.pastelPeach)
                                                    .clipShape(Capsule())
                                            }
                                            Text("\(item.hoursRemaining)h remaining")
                                                .font(.caption2)
                                                .foregroundStyle(PastelTheme.textTertiary)
                                        }
                                        .padding(10)
                                        .background(PastelTheme.cardSurfaceSubtle)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .pastelCard(padding: 14)
                        }

                        // MARK: - Autonomic Status Footer
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Autonomic Evaluation")
                                .font(.footnote.bold())
                                .foregroundStyle(PastelTheme.textSecondary)

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Neurological State")
                                        .font(.caption2)
                                        .foregroundStyle(PastelTheme.textTertiary)
                                    Text(report.cnsStatusTitle)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(PastelTheme.pastelLavender)
                                }
                                Spacer()
                                Text("Updated \(report.date.formatted(date: .omitted, time: .shortened))")
                                    .font(.caption2)
                                    .foregroundStyle(PastelTheme.textTertiary)
                            }
                        }
                        .pastelCard(padding: 14)

                    }
                    .padding(20)
                }
            }
            .navigationTitle("Body Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .font(.body.weight(.medium))
                    .foregroundStyle(PastelTheme.pastelOat)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
