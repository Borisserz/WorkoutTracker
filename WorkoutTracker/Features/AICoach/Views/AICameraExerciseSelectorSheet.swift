internal import SwiftUI

struct AICameraExerciseSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager
    
    let onSelect: (String) -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? PastelTheme.canvas : Color(UIColor.systemGroupedBackground))
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        VStack(spacing: 8) {
                            Image(systemName: "sparkles.tv")
                                .font(.system(size: 44, weight: .light))
                                .foregroundStyle(PastelTheme.pastelLavender)
                            
                            Text("AI form control")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black)
                            
                            Text("Pick an exercise for live form analysis and rep counting.")
                                .font(.subheadline)
                                .foregroundColor(PastelTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                        
                        VStack(spacing: 16) {
                            AICameraExerciseCard(
                                title: "Squats",
                                subtitle: "Depth and knee tracking",
                                icon: "figure.strengthtraining.traditional",
                                colors: [PastelTheme.pastelSlate, PastelTheme.pastelSlate.opacity(0.7)],
                                action: { handleSelection("Squats") }
                            )
                            
                            AICameraExerciseCard(
                                title: "Push-ups",
                                subtitle: "Chest touch and a straight body line",
                                icon: "figure.core.training",
                                colors: [PastelTheme.pastelAmber, PastelTheme.pastelAmber.opacity(0.7)],
                                action: { handleSelection("Pushups") }
                            )
                            
                            AICameraExerciseCard(
                                title: "Pull-ups",
                                subtitle: "Chin over the bar and full arm extension",
                                icon: "figure.climbing",
                                colors: [PastelTheme.pastelLavender, PastelTheme.pastelLavender.opacity(0.7)],
                                action: { handleSelection("Pullups") }
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(PastelTheme.textMuted)
                    }
                }
            }
        }
    }
    
    private func handleSelection(_ exercise: String) {
        HapticManager.shared.impact(.medium)
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onSelect(exercise)
        }
    }
}

struct AICameraExerciseCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let colors: [Color]
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(PastelTheme.cardSurfaceSubtle)
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(colors[0])
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(PastelTheme.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundColor(PastelTheme.textMuted)
            }
            .padding(18)
            .background(colorScheme == .dark ? PastelTheme.cardSurface : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
