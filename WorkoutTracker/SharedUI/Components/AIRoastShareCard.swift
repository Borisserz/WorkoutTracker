//
//  AIRoastShareCard.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 4.04.26.
//

// ============================================================
// FILE: WorkoutTracker/SharedUI/Components/AIRoastShareCard.swift
// ============================================================

internal import SwiftUI

struct AIRoastShareCard: View {
    let roastText: String
    let exerciseName: String
    
        @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        ZStack {
            // Dark Gradient Background
            LinearGradient(
                colors: [Color(hex: "0a0a0a"), Color(hex: "1a0000")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Neon Glow
            Circle()
                .fill(Color.red.opacity(0.3))
                .frame(width: 300)
                .blur(radius: 60)
                .offset(x: -100, y: -200)
            
            Circle()
                .fill(Color.orange.opacity(0.2))
                .frame(width: 400)
                .blur(radius: 80)
                .offset(x: 150, y: 250)
            
            VStack(spacing: 30) {
                // Header
                HStack {
                    Image(systemName: "flame.fill")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("AI ROAST")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundColor(.red)
                        .tracking(4)
                }
                .padding(.top, 60)
                
                Spacer()
                
                // Content
                VStack(spacing: 16) {
                    Text(LocalizationHelper.shared.translateName(exerciseName).uppercased())
                        .font(.headline)
                        .foregroundColor(themeManager.current.secondaryAccent)
                        .tracking(2)
                    
                    Text("\"\(roastText)\"")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.current.background)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                        .padding(.horizontal, 40)
                        .shadow(color: .red.opacity(0.5), radius: 10, x: 0, y: 5)
                }
                
                Spacer()
                
                // Footer
                HStack {
                    Image(systemName: "applewatch")
                    Text(LocalizedStringKey("Tracked with WorkoutTracker"))
                }
                .font(.title2)
                .foregroundColor(themeManager.current.secondaryAccent.opacity(0.6))
                .padding(.bottom, 60)
            }
        }
        .frame(width: 1080, height: 1080) // 1:1 IG/TikTok ready ratio
    }
}
