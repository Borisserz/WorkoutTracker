internal import SwiftUI

/// Luxury architectural mechanical pressure plate representing a Legendary Routine.
/// Styled after the prestigious physical awards & trophies in ProgressView,
/// featuring corner micro-screws, specular rim bevel highlight, illuminated emblem socket,
/// physical spring switch depression, and dedicated tactile haptic feedback.
struct LegendaryPressurePlate: View {
    let routine: LegendaryRoutine
    var isSelected: Bool = false
    var delay: Double = 0.0
    var hasPavedScreen: Bool = true
    let onSelect: () -> Void

    @State private var isDepressed: Bool = false

    var eraColor: Color {
        let lower = (routine.eraTitle + " " + routine.title).lowercased()
        if lower.contains("golden") || lower.contains("arnold") {
            return PastelTheme.pastelAmber
        } else if lower.contains("olympia") || lower.contains("dc") || lower.contains("brutality") {
            return PastelTheme.pastelPeach
        } else if lower.contains("calisthenics") || lower.contains("xero") {
            return PastelTheme.pastelSage
        } else if lower.contains("olympic") || lower.contains("bulgarian") || lower.contains("power") {
            return PastelTheme.pastelLavender
        }
        return PastelTheme.pastelOat
    }

    var eraIcon: String {
        let lower = (routine.eraTitle + " " + routine.title).lowercased()
        if lower.contains("calisthenics") || lower.contains("xero") {
            return "figure.strengthtraining.traditional"
        } else if lower.contains("arnold") || lower.contains("golden") {
            return "crown.fill"
        } else if lower.contains("olympia") || lower.contains("dc") || lower.contains("brutality") {
            return "trophy.fill"
        } else if lower.contains("olympic") || lower.contains("bulgarian") || lower.contains("power") {
            return "bolt.fill"
        } else if lower.contains("combat") || lower.contains("gladiator") {
            return "shield.fill"
        }
        return "star.fill"
    }

    var body: some View {
        Button {
            isDepressed = true
            HapticManager.shared.impact(.rigid)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                isDepressed = false
                onSelect()
            }
        } label: {
            ZStack {
                // 1. Slab Surface Background with Specular Rim Highlight
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? PastelTheme.cardSurfaceSubtle : PastelTheme.cardSurface)
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isDepressed ? 0.02 : 0.10),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    )

                // 2. Corner Micro-Screws (Craftsmanship detail)
                cornerScrews

                // 3. Plate Content
                VStack(spacing: 8) {
                    // Top: Era Pill & Estimated Duration
                    HStack(spacing: 4) {
                        Text(routine.eraTitle)
                            .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(eraColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(eraColor.opacity(0.14))
                            .clipShape(Capsule())

                        Spacer(minLength: 4)

                        HStack(spacing: 3) {
                            Image(systemName: "stopwatch")
                                .font(.system(size: 9, weight: .medium))
                            Text("\(routine.estimatedMinutes)m")
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(PastelTheme.textSecondary)
                    }

                    Spacer(minLength: 2)

                    // Center: Illuminated Emblem Socket
                    ZStack {
                        Circle()
                            .fill(PastelTheme.cardSurfaceSubtle)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle().stroke(eraColor.opacity(0.35), lineWidth: 1)
                            )

                        Image(systemName: eraIcon)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(eraColor)
                    }

                    Spacer(minLength: 2)

                    // Bottom: Title & Highlight Tag
                    VStack(spacing: 4) {
                        Text(LocalizedStringKey(routine.title))
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(PastelTheme.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .frame(height: 34)

                        Text(routine.benefits.first ?? routine.shortVibe)
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(PastelTheme.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(PastelTheme.cardSurfaceSubtle)
                            .clipShape(Capsule())
                    }
                }
                .padding(12)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 164)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? eraColor : PastelTheme.cardBorder,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(
                color: Color.black.opacity(isDepressed ? 0.2 : 0.45),
                radius: isDepressed ? 2 : 6,
                y: isDepressed ? 1 : 4
            )
            // Physical Mechanical Plate Depression Motion
            .offset(y: hasPavedScreen ? (isDepressed ? 3 : 0) : 28)
            .scaleEffect(hasPavedScreen ? (isDepressed ? 0.95 : 1.0) : 0.85)
            .opacity(hasPavedScreen ? 1.0 : 0.0)
            .animation(.spring(response: 0.42, dampingFraction: 0.76).delay(delay), value: hasPavedScreen)
            .animation(.spring(response: 0.20, dampingFraction: 0.72), value: isDepressed)
        }
        .buttonStyle(.plain)
    }

    private var cornerScrews: some View {
        VStack {
            HStack {
                Circle().fill(PastelTheme.cardBorder.opacity(0.4)).frame(width: 3, height: 3)
                Spacer()
                Circle().fill(PastelTheme.cardBorder.opacity(0.4)).frame(width: 3, height: 3)
            }
            Spacer()
            HStack {
                Circle().fill(PastelTheme.cardBorder.opacity(0.4)).frame(width: 3, height: 3)
                Spacer()
                Circle().fill(PastelTheme.cardBorder.opacity(0.4)).frame(width: 3, height: 3)
            }
        }
        .padding(6)
    }
}

/// Compact Horizontal Deck Pressure Plate for Legendary Routines in WorkoutHubView.
struct CompactLegendaryPressurePlate: View {
    let routine: LegendaryRoutine
    let onSelect: () -> Void

    @State private var isDepressed: Bool = false

    var eraColor: Color {
        let lower = (routine.eraTitle + " " + routine.title).lowercased()
        if lower.contains("golden") || lower.contains("arnold") {
            return PastelTheme.pastelAmber
        } else if lower.contains("olympia") || lower.contains("dc") || lower.contains("brutality") {
            return PastelTheme.pastelPeach
        } else if lower.contains("calisthenics") || lower.contains("xero") {
            return PastelTheme.pastelSage
        } else if lower.contains("olympic") || lower.contains("bulgarian") || lower.contains("power") {
            return PastelTheme.pastelLavender
        }
        return PastelTheme.pastelOat
    }

    var eraIcon: String {
        let lower = (routine.eraTitle + " " + routine.title).lowercased()
        if lower.contains("calisthenics") || lower.contains("xero") {
            return "figure.strengthtraining.traditional"
        } else if lower.contains("arnold") || lower.contains("golden") {
            return "crown.fill"
        } else if lower.contains("olympia") || lower.contains("dc") || lower.contains("brutality") {
            return "trophy.fill"
        } else if lower.contains("olympic") || lower.contains("bulgarian") || lower.contains("power") {
            return "bolt.fill"
        }
        return "star.fill"
    }

    var body: some View {
        Button {
            isDepressed = true
            HapticManager.shared.impact(.rigid)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                isDepressed = false
                onSelect()
            }
        } label: {
            ZStack {
                // Background with specular sheen
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(PastelTheme.cardSurface)
                    .overlay(
                        LinearGradient(
                            colors: [Color.white.opacity(isDepressed ? 0.02 : 0.08), Color.clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    )

                // Corner micro-screws
                VStack {
                    HStack {
                        Circle().fill(PastelTheme.cardBorder.opacity(0.35)).frame(width: 3, height: 3)
                        Spacer()
                        Circle().fill(PastelTheme.cardBorder.opacity(0.35)).frame(width: 3, height: 3)
                    }
                    Spacer()
                    HStack {
                        Circle().fill(PastelTheme.cardBorder.opacity(0.35)).frame(width: 3, height: 3)
                        Spacer()
                        Circle().fill(PastelTheme.cardBorder.opacity(0.35)).frame(width: 3, height: 3)
                    }
                }
                .padding(6)

                // Card Layout
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center) {
                        // Era Pill
                        Text(routine.eraTitle)
                            .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(eraColor)
                            .padding(.horizontal, 8)
                            .frame(height: 22)
                            .background(eraColor.opacity(0.14))
                            .clipShape(Capsule())

                        Spacer()

                        // Estimated Time
                        HStack(spacing: 3) {
                            Image(systemName: "stopwatch")
                                .font(.system(size: 10, weight: .medium))
                            Text("\(routine.estimatedMinutes) min")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(PastelTheme.textSecondary)
                    }

                    Spacer(minLength: 2)

                    HStack(spacing: 12) {
                        // Emblem socket
                        ZStack {
                            Circle()
                                .fill(PastelTheme.cardSurfaceSubtle)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle().stroke(eraColor.opacity(0.35), lineWidth: 1)
                                )

                            Image(systemName: eraIcon)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(eraColor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(LocalizedStringKey(routine.title))
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundStyle(PastelTheme.textPrimary)
                                .lineLimit(1)

                            Text(routine.shortVibe)
                                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                                .foregroundStyle(PastelTheme.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)
                    }

                    Spacer(minLength: 2)

                    // Bottom: Benefits & Direct Inspect Arrow
                    HStack {
                        HStack(spacing: 4) {
                            ForEach(routine.benefits.prefix(2), id: \.self) { benefit in
                                Text(benefit)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(PastelTheme.textTertiary)
                                    .padding(.horizontal, 6)
                                    .frame(height: 18)
                                    .background(PastelTheme.cardSurfaceSubtle)
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            }
                        }

                        Spacer()

                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(PastelTheme.pastelOat)
                    }
                }
                .padding(12)
            }
            .frame(width: 230, height: 136)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(isDepressed ? 0.2 : 0.4),
                radius: isDepressed ? 2 : 5,
                y: isDepressed ? 1 : 3
            )
            .scaleEffect(isDepressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.20, dampingFraction: 0.72), value: isDepressed)
        }
        .buttonStyle(.plain)
    }
}
