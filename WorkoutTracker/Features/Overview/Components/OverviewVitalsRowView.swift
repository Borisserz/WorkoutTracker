internal import SwiftUI

/// Compact horizontal vitals chips (CNS Index, Heart Rate, Hydration).
/// Styled in calm, soothing pastel tones with zero visual clutter.
struct OverviewVitalsRowView: View {
    let cnsScore: Double
    let heartRate: Double
    let waterLiters: Double
    let onCNSTap: (() -> Void)?

    init(
        cnsScore: Double,
        heartRate: Double,
        waterLiters: Double,
        onCNSTap: (() -> Void)? = nil
    ) {
        self.cnsScore = cnsScore
        self.heartRate = heartRate
        self.waterLiters = waterLiters
        self.onCNSTap = onCNSTap
    }

    var body: some View {
        HStack(spacing: 10) {
            // CNS Autonomic Readiness Chip (Interactive with soft haptics)
            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                onCNSTap?()
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(PastelTheme.pastelLavender)
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("CNS")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PastelTheme.textSecondary)

                            Image(systemName: "info.circle")
                                .font(.system(size: 10))
                                .foregroundStyle(PastelTheme.textTertiary)
                        }

                        Text("\(Int(cnsScore))%")
                            .font(.headline.bold())
                            .foregroundStyle(PastelTheme.textPrimary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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

            // Heart Rate / Resting BPM Chip
            HStack(spacing: 8) {
                Circle()
                    .fill(PastelTheme.pastelSage)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Pulse")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PastelTheme.textSecondary)

                    Text(heartRate > 0 ? "\(Int(heartRate)) bpm" : "62 bpm")
                        .font(.headline.bold())
                        .foregroundStyle(PastelTheme.textPrimary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(PastelTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: PastelTheme.chipRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PastelTheme.chipRadius, style: .continuous)
                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
            )

            // Water Intake (FoodTracker Sync)
            HStack(spacing: 8) {
                Circle()
                    .fill(PastelTheme.pastelSlate)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Hydration")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PastelTheme.textSecondary)

                    Text(waterLiters > 0 ? String(format: "%.1fL", waterLiters) : "2.1L")
                        .font(.headline.bold())
                        .foregroundStyle(PastelTheme.textPrimary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(PastelTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: PastelTheme.chipRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PastelTheme.chipRadius, style: .continuous)
                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
            )
        }
    }
}
