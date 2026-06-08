//
//  ForceUpdateView.swift
//  WorkoutTracker
//

internal import SwiftUI

struct ForceUpdateView: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // App Icon Mock or Illustration
            ZStack {
                Circle()
                    .fill(themeManager.current.primaryAccent.opacity(0.15))
                    .frame(width: 140, height: 140)
                    .shadow(color: themeManager.current.primaryAccent.opacity(0.4), radius: 20, x: 0, y: 10)
                
                Image(systemName: "arrow.up.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(themeManager.current.primaryAccent)
            }
            
            VStack(spacing: 16) {
                Text("Time to Update!")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(themeManager.current.primaryText)
                    .multilineTextAlignment(.center)
                
                Text("We've added some powerful new features and critical fixes. Please update to the latest version to continue crushing your workouts.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(themeManager.current.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .lineSpacing(6)
            }
            
            Spacer()
            
            Button {
                AppReviewManager.openAppStoreReview() // Reusing the method to open App Store
            } label: {
                Text("Update Now")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [themeManager.current.primaryAccent, themeManager.current.lightHighlight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: themeManager.current.primaryAccent.opacity(0.4), radius: 10, y: 5)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.current.background.ignoresSafeArea())
    }
}
