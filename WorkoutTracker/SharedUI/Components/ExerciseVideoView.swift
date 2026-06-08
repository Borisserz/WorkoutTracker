internal import SwiftUI

struct ExerciseVideoView: View {
    let urlString: String?
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var hasError: Bool = false
    
    var body: some View {
        Group {
            if let urlString = urlString, !hasError {
                GifImageView(urlString: urlString, hasError: $hasError)
                    .frame(height: 250)
            } else {
                placeholderView
            }
        }
        .frame(height: 250)
        .frame(maxWidth: .infinity)
        .background(colorScheme == .dark ? Color(UIColor.tertiarySystemFill) : Color(UIColor.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.1), radius: 10, x: 0, y: 5)
    }
    
    private var placeholderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "video.slash.fill")
                .font(.system(size: 40))
                .foregroundColor(themeManager.current.secondaryText.opacity(0.5))
            
            Text("Animation coming soon")
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .black)
            
            Text("We're currently preparing the video for this exercise.")
                .font(.subheadline)
                .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }
}
