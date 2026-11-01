internal import SwiftUI

struct ExerciseVideoView: View {
    let urlString: String?
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var hasError: Bool = false
    
    var body: some View {
        Group {
            if let urlString, !urlString.isEmpty, !hasError {
                GifImageView(urlString: urlString, hasError: $hasError)
                    .frame(height: 250)
                    .frame(maxWidth: .infinity)
                    .background(PastelTheme.cardSurfaceSubtle)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                // No stub marketing copy — hide until media exists.
                EmptyView()
            }
        }
    }
}
