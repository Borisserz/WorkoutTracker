internal import SwiftUI

struct AICameraExerciseSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager
    
    let onSelect: (String) -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        VStack(spacing: 8) {
                            Image(systemName: "sparkles.tv")
                                .font(.system(size: 48, weight: .thin))
                                .foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                            
                            Text("AI Form Tracker")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                            
                            Text("Select an exercise to analyze your form in real-time.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                        
                        VStack(spacing: 16) {
                            AICameraExerciseCard(
                                title: "Squats",
                                subtitle: "Track depth and knee alignment",
                                icon: "figure.strengthtraining.traditional",
                                colors: [.blue, .cyan],
                                action: { handleSelection("Squats") }
                            )
                            
                            AICameraExerciseCard(
                                title: "Pushups",
                                subtitle: "Track chest-to-floor and back posture",
                                icon: "figure.core.training",
                                colors: [.orange, .red],
                                action: { handleSelection("Pushups") }
                            )
                            
                            AICameraExerciseCard(
                                title: "Pullups",
                                subtitle: "Track chin over bar and extension",
                                icon: "figure.climbing",
                                colors: [.purple, .pink],
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
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }
            }
        }
    }
    
    private func handleSelection(_ exercise: String) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 60, height: 60)
                        .shadow(color: colors[0].opacity(0.4), radius: 10, y: 5)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .gray)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundColor(colors[0].opacity(0.8))
            }
            .padding(20)
            .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(colors: [colors[0].opacity(0.3), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 15, y: 8)
        }
        .buttonStyle(.plain)
    }
}
