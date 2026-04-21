

internal import SwiftUI

struct DetailedComparisonView: View {
    let comparisons: [DetailedComparison]
    let period: String

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        if comparisons.isEmpty {
            EmptyStateView(
                icon: "chart.bar.xaxis",
                title: LocalizedStringKey("No comparison data available"),
                message: LocalizedStringKey("Complete more workouts to see detailed comparisons between periods. Track your progress over time!")
            )
            .frame(height: 150)
        } else {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(comparisons, id: \.metric) { comparison in
                    DetailedComparisonRow(comparison: comparison)
                }
            }
        }
    }
}

struct DetailedComparisonRow: View {
    let comparison: DetailedComparison

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    private func iconAndColor(for metric: String) -> (icon: String, color: Color) {
        let m = metric.lowercased()
        if m.contains("workout") || m.contains("тренировки") { return ("figure.run", themeManager.current.primaryAccent) }
        if m.contains("volume") || m.contains("объем") { return ("scalemass.fill", .purple) }
        if m.contains("distance") || m.contains("дистанция") { return ("map.fill", .orange) }
        if m.contains("time") || m.contains("время") { return ("stopwatch.fill", .cyan) }
        return ("chart.bar.fill", .gray)
    }

    var body: some View {
        HStack(spacing: 16) {
            let style = iconAndColor(for: comparison.metric)

            ZStack {
                Circle().fill(style.color.opacity(0.15)).frame(width: 48, height: 48)
                Image(systemName: style.icon).font(.title3).foregroundColor(style.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(comparison.metric))
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                HStack(spacing: 6) {
                    Text(LocalizationHelper.shared.formatSmart(comparison.previousValue))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.5))
                    Text(LocalizationHelper.shared.formatSmart(comparison.currentValue))
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }
            }

            Spacer()

            let isPositive = comparison.changePercentage >= 0
            Text("\(isPositive ? "+" : "")\(comparison.changePercentage, specifier: "%.1f")%")
                .font(.subheadline)
                .fontWeight(.bold)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isPositive ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                .foregroundColor(isPositive ? .green : .red)
                .clipShape(Capsule())
        }
        .padding(16)
        .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.03 : 0.05), radius: 8, x: 0, y: 4)
    }
}
