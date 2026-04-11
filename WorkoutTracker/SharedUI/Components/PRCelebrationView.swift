//
//  PRCelebrationView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 2.04.26.
//

internal import SwiftUI

// This view shows a celebration for a new Personal Record
struct PRCelebrationView: View {
    let prLevel: PRLevel
    let onClose: () -> Void

    @State private var isAnimating = false

        @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea().onTapGesture(perform: onClose)

            VStack(spacing: 20) {
                Text(prLevel.title)
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundColor(themeManager.current.background)
                    .padding()
            }
            .scaleEffect(isAnimating ? 1.0 : 0.5)
            .opacity(isAnimating ? 1.0 : 0.0)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    isAnimating = true
                }
            }
        }
    }
}
