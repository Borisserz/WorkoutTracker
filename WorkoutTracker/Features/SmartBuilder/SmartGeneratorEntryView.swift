internal import SwiftUI

struct SmartGeneratorEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DashboardViewModel.self) private var dashboard
    @State private var vm = SmartGeneratorViewModel()
    @State private var selectedInfoPreset: PresetInfoItem? = nil

    var onWorkoutReady: ([ExerciseDTO]) -> Void

    struct PresetInfoItem: Identifiable {
        let id: String
        let title: String
        let reason: String
        let muscles: [String]
    }

    private var readyMuscles: [MuscleRecoveryStatus] {
        dashboard.recoveryStatus.filter { $0.recoveryPercentage >= 75 }
    }

    private var hasMeasuredRecovery: Bool {
        !dashboard.recoveryStatus.isEmpty
    }

    private var recoveredMuscleNames: String? {
        let ready = readyMuscles
        guard !ready.isEmpty else { return nil }
        return ready.prefix(3).map { localizedMuscleName($0.muscleGroup) }.joined(separator: ", ")
    }

    private func localizedMuscleName(_ raw: String) -> String {
        let lower = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch lower {
        case "neck": return String(localized: "Neck")
        case "deltoids", "shoulders": return String(localized: "Shoulders")
        case "upper-back", "upper back": return String(localized: "Upper back")
        case "lower-back", "lower back": return String(localized: "Lower back")
        case "lats": return String(localized: "Lats")
        case "trapezius", "traps": return String(localized: "Traps")
        case "chest": return String(localized: "Chest")
        case "biceps": return String(localized: "Biceps")
        case "triceps": return String(localized: "Triceps")
        case "forearm", "forearms", "hands", "arms": return String(localized: "Arms")
        case "abs", "core", "obliques": return String(localized: "Core")
        case "gluteal", "glutes": return String(localized: "Glutes")
        case "quadriceps", "quads": return String(localized: "Quads")
        case "hamstring", "hamstrings": return String(localized: "Hamstrings")
        case "legs": return String(localized: "Legs")
        case "calves": return String(localized: "Calves")
        default: return raw.capitalized
        }
    }

    /// Only recommend a preset when recovery data exists; never invent a “best” pick.
    private var recommendedPresetKey: String? {
        guard !readyMuscles.isEmpty else { return nil }
        let ready = readyMuscles.map { $0.muscleGroup.lowercased() }
        if ready.contains(where: { $0.contains("chest") || $0.contains("arm") }) {
            return "Quick Pump"
        } else if ready.contains(where: { $0.contains("leg") }) {
            return "Dumbbell Full Body"
        } else if ready.contains(where: { $0.contains("cardio") }) {
            return "Cardio Blast"
        }
        return "Quick Pump"
    }

    var body: some View {
        NavigationStack(path: $vm.path) {
            ZStack(alignment: .bottom) {
                PastelTheme.canvas.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        headerSection
                        recoveryCalloutBanner
                        quickPresetsSection
                        Spacer().frame(height: 100)
                    }
                    .padding(.top, 10)
                }

                bottomCustomBuilderBar

                if vm.isGenerating {
                    loadingOverlay
                }
            }
            .navigationTitle("Session of the day")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("wt.smartBuilder.root")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.shared.impact(.light)
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(PastelTheme.textSecondary, PastelTheme.cardSurfaceSubtle)
                    }
                    .accessibilityIdentifier("wt.smartBuilder.close")
                    .accessibilityLabel("Close")
                }
            }
            .navigationDestination(for: String.self) { route in
                switch route {
                case "MuscleSelection": MuscleSelectionView(vm: vm)
                case "Settings": GeneratorSettingsView(vm: vm)
                case "ResultView": GeneratedWorkoutResultView(vm: vm, onStart: { dtos in
                        dismiss()
                        onWorkoutReady(dtos)
                    })
                default: EmptyView()
                }
            }
            .sheet(item: $selectedInfoPreset) { item in
                presetInfoSheet(for: item)
                    .presentationDetents([.fraction(0.35)])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 6) {
            Text("Build your session")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(PastelTheme.textPrimary)
                .padding(.top, 14)

            Text("Pick a ready mode for your recovery, or build one yourself")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PastelTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
    }

    // MARK: - Recovery Callout (honest empty / measured)
    private var recoveryCalloutBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(PastelTheme.pastelSage.opacity(0.18))
                    .frame(width: 38, height: 38)
                    .overlay(Circle().stroke(PastelTheme.pastelSage.opacity(0.4), lineWidth: 1))

                Image(systemName: hasMeasuredRecovery && recoveredMuscleNames != nil ? "bolt.heart.fill" : "heart.text.square")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PastelTheme.pastelSage)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(recoveryTitle)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)

                    Spacer()

                    if recoveredMuscleNames != nil {
                        Text("Ready to Train")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(PastelTheme.pastelSage)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(PastelTheme.pastelSage.opacity(0.14))
                            .clipShape(Capsule())
                    }
                }

                Text(recoverySubtitle)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(PastelTheme.textSecondary)
                    .lineSpacing(2)
            }
        }
        .padding(14)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .accessibilityIdentifier("wt.smartBuilder.recovery")
    }

    private var recoveryTitle: String {
        if recoveredMuscleNames != nil {
            return String(localized: "Muscles recovered")
        }
        if hasMeasuredRecovery {
            return String(localized: "Still recovering")
        }
        return String(localized: "Recovery not measured")
    }

    private var recoverySubtitle: String {
        if let names = recoveredMuscleNames {
            return String(localized: "Fresh groups: \(names). A matching preset is highlighted below.")
        }
        if hasMeasuredRecovery {
            return String(localized: "No muscle groups are fully recovered yet. Pick any mode or build custom.")
        }
        return String(localized: "Train first or sync Health data to see recovery suggestions.")
    }

    // MARK: - Presets Grid
    private var quickPresetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick modes")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(PastelTheme.textPrimary)
                .padding(.horizontal, 18)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                presetCard(
                    title: "Quick Pump",
                    key: "Quick Pump",
                    icon: "bolt.fill",
                    accentColor: PastelTheme.pastelAmber,
                    desc: "Arms & chest · 20 min",
                    reason: "Short upper-body pump when chest and arms are recovered."
                ) {
                    vm.applyQuickPreset(name: "Quick Pump", muscles: ["Arms", "Chest"], duration: 20, equipment: .fullGym, historyCache: dashboard.lastPerformancesCache)
                }

                presetCard(
                    title: "Dumbbell Full Body",
                    key: "Dumbbell Full Body",
                    icon: "scalemass.fill",
                    accentColor: PastelTheme.pastelLavender,
                    desc: "Full body · 45 min",
                    reason: "Balanced dumbbell session across major groups."
                ) {
                    vm.applyQuickPreset(name: "Dumbbell Full Body", muscles: ["Chest", "Back", "Legs"], duration: 45, equipment: .dumbbellsOnly, historyCache: dashboard.lastPerformancesCache)
                }

                presetCard(
                    title: "Home Shred",
                    key: "Home Shred",
                    icon: "house.fill",
                    accentColor: PastelTheme.pastelSlate,
                    desc: "Bodyweight · 30 min",
                    reason: "No equipment — keep form and conditioning at home."
                ) {
                    vm.applyQuickPreset(name: "Home Shred", muscles: ["Chest", "Core", "Legs"], duration: 30, equipment: .bodyweight, historyCache: dashboard.lastPerformancesCache)
                }

                presetCard(
                    title: "Cardio Blast",
                    key: "Cardio Blast",
                    icon: "flame.fill",
                    accentColor: PastelTheme.pastelPeach,
                    desc: "Conditioning · 30 min",
                    reason: "Higher tempo work for cardio and core."
                ) {
                    vm.applyQuickPreset(name: "Cardio Blast", muscles: ["Cardio", "Core"], duration: 30, equipment: .bodyweight, historyCache: dashboard.lastPerformancesCache)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Individual Preset Card
    private func presetCard(
        title: String,
        key: String,
        icon: String,
        accentColor: Color,
        desc: String,
        reason: String,
        action: @escaping () -> Void
    ) -> some View {
        let isRecommended = (recommendedPresetKey == key)

        return ZStack(alignment: .topTrailing) {
            Button {
                HapticManager.shared.impact(.medium)
                action()
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        ZStack {
                            Circle()
                                .fill(accentColor.opacity(0.16))
                                .frame(width: 38, height: 38)
                                .overlay(Circle().stroke(accentColor.opacity(0.35), lineWidth: 1))

                            Image(systemName: icon)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(accentColor)
                        }

                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(PastelTheme.textPrimary)

                        Text(desc)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(isRecommended ? PastelTheme.pastelSage : PastelTheme.textSecondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                .padding(14)
                .background(PastelTheme.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isRecommended ? PastelTheme.pastelSage.opacity(0.85) : PastelTheme.cardBorder, lineWidth: isRecommended ? 1.5 : 1)
                )
            }
            .buttonStyle(.plain)

            if isRecommended {
                HStack(spacing: 3) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9, weight: .bold))
                    Text("Suggested")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                }
                .foregroundStyle(PastelTheme.textOnOat)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(PastelTheme.pastelSage)
                .clipShape(Capsule())
                .padding(10)
                .allowsHitTesting(false)
            } else {
                Button {
                    selectedInfoPreset = PresetInfoItem(id: key, title: title, reason: reason, muscles: [desc])
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(PastelTheme.textTertiary)
                        .padding(10)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Info Popover Sheet
    private func presetInfoSheet(for item: PresetInfoItem) -> some View {
        ZStack {
            PastelTheme.canvas.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(PastelTheme.cardSurfaceSubtle)
                            .frame(width: 36, height: 36)
                            .overlay(Circle().stroke(PastelTheme.cardBorder, lineWidth: 1))

                        Image(systemName: "sparkles")
                            .font(.system(size: 15))
                            .foregroundStyle(PastelTheme.pastelLavender)
                    }

                    Text(item.title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)

                    Spacer()
                }

                Text(item.reason)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PastelTheme.textSecondary)
                    .lineSpacing(3)

                Spacer()
            }
            .padding(20)
        }
    }

    // MARK: - Bottom Custom Builder Bar
    private var bottomCustomBuilderBar: some View {
        VStack {
            Button {
                HapticManager.shared.impact(.medium)
                vm.path.append("MuscleSelection")
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 16, weight: .bold))

                    Text("Custom builder")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundStyle(PastelTheme.textOnOat)
                .frame(maxWidth: .infinity)
                .frame(height: PastelTheme.ButtonMetrics.heroHeight)
                .background(PastelTheme.pastelOat)
                .clipShape(RoundedRectangle(cornerRadius: PastelTheme.ButtonMetrics.heroRadius, style: .continuous))
                .shadow(color: PastelTheme.pastelOat.opacity(0.2), radius: 10, y: 4)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("wt.smartBuilder.custom")
        }
        .padding(.bottom, 16)
    }

    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(PastelTheme.pastelOat)

                Text("Building your program...")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(PastelTheme.textPrimary)
            }
            .padding(28)
            .background(PastelTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 20)
        }
        .zIndex(100)
        .transition(.opacity)
    }
}
