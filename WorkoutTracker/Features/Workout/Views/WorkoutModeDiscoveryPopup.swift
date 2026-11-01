internal import SwiftUI

/// Workout mode choices for the Hearthstone-style discovery popup
enum WorkoutLaunchMode: Int, CaseIterable, Identifiable {
    case empty = 0
    case aiBuilder = 1
    case templates = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .empty: return String(localized: "Empty")
        case .aiBuilder: return String(localized: "AI Builder")
        case .templates: return String(localized: "Templates")
        }
    }

    var fullTitle: String {
        switch self {
        case .empty: return String(localized: "Empty workout")
        case .aiBuilder: return String(localized: "Smart workout")
        case .templates: return String(localized: "History and templates")
        }
    }

    var categoryTitle: String {
        switch self {
        case .empty: return String(localized: "Free choice")
        case .aiBuilder: return String(localized: "Adaptive picks")
        case .templates: return String(localized: "Golden splits")
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

    var imageName: String {
        switch self {
        case .empty: return "workout_free_cover"
        case .aiBuilder: return "workout_ai_cover"
        case .templates: return "workout_templates_cover"
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
        case .empty: return String(localized: "Free set")
        case .aiBuilder: return String(localized: "Smart plan")
        case .templates: return String(localized: "From history")
        }
    }

    var editorialDescription: String {
        switch self {
        case .empty:
            return String(localized: "A clean slate for experienced lifters. Log any exercises and change weights or sets on the fly—no rigid structure.")
        case .aiBuilder:
            return String(localized: "Smart load based on muscle recovery and your current capacity, with built-in progression.")
        case .templates:
            return String(localized: "Proven protocols and golden splits from History. Replay your best session in one tap.")
        }
    }

    var tags: [String] {
        switch self {
        case .empty:
            return [
                String(localized: "Freedom"),
                String(localized: "Quick start"),
                String(localized: "No limits")
            ]
        case .aiBuilder:
            return [
                String(localized: "Muscle analysis"),
                String(localized: "Smart volume"),
                String(localized: "Progression")
            ]
        case .templates:
            return [
                String(localized: "From history"),
                String(localized: "Tonnage"),
                String(localized: "One tap")
            ]
        }
    }
}

/// Hearthstone-style 3-card discovery popup for starting workouts.
/// Features 3D card fan spread, hold-to-inspect editorial description HUD,
/// tactile haptic feedback, and Apple HIG Strict Dark Mode palette.
struct WorkoutModeDiscoveryPopup: View {
    @Binding var isPresented: Bool
    var hasTemplates: Bool = true
    var onCreateTemplate: (() -> Void)? = nil
    var onSelectEmpty: () -> Void
    var onSelectAI: () -> Void
    var onSelectTemplates: () -> Void

    @State private var selectedMode: WorkoutLaunchMode = .empty
    @State private var cardsAppeared: Bool = false
    @State private var showConfirmationAlert: Bool = false
    @State private var showNoTemplatesAlert: Bool = false
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
            VStack(spacing: 16) {
                // Top Header Row with Close Button
                headerBar

                // Dynamic Editorial Inspection HUD (Above the 3 Cards)
                editorialInspectionHUD
                    .padding(.horizontal, 14)

                // The 3 Hearthstone-Style Cards in a Row
                cardsDiscoveryRow
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)

                // Subtle Instruction Eyebrow
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 11, weight: .medium))
                    Text("Preview or pick a mode. Tap to start")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundStyle(PastelTheme.textTertiary)

                // Launch CTA Button for the Selected Mode
                launchPrimaryButton
                    .padding(.horizontal, 14)
            }
            .padding(.vertical, 20)
            .background(PastelTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.6), radius: 36, y: 16)
            .padding(.horizontal, 12)
            .scaleEffect(cardsAppeared ? 1.0 : 0.88)
            .opacity(cardsAppeared ? 1.0 : 0.0)
        }
        .alert(confirmationTitle, isPresented: $showConfirmationAlert) {
            Button(confirmationButtonText, role: .none) {
                let mode = pendingLaunchMode ?? selectedMode
                executeAction(for: mode)
            }
            Button("Cancel", role: .cancel) {
                pendingLaunchMode = nil
            }
        } message: {
            Text(confirmationMessage)
        }
        .alert("No templates yet", isPresented: $showNoTemplatesAlert) {
            Button("Create template") {
                dismissPopup()
                onCreateTemplate?()
            }
            Button("Open History") {
                dismissPopup()
                onSelectTemplates()
            }
            Button("Cancel", role: .cancel) {
                pendingLaunchMode = nil
            }
        } message: {
            Text("No saved templates yet. Create your first template now?")
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
            return "Start an empty workout?"
        case .aiBuilder:
            return "Open AI Builder?"
        case .templates:
            return "Open templates?"
        }
    }

    private var confirmationMessage: String {
        let mode = pendingLaunchMode ?? selectedMode
        switch mode {
        case .empty:
            return "A free-form workout will be created with no template. You can log sets as you go."
        case .aiBuilder:
            return "Generate an adaptive workout plan based on your current muscle readiness?"
        case .templates:
            return "Go to History to start one of your saved splits?"
        }
    }

    private var confirmationButtonText: String {
        let mode = pendingLaunchMode ?? selectedMode
        switch mode {
        case .empty:
            return "Start"
        case .aiBuilder, .templates:
            return "Continue"
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(PastelTheme.pastelLavender)

                Text("Workout format")
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
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                // Clean category label without decorative dots
                Text(selectedMode.categoryTitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(selectedMode.accentColor)

                // Big Confident Mode Title
                Text(selectedMode.fullTitle)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(PastelTheme.textPrimary)
                    .contentTransition(.numericText())

                // Editorial Phrased Description
                Text(selectedMode.editorialDescription)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PastelTheme.textSecondary)
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 44, alignment: .topLeading)

                // Dynamic Tag Pills
                HStack(spacing: 6) {
                    ForEach(selectedMode.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(selectedMode.accentColor)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(selectedMode.accentColor.opacity(0.12))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(selectedMode.accentColor.opacity(0.28), lineWidth: 1))
                    }
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right: Atmospheric Artwork Portrait Thumbnail
            Image(selectedMode.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 58, height: 86)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(selectedMode.accentColor.opacity(0.6), lineWidth: 1.5)
                )
                .shadow(color: selectedMode.accentColor.opacity(0.3), radius: 8, y: 3)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .id(selectedMode.imageName)
        }
        .padding(12)
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

            HStack(spacing: 8) {
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
        .frame(height: 172)
    }

    // MARK: - Individual Hearthstone Card View
    @ViewBuilder
    private func hearthstoneCard(for mode: WorkoutLaunchMode) -> some View {
        let isSelected = selectedMode == mode

        // Hearthstone Fan spread angles
        let fanAngle: Double = {
            if isSelected { return 0 }
            switch mode {
            case .empty: return -2.0
            case .aiBuilder: return 0.0
            case .templates: return 2.0
            }
        }()

        let fanYAxisTilt: Double = {
            if isSelected { return 0 }
            switch mode {
            case .empty: return -3.0
            case .aiBuilder: return 0.0
            case .templates: return 3.0
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
            ZStack {
                // 1. Cinematic Background Image (Exact Fit Geometry)
                GeometryReader { cardGeo in
                    Image(mode.imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cardGeo.size.width, height: cardGeo.size.height)
                        .clipped()
                }
                .overlay(
                    LinearGradient(
                        stops: [
                            .init(color: Color.clear, location: 0.0),
                            .init(color: Color.black.opacity(isSelected ? 0.04 : 0.14), location: 0.35),
                            .init(color: PastelTheme.cardSurface.opacity(isSelected ? 0.70 : 0.82), location: 0.68),
                            .init(color: PastelTheme.cardSurface, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // 2. Card Foreground Content
                VStack(spacing: 6) {
                    // Top Bar: Roman Numeral + Icon Chip
                    HStack {
                        Text(mode.romanNumeral)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? mode.accentColor : PastelTheme.textTertiary)

                        Spacer()

                        Image(systemName: mode.icon)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(isSelected ? mode.accentColor : PastelTheme.textSecondary)
                            .frame(width: 20, height: 20)
                            .background(PastelTheme.cardSurfaceSubtle.opacity(0.85))
                            .clipShape(Circle())
                    }

                    Spacer(minLength: 2)

                    // Card Title & Badge at the bottom
                    VStack(spacing: 3) {
                        Text(mode.title)
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? PastelTheme.textPrimary : PastelTheme.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        Text(mode.badgeText)
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? mode.accentColor : PastelTheme.textTertiary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(PastelTheme.cardSurfaceSubtle.opacity(0.9))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(isSelected ? mode.accentColor.opacity(0.4) : PastelTheme.cardBorder, lineWidth: 1))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
                .padding(6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 162)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? mode.accentColor : PastelTheme.cardBorder, lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? mode.accentColor.opacity(0.35) : Color.black.opacity(0.2), radius: isSelected ? 10 : 4, y: isSelected ? 5 : 2)
            .offset(y: isSelected ? -7 : 0)
            .scaleEffect(x: isSelected ? 1.01 : 0.98, y: isSelected ? 1.02 : 0.98)
            .opacity(isSelected ? 1.0 : 0.88)
            .rotationEffect(.degrees(fanAngle))
            .rotation3DEffect(.degrees(fanYAxisTilt), axis: (x: 0, y: 1, z: 0), perspective: 0.3)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
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
        case .empty: return "Start empty workout"
        case .aiBuilder: return "Open AI Builder"
        case .templates: return hasTemplates ? "Open templates in History" : "Create first template"
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
        if mode == .templates && !hasTemplates {
            showNoTemplatesAlert = true
        } else {
            showConfirmationAlert = true
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
