internal import SwiftUI
import SwiftData

struct SmartWorkoutLauncherSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    var onStartEmptySession: () -> Void
    var onSmartWorkoutTap: () -> Void
    var onPresetTap: (WorkoutPreset) -> Void
    var onExploreTap: () -> Void
    var onNewProgramTap: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground))
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Drag handle
                    Capsule()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 36, height: 5)
                        .padding(.top, 12)

                    // Header
                    Text(LocalizedStringKey("Start Session"))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : .black)

                    ScrollView {
                        VStack(spacing: 16) {
                            // 1. Smart Workout Card
                            launcherCard(
                                title: "Smart Workout",
                                subtitle: "AI Tailored for You",
                                icon: "wand.and.stars",
                                colors: [.purple, .indigo],
                                action: {
                                    dismiss()
                                    onSmartWorkoutTap()
                                }
                            )

                            // 2. Quick Session Card
                            launcherCard(
                                title: "Quick Session",
                                subtitle: "Start freestyle workout",
                                icon: "play.circle.fill",
                                colors: [.blue, .cyan],
                                action: {
                                    dismiss()
                                    onStartEmptySession()
                                }
                            )

                            // 3. My Routines Card (Navigation Link)
                            NavigationLink {
                                SmartWorkoutRoutinesListView(
                                    onPresetTap: onPresetTap,
                                    onNewProgramTap: onNewProgramTap,
                                    onExploreTap: onExploreTap
                                )
                            } label: {
                                launcherCardLabel(
                                    title: "My Routines",
                                    subtitle: "Select a routine template",
                                    icon: "list.bullet.clipboard.fill",
                                    colors: [.green, .mint]
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                    }

                    Spacer()

                    // Explore Link
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        dismiss()
                        onExploreTap()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "compass.fill")
                                .font(.subheadline)
                            Text(LocalizedStringKey("Explore program database"))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(themeManager.current.primaryAccent)
                        .padding(.bottom, 24)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationBarHidden(true)
        }
    }

    @ViewBuilder
    private func launcherCard(
        title: String,
        subtitle: String,
        icon: String,
        colors: [Color],
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            launcherCardLabel(title: title, subtitle: subtitle, icon: icon, colors: colors)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func launcherCardLabel(
        title: String,
        subtitle: String,
        icon: String,
        colors: [Color]
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title))
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                Text(LocalizedStringKey(subtitle))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(colors: [colors[0].opacity(0.4), colors[1].opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.15 : 0.04), radius: 8, x: 0, y: 4)
    }
}
