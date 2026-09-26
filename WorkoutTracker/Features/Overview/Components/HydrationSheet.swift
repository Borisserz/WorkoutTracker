internal import SwiftUI

/// Interactive sheet for hydration tracking, quick water logging, and sports-science recovery insights.
struct HydrationSheet: View {
    let waterLiters: Double
    let onAddWater: (Double) -> Void
    let onResetWater: () -> Void
    @Environment(\.dismiss) private var dismiss

    private let dailyGoalLiters: Double = 2.5

    private var progressFraction: Double {
        min(1.0, max(0.0, waterLiters / dailyGoalLiters))
    }

    private var percentageText: String {
        "\(Int(progressFraction * 100))%"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PastelTheme.canvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header Metric Card
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Intracellular Hydration")
                                    .font(.headline)
                                    .foregroundStyle(PastelTheme.textPrimary)

                                Text("Daily fluid & electrolyte retention")
                                    .font(.caption)
                                    .foregroundStyle(PastelTheme.textSecondary)
                            }

                            Spacer()

                            HStack(spacing: 6) {
                                Image(systemName: "drop.fill")
                                    .font(.caption)
                                    .foregroundStyle(PastelTheme.pastelSlate)

                                Text(waterLiters > 0 ? String(format: "%.1fL", waterLiters) : "0.0L")
                                    .font(.headline.bold())
                                    .foregroundStyle(PastelTheme.textPrimary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(PastelTheme.cardSurface)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1))
                        }

                        // Progress Bar Container
                        VStack(spacing: 8) {
                            HStack {
                                Text("Progress to 2.5L Goal")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(PastelTheme.textSecondary)

                                Spacer()

                                Text(percentageText)
                                    .font(.caption.bold())
                                    .foregroundStyle(PastelTheme.pastelSlate)
                            }

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(PastelTheme.cardSurfaceSubtle)

                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [PastelTheme.pastelSlate.opacity(0.8), PastelTheme.pastelSage],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: max(8, geo.size.width * CGFloat(progressFraction)))
                                }
                            }
                            .frame(height: 10)
                        }
                        .padding(14)
                        .background(PastelTheme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(PastelTheme.cardBorder, lineWidth: 1)
                        )

                        // Quick Log Buttons
                        VStack(alignment: .leading, spacing: 10) {
                            Text("QUICK LOG")
                                .font(.caption2.bold())
                                .tracking(1)
                                .foregroundStyle(PastelTheme.textTertiary)

                            HStack(spacing: 10) {
                                HydrationActionButton(
                                    title: "+250 ml",
                                    subtitle: "Glass",
                                    icon: "cup.and.saucer.fill"
                                ) {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    onAddWater(0.25)
                                }

                                HydrationActionButton(
                                    title: "+500 ml",
                                    subtitle: "Bottle",
                                    icon: "waterbottle.fill"
                                ) {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    onAddWater(0.5)
                                }

                                HydrationActionButton(
                                    title: "Reset",
                                    subtitle: "Clear",
                                    icon: "arrow.counterclockwise"
                                ) {
                                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                                    onResetWater()
                                }
                            }
                        }

                        // Sports Science Recovery Rationale
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.caption)
                                    .foregroundStyle(PastelTheme.pastelSlate)

                                Text("Hydration & Strength Science")
                                    .font(.footnote.bold())
                                    .foregroundStyle(PastelTheme.textPrimary)
                            }

                            Text("Skeletal muscle is ~75% water. A dehydration deficit of just 2% body mass reduces isometric peak torque by up to 10% and impairs muscular endurance.")
                                .font(.caption)
                                .lineSpacing(3)
                                .foregroundStyle(PastelTheme.textSecondary)

                            Text("Adequate intra-cellular volume protects spinal discs during axial loading and promotes rapid fascia rehydration after heavy sessions.")
                                .font(.caption)
                                .lineSpacing(3)
                                .foregroundStyle(PastelTheme.textSecondary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PastelTheme.cardSurfaceSubtle)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(PastelTheme.cardBorder, lineWidth: 1)
                        )
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Hydration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
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

private struct HydrationActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(PastelTheme.pastelSlate)

                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(PastelTheme.textPrimary)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(PastelTheme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(PastelTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
