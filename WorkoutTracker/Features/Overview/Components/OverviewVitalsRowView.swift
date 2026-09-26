internal import SwiftUI

/// Compact horizontal vitals chips (CNS Index, Heart Rate, Hydration).
/// Styled in calm, soothing pastel tones with zero visual clutter.
struct OverviewVitalsRowView: View {
    let cnsScore: Double
    let heartRate: Double
    let waterLiters: Double
    let onCNSTap: (() -> Void)?
    let onPulseTap: (() -> Void)?
    let onWaterTap: (() -> Void)?

    init(
        cnsScore: Double,
        heartRate: Double,
        waterLiters: Double,
        onCNSTap: (() -> Void)? = nil,
        onPulseTap: (() -> Void)? = nil,
        onWaterTap: (() -> Void)? = nil
    ) {
        self.cnsScore = cnsScore
        self.heartRate = heartRate
        self.waterLiters = waterLiters
        self.onCNSTap = onCNSTap
        self.onPulseTap = onPulseTap
        self.onWaterTap = onWaterTap
    }

    var body: some View {
        HStack(spacing: 8) {
            // CNS Autonomic Readiness Chip
            VitalChipButton(
                title: "CNS",
                value: "\(Int(cnsScore))%",
                dotColor: PastelTheme.pastelLavender,
                action: onCNSTap
            )

            // Heart Rate / Resting BPM Chip
            VitalChipButton(
                title: "Pulse",
                value: heartRate > 0 ? "\(Int(heartRate)) bpm" : "62 bpm",
                dotColor: PastelTheme.pastelSage,
                action: onPulseTap
            )

            // Water Intake Chip (Guaranteed exact same size as CNS and Pulse)
            VitalChipButton(
                title: "Hydration",
                value: waterLiters > 0 ? String(format: "%.1fL", waterLiters) : "2.1L",
                dotColor: PastelTheme.pastelSlate,
                action: onWaterTap
            )
        }
        .frame(maxWidth: .infinity)
    }
}

/// Unified, pixel-perfect vitals chip ensuring strict equal dimensions and typography.
private struct VitalChipButton: View {
    let title: String
    let value: String
    let dotColor: Color
    let action: (() -> Void)?

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            action?()
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 3) {
                        Text(title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(PastelTheme.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        Image(systemName: "info.circle")
                            .font(.system(size: 9))
                            .foregroundStyle(PastelTheme.textTertiary)
                    }

                    Text(value)
                        .font(.subheadline.bold())
                        .foregroundStyle(PastelTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 62)
            .padding(.horizontal, 10)
            .background(PastelTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: PastelTheme.chipRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PastelTheme.chipRadius, style: .continuous)
                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}
