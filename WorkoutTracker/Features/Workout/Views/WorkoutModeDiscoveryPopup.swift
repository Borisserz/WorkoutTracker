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
        case .aiBuilder: return "Смарт-тренировка"
        case .templates: return "История и шаблоны"
        }
    }

    var categoryTitle: String {
        switch self {
        case .empty: return "Свободный выбор"
        case .aiBuilder: return "Адаптивный подбор"
        case .templates: return "Золотые сплиты"
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
        case .templates: return "trophy.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .empty: return PastelTheme.pastelSage       // Athletic Emerald
        case .aiBuilder: return PastelTheme.pastelLavender // Soft Violet
        case .templates: return PastelTheme.pastelAmber     // Warm Amber
        }
    }

    var badgeText: String {
        switch self {
        case .empty: return "Свободный сет"
        case .aiBuilder: return "Умный план"
        case .templates: return "Из истории"
        }
    }

    var editorialDescription: String {
        switch self {
        case .empty:
            return "Чистый лист для опытных атлетов. Записывайте любые упражнения, меняйте веса и подходы прямо на ходу без жестких рамок."
        case .aiBuilder:
            return "Интеллектуальный расчет нагрузки под статус восстановления мышц и вашу текущую выносливость с прогрессией."
        case .templates:
            return "Проверенные протоколы и золотые сплиты из вкладки История. Мгновенный повтор вашей лучшей тренировки в 1 тап."
        }
    }

    var tags: [String] {
        switch self {
        case .empty:
            return ["0 ограничений", "Быстрый старт", "Свой порядок"]
        case .aiBuilder:
            return ["Анализ мышц", "Смарт-объем", "Прогрессия"]
        case .templates:
            return ["Лучший тоннаж", "История весов", "В 1 тап"]
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
    @State private var showConfirmationAlert: Bool = false
    @State private var pendingLaunchMode: WorkoutLaunchMode? = nil

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
                    Text("Наведите или выберите режим • Запуск по нажатию")
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
        .alert(confirmationTitle, isPresented: $showConfirmationAlert) {
            Button(confirmationButtonText, role: .none) {
                let mode = pendingLaunchMode ?? selectedMode
                executeAction(for: mode)
            }
            Button("Отмена", role: .cancel) {
                pendingLaunchMode = nil
            }
        } message: {
            Text(confirmationMessage)
        }
        .onAppear {
            HapticManager.playMediumImpact()
            withAnimation(.spring(response: 0.44, dampingFraction: 0.74)) {
                cardsAppeared = true
            }
        }
    }

    // MARK: - Confirmation Copy
    private var confirmationTitle: String {
        let mode = pendingLaunchMode ?? selectedMode
        switch mode {
        case .empty:
            return "Начать пустую тренировку?"
        case .aiBuilder:
            return "Открыть AI Билдер?"
        case .templates:
            return "Открыть шаблоны?"
        }
    }

    private var confirmationMessage: String {
        let mode = pendingLaunchMode ?? selectedMode
        switch mode {
        case .empty:
            return "Будет создана свободная тренировка без шаблона. Вы сможете записывать подходы прямо на ходу."
        case .aiBuilder:
            return "Перейти к генерации адаптивного плана тренировки под текущую готовность мышц?"
        case .templates:
            return "Перейти во вкладку «История» для запуска одного из ваших сохраненных сплитов?"
        }
    }

    private var confirmationButtonText: String {
        let mode = pendingLaunchMode ?? selectedMode
        switch mode {
        case .empty:
            return "Начать"
        case .aiBuilder, .templates:
            return "Перейти"
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(PastelTheme.pastelLavender)

                Text("Формат тренировки")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(PastelTheme.textPrimary)
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
            // Clean category label without decorative dots
            Text(selectedMode.categoryTitle)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(selectedMode.accentColor)

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
        GeometryReader { geo in
            let rowWidth = geo.size.width
            let step = max(1.0, rowWidth / 3.0)

            HStack(spacing: 12) {
                ForEach(WorkoutLaunchMode.allCases) { mode in
                    hearthstoneCard(for: mode)
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        let locationX = value.location.x
                        let index = Int(locationX / step)
                        let clampedIndex = max(0, min(2, index))
                        if let mode = WorkoutLaunchMode(rawValue: clampedIndex), selectedMode != mode {
                            HapticManager.playSelection()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                selectedMode = mode
                            }
                        }
                    }
            )
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
                // Tapped on already focused card -> request launch with confirmation!
                requestLaunch(for: mode)
            } else {
                // Switch focus to this card
                HapticManager.playSelection()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                    selectedMode = mode
                }
            }
        } label: {
            VStack(spacing: 10) {
                // Top Roman Numeral
                HStack {
                    Text(mode.romanNumeral)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? mode.accentColor : PastelTheme.textTertiary)

                    Spacer()
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
        .onHover { isHovered in
            if isHovered && selectedMode != mode {
                HapticManager.playSelection()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    selectedMode = mode
                }
            }
        }
    }

    // MARK: - Launch Primary Button
    private var launchPrimaryButton: some View {
        Button {
            requestLaunch(for: selectedMode)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: primaryButtonIcon(for: selectedMode))
                    .font(.system(size: 14, weight: .bold))

                Text(primaryButtonText(for: selectedMode))
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

    private func primaryButtonIcon(for mode: WorkoutLaunchMode) -> String {
        switch mode {
        case .empty: return "play.fill"
        case .aiBuilder: return "sparkles"
        case .templates: return "arrow.right"
        }
    }

    private func primaryButtonText(for mode: WorkoutLaunchMode) -> String {
        switch mode {
        case .empty: return "Запустить: Пустая тренировка"
        case .aiBuilder: return "Перейти в AI Билдер"
        case .templates: return "Открыть шаблоны в Истории"
        }
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

    private func requestLaunch(for mode: WorkoutLaunchMode) {
        HapticManager.playMediumImpact()
        pendingLaunchMode = mode
        showConfirmationAlert = true
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
