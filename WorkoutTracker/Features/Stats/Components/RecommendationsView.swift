

internal import SwiftUI

struct RecommendationsView: View {
    let recommendations: [Recommendation]
       var onTap: ((Recommendation) -> Void)?

       init(
           recommendations: [Recommendation],
           onTap: ((Recommendation) -> Void)? = nil
       ) {
           self.recommendations = recommendations
           self.onTap = onTap
       }

        @Environment(ThemeManager.self) private var themeManager

       var body: some View {
        if recommendations.isEmpty {
            EmptyStateView(
                icon: "checkmark.circle.fill",
                title: LocalizedStringKey("No recommendations"),
                message: LocalizedStringKey("You're doing great! Keep up the consistent training to receive personalized recommendations.")
            )
            .frame(height: 150)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(recommendations.prefix(5))) { recommendation in
                    RecommendationRow(recommendation: recommendation)
                }
            }
        }
    }
}

struct RecommendationRow: View {
    let recommendation: Recommendation

        @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: recommendation.type.icon)
                .foregroundColor(recommendation.type.color)
                .font(.title3)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(recommendation.title)
                        .font(.headline)

                    Spacer()

                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { index in
                            Circle()
                                .fill(index <= recommendation.priority ? recommendation.type.color : Color.gray.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                    }
                }

                Text(recommendation.message)
                    .font(.subheadline)
                    .foregroundColor(themeManager.current.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    RecommendationsView(recommendations: [])
}

