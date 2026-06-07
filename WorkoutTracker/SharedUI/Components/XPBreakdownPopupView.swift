internal import SwiftUI

struct XPBreakdownPopupView: View {
    let breakdown: XPBreakdown
    let isLevelUp: Bool
    let newLevel: Int
    let newTitle: String
    let onDismiss: () -> Void

    @State private var showContent = false
    @State private var fillProgress: CGFloat = 0.0
    @State private var animatedBase = 0
    @State private var animatedDuration = 0
    @State private var animatedSets = 0
    @State private var animatedPR = 0
    @State private var animatedVolume = 0
    @State private var animatedTotal = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            VStack(spacing: 24) {
                if isLevelUp {
                    Text("LEVEL UP!")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: .orange.opacity(0.8), radius: 10, y: 5)
                        .scaleEffect(showContent ? 1.0 : 0.5)
                        .opacity(showContent ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2), value: showContent)

                    VStack(spacing: 4) {
                        Text("Level \(newLevel)")
                            .font(.title2.bold())
                        Text(newTitle)
                            .font(.title3.weight(.medium))
                            .foregroundColor(.cyan)
                    }
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeIn.delay(0.4), value: showContent)
                } else {
                    Text("WORKOUT COMPLETE")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeIn.delay(0.2), value: showContent)
                }

                VStack(spacing: 16) {
                    xpRow(title: "Base XP", value: animatedBase)
                    xpRow(title: "Duration XP", value: animatedDuration)
                    xpRow(title: "Sets XP", value: animatedSets)
                    if breakdown.prXP > 0 {
                        xpRow(title: "PR Bonus", value: animatedPR, color: .yellow)
                    }
                    xpRow(title: "Volume XP", value: animatedVolume)

                    Divider().background(Color.white.opacity(0.3))

                    HStack {
                        Text("Total XP Earned")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        Text("+\(animatedTotal) XP")
                            .font(.title3.bold().monospacedDigit())
                            .foregroundColor(.green)
                    }
                    if breakdown.effortMultiplier > 1.0 {
                        Text("Includes \(String(format: "%.1f", breakdown.effortMultiplier))x Effort Multiplier")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(16)
                .opacity(showContent ? 1 : 0)

                Button(action: onDismiss) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                }
                .padding(.top, 8)
                .opacity(showContent ? 1 : 0)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(UIColor.systemGray6))
                    .shadow(color: Color.purple.opacity(isLevelUp ? 0.6 : 0.2), radius: 30)
            )
            .padding(.horizontal, 32)
            .rotation3DEffect(.degrees(showContent ? 0 : 20), axis: (x: 1, y: 0, z: 0))
            .scaleEffect(showContent ? 1 : 0.8)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showContent = true
            }
            animateNumbers()
        }
    }

    private func xpRow(title: String, value: Int, color: Color = .white) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
            Spacer()
            Text("+\(value)")
                .font(.subheadline.bold().monospacedDigit())
                .foregroundColor(color)
        }
    }

    private func animateNumbers() {
        // Sequential animation
        let steps = 20
        let interval = 0.05

        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
                let fraction = Double(i) / Double(steps)
                animatedBase = Int(Double(breakdown.baseXP) * fraction)
            }
        }

        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 + interval * Double(i)) {
                let fraction = Double(i) / Double(steps)
                animatedDuration = Int(Double(breakdown.durationXP) * fraction)
                animatedSets = Int(Double(breakdown.setsXP) * fraction)
                animatedPR = Int(Double(breakdown.prXP) * fraction)
                animatedVolume = Int(Double(breakdown.volumeXP) * fraction)
            }
        }

        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0 + interval * Double(i)) {
                let fraction = Double(i) / Double(steps)
                animatedTotal = Int(Double(breakdown.total) * fraction)
            }
        }
    }
}
