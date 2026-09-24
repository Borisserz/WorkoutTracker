internal import SwiftUI

/// Centerpiece interactive anatomical card displaying muscle recovery readiness.
/// Includes Front/Back toggle, interactive muscle tap with inline detail card,
/// pastel legend bar, soft haptics, and the primary 'Body Analysis' CTA.
struct OverviewAnatomyCard: View {
    @Binding var isFrontView: Bool
    let cnsScore: Double
    let recoveryDict: [String: Int]
    let userGender: String
    let isLocked: Bool
    let recentWorkouts: [Workout]
    let onBodyAnalysisTap: () -> Void
    let onSettingsTap: () -> Void

    @State private var selectedMuscleSlug: String? = nil
    @State private var selectedMuscleName: String? = nil
    @State private var selectedMusclePct: Int = 100

    init(
        isFrontView: Binding<Bool>,
        cnsScore: Double,
        recoveryDict: [String: Int],
        userGender: String,
        isLocked: Bool,
        recentWorkouts: [Workout] = [],
        onBodyAnalysisTap: @escaping () -> Void,
        onSettingsTap: @escaping () -> Void
    ) {
        self._isFrontView = isFrontView
        self.cnsScore = cnsScore
        self.recoveryDict = recoveryDict
        self.userGender = userGender
        self.isLocked = isLocked
        self.recentWorkouts = recentWorkouts
        self.onBodyAnalysisTap = onBodyAnalysisTap
        self.onSettingsTap = onSettingsTap
    }

    private var averageReadiness: Int {
        guard !recoveryDict.isEmpty else { return 100 }
        let sum = recoveryDict.values.reduce(0, +)
        return sum / recoveryDict.count
    }

    private func muscleColor(for pct: Int) -> Color {
        if pct >= 80 {
            return PastelTheme.pastelSage
        } else if pct >= 55 {
            return PastelTheme.pastelAmber
        } else {
            return PastelTheme.pastelPeach
        }
    }

    private var selectedMuscleDetailText: String {
        guard let slug = selectedMuscleSlug else { return "" }
        let hoursRemaining = max(0, Int(Double(100 - selectedMusclePct) / 100.0 * 48.0))
        
        // Find most recent exercise targeting this group
        var lastExerciseName: String? = nil
        for workout in recentWorkouts {
            for exercise in workout.exercises {
                let broadCategory = MuscleCategoryMapper.getBroadCategory(for: exercise.muscleGroup).lowercased()
                if broadCategory == slug || exercise.muscleGroup.lowercased().contains(slug) {
                    lastExerciseName = exercise.name
                    break
                }
            }
            if lastExerciseName != nil { break }
        }

        if selectedMusclePct >= 95 {
            return "Fully recovered · Primed for high volume training"
        } else if let exName = lastExerciseName {
            return "\(hoursRemaining)h until full recovery · Last hit by \(exName)"
        } else {
            return "\(hoursRemaining)h remaining until full cellular recovery"
        }
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

                // Minimalist Pastel Segmented Toggle with Soft Haptics
                HStack(spacing: 0) {
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            isFrontView = true
                            selectedMuscleName = nil
                            selectedMuscleSlug = nil
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
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            isFrontView = false
                            selectedMuscleName = nil
                            selectedMuscleSlug = nil
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
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedMuscleSlug = muscle.slug
                            selectedMuscleName = MuscleDisplayHelper.getDisplayName(for: muscle.slug)
                            selectedMusclePct = pct
                        }
                    }
                )
                .frame(height: 370)
                .scaleEffect(1.02)
                .clipped()
                .blur(radius: isLocked ? 10 : 0)
                .disabled(isLocked)

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
            .frame(height: 370)

            // MARK: - Inline Muscle Detail Card (When Muscle is Tapped)
            if let name = selectedMuscleName, !isLocked {
                HStack(alignment: .center, spacing: 12) {
                    Circle()
                        .fill(muscleColor(for: selectedMusclePct))
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(name)
                                .font(.subheadline.bold())
                                .foregroundStyle(PastelTheme.textPrimary)
                            Spacer()
                            Text("\(selectedMusclePct)%")
                                .font(.caption.bold())
                                .foregroundStyle(PastelTheme.textOnOat)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(muscleColor(for: selectedMusclePct))
                                .clipShape(Capsule())
                        }

                        Text(selectedMuscleDetailText)
                            .font(.caption)
                            .foregroundStyle(PastelTheme.textSecondary)
                            .lineLimit(2)
                    }

                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            selectedMuscleName = nil
                            selectedMuscleSlug = nil
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(PastelTheme.textTertiary)
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(PastelTheme.cardSurfaceSubtle)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(PastelTheme.cardBorder, lineWidth: 1)
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }

            // MARK: - Subtle Pastel Legend Bar
            HStack(spacing: 16) {
                HStack(spacing: 5) {
                    Circle().fill(PastelTheme.pastelSage).frame(width: 6, height: 6)
                    Text("Ready 80-100%").font(.system(size: 11)).foregroundStyle(PastelTheme.textTertiary)
                }
                HStack(spacing: 5) {
                    Circle().fill(PastelTheme.pastelAmber).frame(width: 6, height: 6)
                    Text("55-79%").font(.system(size: 11)).foregroundStyle(PastelTheme.textTertiary)
                }
                HStack(spacing: 5) {
                    Circle().fill(PastelTheme.pastelPeach).frame(width: 6, height: 6)
                    Text("<55% Fatigued").font(.system(size: 11)).foregroundStyle(PastelTheme.textTertiary)
                }
            }
            .padding(.top, 2)

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
