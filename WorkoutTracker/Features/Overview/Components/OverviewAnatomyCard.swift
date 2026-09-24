internal import SwiftUI

/// Centerpiece interactive anatomical card displaying muscle recovery readiness.
/// Includes Front/Back toggle, interactive muscle tap with live tooltips,
/// and the primary full-width 'Body Analysis' call-to-action button.
struct OverviewAnatomyCard: View {
    @Binding var isFrontView: Bool
    let cnsScore: Double
    let recoveryDict: [String: Int]
    let userGender: String
    let isLocked: Bool
    let onBodyAnalysisTap: () -> Void
    let onSettingsTap: () -> Void

    @State private var selectedMuscleName: String? = nil
    @State private var selectedMusclePct: Int = 100

    init(
        isFrontView: Binding<Bool>,
        cnsScore: Double,
        recoveryDict: [String: Int],
        userGender: String,
        isLocked: Bool,
        onBodyAnalysisTap: @escaping () -> Void,
        onSettingsTap: @escaping () -> Void
    ) {
        self._isFrontView = isFrontView
        self.cnsScore = cnsScore
        self.recoveryDict = recoveryDict
        self.userGender = userGender
        self.isLocked = isLocked
        self.onBodyAnalysisTap = onBodyAnalysisTap
        self.onSettingsTap = onSettingsTap
    }

    private var averageReadiness: Int {
        guard !recoveryDict.isEmpty else { return 100 }
        let sum = recoveryDict.values.reduce(0, +)
        return sum / recoveryDict.count
    }

    var body: some View {
        VStack(spacing: 16) {
            
            // MARK: - Header & Front / Back Toggle
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Muscle Readiness & Anatomy")
                        .font(.headline)
                        .foregroundStyle(PastelTheme.textPrimary)

                    Text("\(averageReadiness)% Systemic Readiness")
                        .font(.caption)
                        .foregroundStyle(PastelTheme.pastelSage)
                }

                Spacer()

                // Minimalist Pastel Segmented Toggle
                HStack(spacing: 0) {
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            isFrontView = true
                            selectedMuscleName = nil
                        }
                    } label: {
                        Text("Front")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isFrontView ? PastelTheme.textOnOat : PastelTheme.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(isFrontView ? PastelTheme.pastelOat : Color.clear)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            isFrontView = false
                            selectedMuscleName = nil
                        }
                    } label: {
                        Text("Back")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(!isFrontView ? PastelTheme.textOnOat : PastelTheme.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(!isFrontView ? PastelTheme.pastelOat : Color.clear)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(3)
                .background(PastelTheme.cardSurfaceSubtle)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1))
            }

            // MARK: - Interactive Body Silhouette
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(PastelTheme.anatomyBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(PastelTheme.cardBorder, lineWidth: 1)
                    )

                BodyHeatmapView(
                    muscleIntensities: recoveryDict,
                    isRecoveryMode: true,
                    isCompactMode: true,
                    defaultToBack: !isFrontView,
                    userGender: userGender,
                    showLabels: false,
                    onMuscleTapped: { muscle, pct in
                        selectedMuscleName = MuscleDisplayHelper.getDisplayName(for: muscle.slug)
                        selectedMusclePct = pct
                    }
                )
                .frame(height: 380)
                .scaleEffect(1.02)
                .clipped()
                .blur(radius: isLocked ? 10 : 0)
                .disabled(isLocked)

                // Selected Muscle Floating Tooltip
                if let name = selectedMuscleName, !isLocked {
                    VStack {
                        HStack {
                            Spacer()
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(selectedMusclePct >= 80 ? PastelTheme.pastelSage : (selectedMusclePct >= 55 ? PastelTheme.pastelAmber : PastelTheme.pastelPeach))
                                    .frame(width: 8, height: 8)

                                Text("\(name): \(selectedMusclePct)% Ready")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(PastelTheme.textPrimary)

                                Button {
                                    withAnimation { selectedMuscleName = nil }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(PastelTheme.textTertiary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(PastelTheme.cardSurface)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(PastelTheme.pastelOat.opacity(0.3), lineWidth: 1))
                            .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
                            .transition(.scale.combined(with: .opacity))
                        }
                        .padding(12)
                        Spacer()
                    }
                }

                // Locked State Overlay for Beginners
                if isLocked {
                    VStack(spacing: 8) {
                        Image(systemName: "figure.mind.and.body")
                            .font(.system(size: 32))
                            .foregroundStyle(PastelTheme.pastelSlate)

                        Text("Anatomy Locked")
                            .font(.subheadline.bold())
                            .foregroundStyle(PastelTheme.textPrimary)

                        Text("Complete your first workout to activate live muscle recovery tracking.")
                            .font(.caption)
                            .foregroundStyle(PastelTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                    }
                    .padding(20)
                    .background(PastelTheme.cardSurface.opacity(0.92))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(PastelTheme.cardBorder, lineWidth: 1))
                    .padding(.horizontal, 20)
                }
            }
            .frame(height: 380)

            // MARK: - Primary Action: Body Analysis CTA Button
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onBodyAnalysisTap()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Body Analysis")
                        .font(.body.weight(.semibold))
                }
                .foregroundStyle(PastelTheme.textOnOat)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(PastelTheme.pastelOat)
                .clipShape(RoundedRectangle(cornerRadius: PastelTheme.buttonRadius, style: .continuous))
                .shadow(color: PastelTheme.pastelOat.opacity(0.12), radius: 10, y: 3)
            }
            .buttonStyle(.plain)
        }
        .pastelCard(padding: 16)
    }
}
