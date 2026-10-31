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
                            
                            Text("ИИ-контроль формы")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black)
                            
                            Text("Выберите упражнение для анализа техники и подсчета повторений в реальном времени.")
                                .font(.subheadline)
                                .foregroundColor(PastelTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                        
                        VStack(spacing: 16) {
                            AICameraExerciseCard(
                                title: "Приседания",
                                subtitle: "Контроль глубины седа и положения коленей",
                                icon: "figure.strengthtraining.traditional",
                                colors: [PastelTheme.pastelSlate, PastelTheme.pastelSlate.opacity(0.7)],
                                action: { handleSelection("Squats") }
                            )
                            
                            AICameraExerciseCard(
                                title: "Отжимания",
                                subtitle: "Контроль касания пола и ровной линии корпуса",
                                icon: "figure.core.training",
                                colors: [PastelTheme.pastelAmber, PastelTheme.pastelAmber.opacity(0.7)],
                                action: { handleSelection("Pushups") }
                            )
                            
                            AICameraExerciseCard(
                                title: "Подтягивания",
                                subtitle: "Контроль подбородка над турником и выпрямления рук",
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
