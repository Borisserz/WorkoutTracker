internal import SwiftUI

struct SmartGeneratorEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DashboardViewModel.self) private var dashboard 
    @State private var vm = SmartGeneratorViewModel()
    @State private var selectedInfoPreset: PresetInfoItem? = nil

    var onWorkoutReady: ([ExerciseDTO]) -> Void

    struct PresetInfoItem: Identifiable {
        let id = UUID()
        let title: String
        let reason: String
        let muscles: [String]
    }

    private var recoveredMuscleNames: String {
        let ready = dashboard.recoveryStatus.filter { $0.recoveryPercentage >= 75 }
        if ready.isEmpty {
            return "Грудь, руки и плечи"
        }
        return ready.prefix(3).map { localizedMuscleName($0.muscleGroup) }.joined(separator: ", ")
    }

    private func localizedMuscleName(_ raw: String) -> String {
        let lower = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch lower {
        case "neck": return "Шея"
        case "deltoids", "shoulders": return "Плечи"
        case "upper-back", "upper back": return "Верх спины"
        case "lower-back", "lower back": return "Поясница"
        case "lats": return "Широчайшие"
        case "trapezius", "traps": return "Трапеции"
        case "chest": return "Грудь"
        case "biceps": return "Бицепс"
        case "triceps": return "Трицепс"
        case "forearm", "forearms", "hands", "arms": return "Руки"
        case "abs", "core", "obliques": return "Пресс и кор"
        case "gluteal", "glutes": return "Ягодицы"
        case "quadriceps", "quads": return "Квадрицепсы"
        case "hamstring", "hamstrings": return "Бицепс бедра"
        case "legs": return "Ноги"
        case "calves": return "Икры"
        default: return raw.capitalized
        }
    }

    private var recommendedPresetKey: String {
        let ready = dashboard.recoveryStatus.filter { $0.recoveryPercentage >= 75 }.map { $0.muscleGroup.lowercased() }
        if ready.contains(where: { $0.contains("chest") || $0.contains("arm") || $0.contains("груд") || $0.contains("рук") }) {
            return "Quick Pump"
        } else if ready.contains(where: { $0.contains("leg") || $0.contains("ног") }) {
            return "Dumbbell Full Body"
        } else if ready.contains(where: { $0.contains("cardio") || $0.contains("кардио") }) {
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
                        // 1. Header Section
                        headerSection

                        // 2. Smart Muscle Recovery Callout (Mini Popup / Badge)
                        recoveryCalloutBanner

                        // 3. Quick Presets Section with Recovery Recommendation Highlight
                        quickPresetsSection

                        Spacer().frame(height: 100)
                    }
                    .padding(.top, 10)
                }

                // 4. Hero Action: Custom Builder Button (Tier 1: 48pt, r=14, PastelOat)
                bottomCustomBuilderBar

                // 5. Loading Overlay
                if vm.isGenerating {
                    loadingOverlay
                }
            }
            .navigationTitle("Сессия дня")
            .navigationBarTitleDisplayMode(.inline)
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
            Text("Сборка тренировки")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(PastelTheme.textPrimary)
                .padding(.top, 14)

            Text("Выберите готовый режим под вашу готовность или соберите вручную")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PastelTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
    }

    // MARK: - Smart Muscle Recovery Callout Banner
    private var recoveryCalloutBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(PastelTheme.pastelSage.opacity(0.18))
                    .frame(width: 38, height: 38)
                    .overlay(Circle().stroke(PastelTheme.pastelSage.opacity(0.4), lineWidth: 1))

                Image(systemName: "bolt.heart.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PastelTheme.pastelSage)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Мышцы восстановились")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)

                    Spacer()

                    HStack(spacing: 4) {
                        Circle()
                            .fill(PastelTheme.pastelSage)
                            .frame(width: 5, height: 5)
                        Text("Готовы к росту")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(PastelTheme.pastelSage)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(PastelTheme.pastelSage.opacity(0.14))
                    .clipShape(Capsule())
                }

                Text("Свежие группы: \(recoveredMuscleNames). Рекомендуем режим с максимальным фокусом на эти мышцы:")
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
    }

    // MARK: - Presets Grid
    private var quickPresetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Быстрые режимы")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(PastelTheme.textPrimary)
                .padding(.horizontal, 18)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                // 1. Быстрый памп (Arms & Chest)
                presetCard(
                    title: "Быстрый памп",
                    key: "Quick Pump",
                    icon: "bolt.fill",
                    accentColor: PastelTheme.pastelAmber,
                    desc: "Руки и грудь • 20 мин",
                    reason: "Идеально подходит под ваше восстановление груди и трицепса."
                ) {
                    vm.applyQuickPreset(name: "Quick Pump", muscles: ["Arms", "Chest"], duration: 20, equipment: .fullGym, historyCache: dashboard.lastPerformancesCache)
                }

                // 2. С гантелями (Full Body)
                presetCard(
                    title: "С гантелями",
                    key: "Dumbbell Full Body",
                    icon: "scalemass.fill",
                    accentColor: PastelTheme.pastelLavender,
                    desc: "Всё тело • 45 мин",
                    reason: "Сбалансированная нагрузка для всего тела с гантелями."
                ) {
                    vm.applyQuickPreset(name: "Dumbbell Full Body", muscles: ["Chest", "Back", "Legs"], duration: 45, equipment: .dumbbellsOnly, historyCache: dashboard.lastPerformancesCache)
                }

                // 3. Домашняя (Bodyweight)
                presetCard(
                    title: "Домашний шред",
                    key: "Home Shred",
                    icon: "house.fill",
                    accentColor: PastelTheme.pastelSlate,
                    desc: "Свой вес • 30 мин",
                    reason: "Тренировка без железа для поддержания формы и тонуса."
                ) {
                    vm.applyQuickPreset(name: "Home Shred", muscles: ["Chest", "Core", "Legs"], duration: 30, equipment: .bodyweight, historyCache: dashboard.lastPerformancesCache)
                }

                // 4. Кардио и кор
                presetCard(
                    title: "Кардио-бласт",
                    key: "Cardio Blast",
                    icon: "flame.fill",
                    accentColor: PastelTheme.pastelPeach,
                    desc: "Жиросжигание • 30 мин",
                    reason: "Высокий темп, укрепление сердечно-сосудистой системы и пресса."
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
        let isRecommended = (key == recommendedPresetKey)

        return Button {
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

                    if isRecommended {
                        HStack(spacing: 3) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 9, weight: .bold))
                            Text("Выбор ИИ")
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                        }
                        .foregroundStyle(PastelTheme.textOnOat)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(PastelTheme.pastelSage)
                        .clipShape(Capsule())
                    } else {
                        Button {
                            selectedInfoPreset = PresetInfoItem(title: title, reason: reason, muscles: [desc])
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14))
                                .foregroundStyle(PastelTheme.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
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
            .shadow(color: isRecommended ? PastelTheme.pastelSage.opacity(0.16) : Color.clear, radius: 8, y: 2)
        }
        .buttonStyle(.plain)
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

    // MARK: - Bottom Custom Builder Bar (Tier 1 Hero Action)
    private var bottomCustomBuilderBar: some View {
        VStack {
            Button {
                HapticManager.shared.impact(.medium)
                vm.path.append("MuscleSelection")
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 16, weight: .bold))

                    Text("Индивидуальная сборка")
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

                Text("ИИ собирает программу...")
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
