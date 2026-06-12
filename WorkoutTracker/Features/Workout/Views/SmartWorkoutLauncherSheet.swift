internal import SwiftUI
import SwiftData

struct SmartWorkoutLauncherSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    @Query(filter: #Predicate<WorkoutPreset> { $0.isSystem == false }, sort: \WorkoutPreset.name)
    private var userPresets: [WorkoutPreset]

    var onStartEmptySession: () -> Void
    var onSmartWorkoutTap: () -> Void
    var onPresetTap: (WorkoutPreset) -> Void
    var onExploreTap: () -> Void

    private var myRoutines: [WorkoutPreset] {
        userPresets.filter { ($0.folderName ?? "").isEmpty && $0.name != "Today's Plan" }
    }

    var body: some View {
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

                        // 3. My Routines Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "list.bullet.clipboard.fill")
                                    .font(.title2)
                                    .foregroundStyle(LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 32, height: 32)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(LocalizedStringKey("My Routines"))
                                        .font(.headline)
                                        .foregroundColor(colorScheme == .dark ? .white : .black)
                                    Text(LocalizedStringKey("Select a routine template"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }

                            if myRoutines.isEmpty {
                                Text(LocalizedStringKey("No custom routines yet"))
                                    .font(.caption)
                                    .italic()
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 40)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(myRoutines) { preset in
                                            Button {
                                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                dismiss()
                                                onPresetTap(preset)
                                            } label: {
                                                HStack(spacing: 6) {
                                                    Image(systemName: preset.icon.isEmpty ? "dumbbell.fill" : preset.icon)
                                                        .font(.caption)
                                                    Text(preset.name)
                                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                                }
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(themeManager.current.primaryAccent.opacity(0.15))
                                                .cornerRadius(8)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(themeManager.current.primaryAccent.opacity(0.3), lineWidth: 1)
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.leading, 40)
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(
                                    LinearGradient(colors: [.green.opacity(0.4), .mint.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.15 : 0.04), radius: 8, x: 0, y: 4)
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
        .buttonStyle(.plain)
    }
}
