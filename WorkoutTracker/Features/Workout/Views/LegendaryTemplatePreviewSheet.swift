internal import SwiftUI

struct LegendaryTemplatePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager
    
    let routine: LegendaryRoutine
    let onStart: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                (colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color(UIColor.secondarySystemBackground)).ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Header Section
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: routine.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 80, height: 80)
                                    .blur(radius: 25)
                                    .opacity(0.5)
                                
                                ZStack {
                                    Circle()
                                        .fill(colorScheme == .dark ? themeManager.current.surface : Color.white)
                                        .frame(width: 88, height: 88)
                                        .overlay(Circle().stroke(Color.gray.opacity(0.15), lineWidth: 1))
                                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.1 : 0.05), radius: 10, x: 0, y: 5)
                                    
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 32))
                                        .foregroundStyle(LinearGradient(colors: routine.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                }
                            }
                            .padding(.top, 24)
                            
                            VStack(spacing: 6) {
                                Text(LocalizedStringKey(routine.eraTitle))
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                                    .textCase(.uppercase)
                                
                                Text(LocalizedStringKey(routine.title))
                                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                                    .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .black)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                Text(LocalizedStringKey(routine.shortVibe))
                                    .font(.subheadline)
                                    .italic()
                                    .foregroundColor(.cyan)
                            }
                        }
                        
                        // Lore & Stats Description Card
                        VStack(alignment: .leading, spacing: 16) {
                            Text(LocalizedStringKey(routine.loreDescription))
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .black)
                                .lineSpacing(5)
                                .padding(.horizontal)
                            
                            HStack(spacing: 16) {
                                HStack(spacing: 4) {
                                    Image(systemName: "stopwatch.fill").foregroundColor(.gray)
                                    Text(LocalizedStringKey("~\(routine.estimatedMinutes) min")).fontWeight(.bold)
                                }
                                HStack(spacing: 4) {
                                    Image(systemName: "flame.fill").foregroundColor(.orange)
                                    Text(LocalizedStringKey(routine.difficulty.rawValue)).fontWeight(.bold)
                                }
                            }
                            .font(.subheadline)
                            .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(routine.benefits, id: \.self) { benefit in
                                        Text(LocalizedStringKey(benefit))
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(themeManager.current.primaryAccent.opacity(0.15))
                                            .foregroundColor(themeManager.current.primaryAccent)
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        Divider()
                            .padding(.horizontal)
                            .opacity(0.5)
                        
                        // Exercises List Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text(LocalizedStringKey("Workout Structure"))
                                .font(.headline)
                                .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                                .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                ForEach(routine.exercises, id: \.name) { exercise in
                                    HStack(spacing: 16) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(themeManager.current.primaryAccent.opacity(0.1))
                                                .frame(width: 50, height: 50)
                                            
                                            Image(systemName: exercise.type == "Cardio" ? "figure.run" : "dumbbell.fill")
                                                .foregroundColor(themeManager.current.primaryAccent)
                                                .font(.title3)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(LocalizationHelper.shared.translateName(exercise.name))
                                                .font(.headline)
                                                .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .black)
                                                .lineLimit(1)
                                            
                                            HStack(spacing: 6) {
                                                Text(LocalizedStringKey("\(exercise.sets) sets"))
                                                Text("×")
                                                Text(LocalizedStringKey("\(exercise.reps) reps"))
                                            }
                                            .font(.subheadline)
                                            .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                                        }
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(colorScheme == .dark ? themeManager.current.surfaceVariant : Color.black.opacity(0.05), lineWidth: 1)
                                    )
                                    .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 120)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(colorScheme == .dark ? Color(UIColor.tertiarySystemFill) : .gray.opacity(0.5))
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onStart()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "bolt.fill")
                            .font(.title3)
                        Text(LocalizedStringKey("Start Workout"))
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(themeManager.current.primaryAccent)
                    .cornerRadius(20)
                    .shadow(color: themeManager.current.primaryAccent.opacity(0.4), radius: 15, x: 0, y: 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 10)
                .background(
                    LinearGradient(colors: [(colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color(UIColor.secondarySystemBackground)), (colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color(UIColor.secondarySystemBackground)).opacity(0.0)], startPoint: .bottom, endPoint: .top)
                        .ignoresSafeArea()
                )
            }
        }
        .presentationDragIndicator(.visible)
    }
}
