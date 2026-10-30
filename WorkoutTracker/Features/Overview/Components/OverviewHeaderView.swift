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
        formatter.dateFormat = "EEEE, d MMMM"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: Date()).capitalized
    }

    private func streakText(for days: Int) -> String {
        let remainder10 = days % 10
        let remainder100 = days % 100
        let word: String
        if remainder100 >= 11 && remainder100 <= 19 {
            word = "дней"
        } else if remainder10 == 1 {
            word = "день"
        } else if remainder10 >= 2 && remainder10 <= 4 {
            word = "дня"
        } else {
            word = "дней"
        }
        return "\(days) \(word) подряд"
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(formattedDate)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(PastelTheme.textSecondary)

                Text("Обзор")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(PastelTheme.textPrimary)
            }

            Spacer()

            HStack(spacing: 8) {
                // Subtle Streak Badge (Guaranteed single line, pixel-aligned)
                if streakDays > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(PastelTheme.pastelAmber)

                        Text(streakText(for: streakDays))
                            .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(PastelTheme.textPrimary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 11)
                    .frame(height: 38)
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
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PastelTheme.textPrimary)
                        .frame(width: 38, height: 38)
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
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(PastelTheme.textPrimary)
                        .frame(width: 38, height: 38)
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
