internal import SwiftUI

/// Clean, minimalist header for the Overview tab.
/// Displays greeting/date, subtle streak badge, calendar and profile actions.
struct OverviewHeaderView: View {
    let streakDays: Int
    let onCalendarTap: () -> Void
    let onProfileTap: () -> Void

    init(
        streakDays: Int,
        onCalendarTap: @escaping () -> Void,
        onProfileTap: @escaping () -> Void
    ) {
        self.streakDays = streakDays
        self.onCalendarTap = onCalendarTap
        self.onProfileTap = onProfileTap
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date()).capitalized
    }

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDate)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PastelTheme.textSecondary)

                Text("Overview")
                    .font(.system(size: 34, weight: .bold, design: .default))
                    .foregroundStyle(PastelTheme.textPrimary)
            }

            Spacer()

            HStack(spacing: 10) {
                // Subtle Streak Badge
                if streakDays > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(PastelTheme.pastelPeach)

                        Text("\(streakDays) \(streakDays == 1 ? "day" : "days")")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PastelTheme.textPrimary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(PastelTheme.cardSurface)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1)
                    )
                }

                // Calendar Button
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onCalendarTap()
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(PastelTheme.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(PastelTheme.cardSurface)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(PastelTheme.cardBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                // Profile Button
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onProfileTap()
                } label: {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(PastelTheme.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(PastelTheme.cardSurface)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(PastelTheme.cardBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
    }
}
