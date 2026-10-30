internal import SwiftUI

/// Workout mode choices for the Hearthstone-style discovery popup
enum WorkoutLaunchMode: Int, CaseIterable, Identifiable {
    case empty = 0
    case aiBuilder = 1
    case templates = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .empty: return "Пустая"
        case .aiBuilder: return "AI Билдер"
        case .templates: return "Шаблоны"
        }
    }

    var fullTitle: String {
        switch self {
        case .empty: return "Пустая тренировка"
        case .aiBuilder: return "AI Смарт-Билдер"
        case .templates: return "Мои шаблоны"
        }
    }

    var eyebrow: String {
        switch self {
        case .empty: return "РЕЖИМ 01 • СВОБОДНЫЙ"
        case .aiBuilder: return "РЕЖИМ 02 • НЕЙРОСЕТЬ"
        case .templates: return "РЕЖИМ 03 • БИБЛИОТЕКА"
        }
    }

    var romanNumeral: String {
        switch self {
        case .empty: return "I"
        case .aiBuilder: return "II"
        case .templates: return "III"
        }
    }

    var icon: String {
        switch self {
        case .empty: return "plus"
        case .aiBuilder: return "sparkles"
        case .templates: return "square.stack.3d.up.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .empty: return PastelTheme.pastelSage       // Athletic Emerald
        case .aiBuilder: return PastelTheme.pastelLavender // Neural Violet
        case .templates: return PastelTheme.pastelAmber     // Warm Amber
        }
    }

    var badgeText: String {
        switch self {
        case .empty: return "Свободный сет"
        case .aiBuilder: return "Умный подбор"
        case .templates: return "Из каталога"
        }
    }

    var editorialDescription: String {
        switch self {
        case .empty:
            return "Чистый лист для опытных атлетов. Записывайте любые упражнения, меняйте веса и подходы прямо на ходу без жестких рамок."
        case .aiBuilder:
            return "Интеллектуальный расчет нагрузки под статус восстановления мышечных групп и вашу текущую выносливость с прогрессией."
        case .templates:
            return "Проверенные тренировочные протоколы. Мгновенный запуск сохраненных тренировочных планов и золотых сплитов с историей весов."
        }
    }

    var tags: [String] {
        switch self {
        case .empty:
            return ["0 ограничений", "Быстрый старт", "Свой порядок"]
        case .aiBuilder:
            return ["Анализ мышц", "Смарт-объем", "CNS Прогрессия"]
        case .templates:
            return ["История весов", "Готовые сеты", "Таймер отдыха"]
        }
    }
}

/// Hearthstone-style 3-card discovery popup for starting workouts.
/// Features 3D card fan spread, hold-to-inspect editorial description HUD,
/// tactile haptic feedback, and Apple HIG Strict Dark Mode palette.
struct WorkoutModeDiscoveryPopup: View {
    @Binding var isPresented: Bool
    var onSelectEmpty: () -> Void
    var onSelectAI: () -> Void
    var onSelectTemplates: () -> Void

    @State private var selectedMode: WorkoutLaunchMode = .empty
    @State private var cardsAppeared: Bool = false
    @State private var isHoldingCard: Bool = false

    var body: some View {
        ZStack {
            // 1. Atmospheric Dimmed Backdrop
            Color.black.opacity(0.78)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissPopup()
                }

            // 2. Discovery Modal Container
            VStack(spacing: 20) {
                // Top Header Row with Close Button
                headerBar

                // Dynamic Editorial Inspection HUD (Above the 3 Cards)
                editorialInspectionHUD
                    .padding(.horizontal, 20)

                // The 3 Hearthstone-Style Cards in a Row
                cardsDiscoveryRow
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                // Subtle Instruction Eyebrow
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 11, weight: .medium))
                    Text("Коснитесь для выбора или удерживайте для описания")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundStyle(PastelTheme.textTertiary)

                // Launch CTA Button for the Selected Mode
                launchPrimaryButton
                    .padding(.horizontal, 20)
            }
            .padding(.vertical, 24)
            .background(PastelTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.6), radius: 36, y: 16)
            .padding(.horizontal, 16)
            .scaleEffect(cardsAppeared ? 1.0 : 0.88)
            .opacity(cardsAppeared ? 1.0 : 0.0)
        }
        .onAppear {
            HapticManager.playMediumImpact()
            withAnimation(.spring(response: 0.44, dampingFraction: 0.74)) {
                cardsAppeared = true
            }
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(PastelTheme.pastelLavender)

                Text("ВЫБОР РЕЖИМА ТРЕНИРОВКИ")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(PastelTheme.textSecondary)
                    .tracking(0.8)
            }

            Spacer()

            Button {
                dismissPopup()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(PastelTheme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(PastelTheme.cardSurfaceSubtle)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(PastelTheme.cardBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Editorial Inspection HUD (Above the 3 Cards)
    private var editorialInspectionHUD: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Eyebrow with Mode Accent Dot
            HStack(spacing: 6) {
                Circle()
                    .fill(selectedMode.accentColor)
                    .frame(width: 7, height: 7)

                Text(selectedMode.eyebrow)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(selectedMode.accentColor)
                    .tracking(0.6)
            }

            // Big Confident Mode Title
            Text(selectedMode.fullTitle)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(PastelTheme.textPrimary)
                .contentTransition(.numericText())

            // Editorial Phrased Description
            Text(selectedMode.editorialDescription)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PastelTheme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 48, alignment: .topLeading)

            // Dynamic Tag Pills
            HStack(spacing: 6) {
                ForEach(selectedMode.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(selectedMode.accentColor)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(selectedMode.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(selectedMode.accentColor.opacity(0.28), lineWidth: 1))
                }
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(PastelTheme.cardSurfaceSubtle)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(selectedMode.accentColor.opacity(0.35), lineWidth: 1)
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: selectedMode)
    }

    // MARK: - The 3 Hearthstone Cards in a Row
    private var cardsDiscoveryRow: some View {
        HStack(spacing: 12) {
            ForEach(WorkoutLaunchMode.allCases) { mode in
                hearthstoneCard(for: mode)
            }
        }
        .frame(height: 184)
    }

    // MARK: - Individual Hearthstone Card View
    @ViewBuilder
    private func hearthstoneCard(for mode: WorkoutLaunchMode) -> some View {
        let isSelected = selectedMode == mode

        // Hearthstone Fan spread angles
        let fanAngle: Double = {
            if isSelected { return 0 }
            switch mode {
            case .empty: return -4.0
            case .aiBuilder: return 0.0
            case .templates: return 4.0
            }
        }()

        let fanYAxisTilt: Double = {
            if isSelected { return 0 }
            switch mode {
            case .empty: return -6.0
            case .aiBuilder: return 0.0
            case .templates: return 6.0
            }
        }()

        Button {
            if selectedMode == mode {
                // Tapped again -> execute
                executeAction(for: mode)
            } else {
                // Switch focus to this card
                HapticManager.playSelection()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                    selectedMode = mode
                }
            }
        } label: {
            VStack(spacing: 10) {
                // Top Roman Numeral Eyebrow
                HStack {
                    Text(mode.romanNumeral)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(isSelected ? mode.accentColor : PastelTheme.textTertiary)

                    Spacer()

                    Circle()
                        .fill(isSelected ? mode.accentColor : PastelTheme.cardBorder)
                        .frame(width: 5, height: 5)
                }

                Spacer(minLength: 4)

                // Central Icon Emblem
                ZStack {
                    Circle()
                        .fill(isSelected ? mode.accentColor.opacity(0.18) : PastelTheme.cardSurface)
                        .frame(width: 48, height: 48)

                    Image(systemName: mode.icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(isSelected ? mode.accentColor : PastelTheme.textSecondary)
                }

                Spacer(minLength: 4)

                // Card Title
                VStack(spacing: 2) {
                    Text(mode.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? PastelTheme.textPrimary : PastelTheme.textSecondary)
                        .lineLimit(1)

                    Text(mode.badgeText)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(isSelected ? mode.accentColor : PastelTheme.textTertiary)
                        .lineLimit(1)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .frame(height: 168)
            .background(isSelected ? PastelTheme.cardSurfaceSubtle : PastelTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? mode.accentColor : PastelTheme.cardBorder, lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? mode.accentColor.opacity(0.3) : Color.black.opacity(0.2), radius: isSelected ? 12 : 6, y: isSelected ? 6 : 2)
            .offset(y: isSelected ? -10 : 0)
            .scaleEffect(isSelected ? 1.06 : 0.95)
            .opacity(isSelected ? 1.0 : 0.7)
            .rotationEffect(.degrees(fanAngle))
            .rotation3DEffect(.degrees(fanYAxisTilt), axis: (x: 0, y: 1, z: 0), perspective: 0.3)
            .animation(.spring(response: 0.32, dampingFraction: 0.72), value: isSelected)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if selectedMode != mode {
                        HapticManager.playSelection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedMode = mode
                        }
                    }
                }
        )
    }

    // MARK: - Launch Primary Button
    private var launchPrimaryButton: some View {
        Button {
            executeAction(for: selectedMode)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold))

                Text("Запустить: \(selectedMode.fullTitle)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .foregroundStyle(PastelTheme.textOnOat)
            .frame(maxWidth: .infinity)
            .frame(height: PastelTheme.ButtonMetrics.heroHeight)
            .background(PastelTheme.pastelOat)
            .clipShape(RoundedRectangle(cornerRadius: PastelTheme.ButtonMetrics.heroRadius, style: .continuous))
            .shadow(color: PastelTheme.pastelOat.opacity(0.2), radius: 8, y: 3)
        }
        .buttonStyle(Tactile3DCardButtonStyle(scale: 0.985, maxTilt: 2.0))
    }

    // MARK: - Actions
    private func dismissPopup() {
        HapticManager.playLightImpact()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
            cardsAppeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isPresented = false
        }
    }

    private func executeAction(for mode: WorkoutLaunchMode) {
        HapticManager.playMediumImpact()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            cardsAppeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            isPresented = false
            switch mode {
            case .empty:
                onSelectEmpty()
            case .aiBuilder:
                onSelectAI()
            case .templates:
                onSelectTemplates()
            }
        }
    }
}
