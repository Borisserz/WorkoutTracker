internal import SwiftUI

/// Sports-science sheet explaining cardiovascular recovery, heart rate zones, and autonomic readiness.
struct PulseExplanationSheet: View {
    let heartRate: Double
    let timeAgoText: String
    @Environment(\.dismiss) private var dismiss

    private var bpmValue: Int {
        heartRate > 0 ? Int(heartRate) : 62
    }

    private var recoveryCategory: (title: String, description: String, color: Color) {
        if bpmValue < 60 {
            return (
                "Athletic Efficiency",
                "Strong vagal tone and higher stroke volume. Neural recovery is optimal for maximal strength and power output.",
                PastelTheme.pastelSage
            )
        } else if bpmValue <= 75 {
            return (
                "Optimal Baseline",
                "Resting cardiovascular strain is well-balanced. Safe to train with standard progressive overload.",
                PastelTheme.pastelSage
            )
        } else if bpmValue <= 85 {
            return (
                "Mild Elevation",
                "Slight sympathetic dominance detected. Ensure adequate pre-workout hydration and take longer rest intervals between sets.",
                PastelTheme.pastelAmber
            )
        } else {
            return (
                "Cardiovascular Fatigue",
                "Heart rate indicates heightened systemic stress or incomplete tissue recovery. Prioritize active recovery or light volume.",
                PastelTheme.pastelPeach
            )
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PastelTheme.canvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Header Metric Card
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Cardiovascular Pulse")
                                    .font(.headline)
                                    .foregroundStyle(PastelTheme.textPrimary)

                                Text("Resting heart rate & recovery biomarker")
                                    .font(.caption)
                                    .foregroundStyle(PastelTheme.textSecondary)
                            }

                            Spacer()

                            HStack(spacing: 6) {
                                Image(systemName: "heart.fill")
                                    .font(.caption)
                                    .foregroundStyle(PastelTheme.pastelSage)

                                Text("\(bpmValue) bpm")
                                    .font(.headline.bold())
                                    .foregroundStyle(PastelTheme.pastelSage)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(PastelTheme.cardSurface)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1))
                        }

                        // Readiness Evaluation Box
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(recoveryCategory.color)
                                    .frame(width: 8, height: 8)

                                Text("Status: \(recoveryCategory.title)")
                                    .font(.footnote.bold())
                                    .foregroundStyle(recoveryCategory.color)
                            }

                            Text(recoveryCategory.description)
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

                        // Cardiovascular Training Zones
                        VStack(alignment: .leading, spacing: 10) {
                            Text("TRAINING TARGET ZONES")
                                .font(.caption2.bold())
                                .tracking(1)
                                .foregroundStyle(PastelTheme.textTertiary)

                            VStack(spacing: 8) {
                                ZoneRowView(
                                    zoneNumber: "Z1",
                                    title: "Active Recovery",
                                    rangeText: "50–60% Max HR",
                                    color: PastelTheme.pastelSlate
                                )
                                ZoneRowView(
                                    zoneNumber: "Z2",
                                    title: "Aerobic Base / Mitochondria",
                                    rangeText: "60–70% Max HR",
                                    color: PastelTheme.pastelSage
                                )
                                ZoneRowView(
                                    zoneNumber: "Z3",
                                    title: "Hypertrophy & Work Capacity",
                                    rangeText: "70–85% Max HR",
                                    color: PastelTheme.pastelAmber
                                )
                                ZoneRowView(
                                    zoneNumber: "Z4",
                                    title: "Anaerobic / Peak Neural Output",
                                    rangeText: "85–100% Max HR",
                                    color: PastelTheme.pastelPeach
                                )
                            }
                            .padding(12)
                            .background(PastelTheme.cardSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
                            )
                        }

                        // HealthKit Live Sync indicator
                        HStack(spacing: 8) {
                            Circle()
                                .fill(PastelTheme.pastelSage)
                                .frame(width: 6, height: 6)

                            Text(timeAgoText.isEmpty || timeAgoText == "No data" ? "Apple Watch / HealthKit Live Sync" : "HealthKit Sync • \(timeAgoText)")
                                .font(.caption2)
                                .foregroundStyle(PastelTheme.textTertiary)
                        }
                        .padding(.top, 4)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Pulse & Recovery")
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

private struct ZoneRowView: View {
    let zoneNumber: String
    let title: String
    let rangeText: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Text(zoneNumber)
                .font(.caption2.bold())
                .foregroundStyle(PastelTheme.textPrimary)
                .frame(width: 26, height: 22)
                .background(color.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(PastelTheme.textPrimary)

            Spacer()

            Text(rangeText)
                .font(.caption2)
                .foregroundStyle(PastelTheme.textTertiary)
        }
    }
}
