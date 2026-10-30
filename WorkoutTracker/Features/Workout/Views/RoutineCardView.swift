

internal import SwiftUI

/// Premium Luxury Routine Card with 3D tactile press physics,
/// solid PastelTheme palette, strict ButtonMetrics, zero gradients, and zero emojis.
struct PremiumRoutineCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let preset: WorkoutPreset
    let onStart: () -> Void
    var onEdit: (() -> Void)? = nil
    var onDuplicate: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @State private var dragOffset: CGSize = .zero
    @State private var isInteracting: Bool = false

    private var targetedMusclesText: String {
        let slugs = preset.exercises.compactMap { ex -> String? in
            guard !ex.muscleGroup.isEmpty else { return nil }
            return ex.muscleGroup.lowercased()
        }
        let unique = Array(Set(slugs)).prefix(3).map { MuscleDisplayHelper.getDisplayName(for: $0) }
        return unique.isEmpty ? String(localized: "Full Body") : unique.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Row: Squircle Icon + Title + Overflow Menu
            HStack(alignment: .center, spacing: 12) {
                // Squircle Icon (40x40)
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(PastelTheme.cardSurfaceSubtle)
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(PastelTheme.cardBorder, lineWidth: 1)
                        )

                    Image(systemName: preset.icon.isEmpty ? "figure.strengthtraining.traditional" : preset.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PastelTheme.pastelOat)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(preset.name))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(targetedMusclesText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PastelTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Menu {
                    if let onEdit = onEdit {
                        Button(action: onEdit) {
                            Label(LocalizedStringKey("Edit Template"), systemImage: "pencil")
                        }
                    }

                    if let onDuplicate = onDuplicate {
                        Button(action: onDuplicate) {
                            Label(
                                preset.isSystem ? LocalizedStringKey("Save to My Routines") : LocalizedStringKey("Duplicate"),
                                systemImage: "plus.square.on.square"
                            )
                        }
                    }

                    if let onDelete = onDelete {
                        Button(role: .destructive, action: onDelete) {
                            Label(LocalizedStringKey("Delete"), systemImage: "trash")
                        }
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(PastelTheme.cardSurfaceSubtle)
                            .frame(width: 32, height: 32)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
                            )

                        Image(systemName: "ellipsis")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(PastelTheme.textSecondary)
                    }
                }
                .highPriorityGesture(TapGesture().onEnded { })
            }

            // Middle Row: Metadata Badges
            HStack(spacing: 8) {
                // Exercise count pill
                Text("\(preset.exercises.count) упр.")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(PastelTheme.pastelSage)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(PastelTheme.pastelSage.opacity(0.12))
                    .clipShape(Capsule())

                Text("•")
                    .font(.caption2)
                    .foregroundStyle(PastelTheme.textTertiary)

                Text(exercisesPreviewText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PastelTheme.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            // Primary Tier 2 Action: Start Routine Button (Solid Warm Oat #EFE3D3, Pure Black Text)
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                onStart()
            }) {
                HStack(spacing: 7) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text(LocalizedStringKey("Start Routine"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundStyle(PastelTheme.textOnOat)
                .frame(maxWidth: .infinity)
                .frame(height: PastelTheme.ButtonMetrics.splitHeight)
                .background(PastelTheme.pastelOat)
                .clipShape(RoundedRectangle(cornerRadius: PastelTheme.ButtonMetrics.splitRadius, style: .continuous))
                .shadow(color: PastelTheme.pastelOat.opacity(0.2), radius: 6, y: 2)
            }
            .buttonStyle(Tactile3DCardButtonStyle(scale: 0.98, maxTilt: 2.5))
        }
        .padding(16)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: PastelTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PastelTheme.cardRadius, style: .continuous)
                .stroke(isInteracting ? PastelTheme.cardBorderFocused : PastelTheme.cardBorder, lineWidth: 1)
        )
        .rotation3DEffect(
            .degrees(Double(dragOffset.width / 18)),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.4
        )
        .rotation3DEffect(
            .degrees(Double(-dragOffset.height / 18)),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.4
        )
        .gesture(
            DragGesture(minimumDistance: 12)
                .onChanged { value in
                    isInteracting = true
                    withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.8)) {
                        dragOffset = value.translation
                    }
                }
                .onEnded { _ in
                    isInteracting = false
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.68)) {
                        dragOffset = .zero
                    }
                }
        )
    }

    private var exercisesPreviewText: String {
        if preset.exercises.isEmpty { return String(localized: "No exercises") }
        return preset.exercises.prefix(3).map { LocalizationHelper.shared.translateName($0.name) }.joined(separator: ", ")
    }
}
