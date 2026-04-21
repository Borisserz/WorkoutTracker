

internal import SwiftUI

struct MuscleSelectionView: View {
    @Bindable var vm: SmartGeneratorViewModel
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme 

    var body: some View {
        ZStack(alignment: .bottom) {

            (colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground))
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("What are we training today?")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : .black) 
                        .padding(.horizontal)
                        .padding(.top, 10)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(vm.availableMuscles, id: \.self) { muscle in
                            let isSelected = vm.targetMuscles.contains(muscle)
                            Button {
                                                            vm.toggleMuscle(muscle)
                                                        } label: {
                                                            VStack {
                                                                Image(systemName: icon(for: muscle))
                                                                    .font(.title)
                                                                    .foregroundColor(isSelected ? .white : (colorScheme == .dark ? .secondary : themeManager.current.primaryAccent)) 
                                                                    .padding(.bottom, 4)

                                                                Text(LocalizedStringKey(muscle))
                                                                    .font(.headline)
                                                                    .foregroundColor(isSelected ? .white : (colorScheme == .dark ? .primary : .black))
                                                            }
                                                            .frame(maxWidth: .infinity)
                                                            .padding(.vertical, 24)
                                                            .background(
                                                                ZStack {
                                                                    (colorScheme == .dark ? themeManager.current.surface : Color.white)
                                                                    if isSelected {
                                                                        themeManager.current.primaryAccent 
                                                                    }
                                                                }
                                                            )
                                                            .cornerRadius(20)
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: 20)
                                                                    .stroke(isSelected ? themeManager.current.primaryAccent : (colorScheme == .dark ? Color.clear : Color.black.opacity(0.05)), lineWidth: isSelected ? 0 : 1)
                                                            )
                                                            .shadow(color: isSelected ? themeManager.current.primaryAccent.opacity(0.4) : .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 10, x: 0, y: 5)
                                                        }
                                                        .buttonStyle(.plain)
                                                        .scaleEffect(isSelected ? 1.02 : 1.0)
                                                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 120)
                }
            }

            Button {
                let gen = UIImpactFeedbackGenerator(style: .medium)
                gen.impactOccurred()
                vm.path.append("Settings")
            } label: {
                Text("Next Step")
                    .font(.headline).bold()
                    .foregroundColor(themeManager.current.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(vm.targetMuscles.isEmpty ? Color.gray : themeManager.current.primaryAccent)
                    .clipShape(Capsule())
                    .shadow(color: vm.targetMuscles.isEmpty ? .clear : themeManager.current.primaryAccent.opacity(0.4), radius: 10, x: 0, y: 5)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
            .disabled(vm.targetMuscles.isEmpty)
            .animation(.easeInOut, value: vm.targetMuscles.isEmpty)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func icon(for muscle: String) -> String {
        switch muscle {
        case "Chest": return "shield.fill"
        case "Back": return "arrow.up.and.down.and.sparkles"
        case "Legs": return "figure.walk"
        case "Shoulders": return "figure.arms.open"
        case "Arms": return "hand.raised.fill"
        case "Core": return "bolt.shield.fill"
        case "Cardio": return "heart.fill"
        default: return "dumbbell.fill"
        }
    }
}

struct GeneratorSettingsView: View {
    @Bindable var vm: SmartGeneratorViewModel
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(DashboardViewModel.self) private var dashboard

    var body: some View {
        ZStack(alignment: .bottom) {

            (colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground))
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {

                    VStack(alignment: .leading, spacing: 8) {
                        Text("AI Configuration")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                        Text("Refine parameters to generate your perfect workout.")
                            .font(.subheadline)
                            .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            ZStack {
                                Circle().fill(Color.cyan.opacity(0.15)).frame(width: 36, height: 36)
                                Image(systemName: "stopwatch.fill").foregroundColor(.cyan)
                            }
                            Text("Duration")
                                .font(.headline)
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                            Spacer()
                            Text("\(Int(vm.durationMinutes)) мин")
                                .font(.title2).bold()
                                .foregroundColor(.cyan)
                                .contentTransition(.numericText())
                        }

                        Slider(value: $vm.durationMinutes, in: 15...120, step: 5)
                            .tint(.cyan)

                        HStack {
                            Text("15 мин").font(.caption2).bold().foregroundColor(.gray)
                            Spacer()
                            Text("120 мин").font(.caption2).bold().foregroundColor(.gray)
                        }
                    }
                    .modifier(PremiumCardModifier(colorScheme: colorScheme, themeManager: themeManager))

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            ZStack {
                                Circle().fill(Color.orange.opacity(0.15)).frame(width: 36, height: 36)
                                Image(systemName: "flame.fill").foregroundColor(.orange)
                            }
                            Text("Experience Level")
                                .font(.headline)
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                        }

                        HStack(spacing: 8) {
                            ForEach(WorkoutDifficulty.allCases, id: \.self) { diff in
                                let isSelected = vm.difficulty == diff
                                Button {
                                    UISelectionFeedbackGenerator().selectionChanged()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { vm.difficulty = diff }
                                } label: {
                                    Text(LocalizedStringKey(diff.rawValue))
                                        .font(.subheadline)
                                        .fontWeight(isSelected ? .bold : .medium)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(isSelected ? Color.orange : (colorScheme == .dark ? Color.white.opacity(0.05) : Color(UIColor.systemGray6)))
                                        .foregroundColor(isSelected ? .white : (colorScheme == .dark ? .white : .black))
                                        .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .modifier(PremiumCardModifier(colorScheme: colorScheme, themeManager: themeManager))

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            ZStack {
                                Circle().fill(Color.purple.opacity(0.15)).frame(width: 36, height: 36)
                                Image(systemName: "dumbbell.fill").foregroundColor(.purple)
                            }
                            Text("Equipment")
                                .font(.headline)
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                        }

                        VStack(spacing: 12) {
                            ForEach(WorkoutEquipment.allCases, id: \.self) { eq in
                                let isSelected = vm.equipment == eq
                                Button {
                                    UISelectionFeedbackGenerator().selectionChanged()
                                    withAnimation(.spring()) { vm.equipment = eq }
                                } label: {
                                    HStack {
                                        Text(LocalizedStringKey(eq.rawValue))
                                            .font(.subheadline)
                                            .fontWeight(isSelected ? .bold : .medium)
                                        Spacer()
                                        if isSelected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.purple)
                                                .font(.title3)
                                        }
                                    }
                                    .padding()
                                    .background(isSelected ? Color.purple.opacity(0.1) : Color.clear)
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color.purple.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                            }
                        }
                    }
                    .modifier(PremiumCardModifier(colorScheme: colorScheme, themeManager: themeManager))

                }
                .padding(.bottom, 120) 
            }

            VStack {
                Spacer()
                Button {
                    Task { await vm.generateWorkout(historyCache: dashboard.lastPerformancesCache) }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.title3)
                        Text("Generate AI Routine")
                            .font(.headline).bold()
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(themeManager.current.primaryGradient)
                    .clipShape(Capsule())
                    .shadow(color: themeManager.current.deepPremiumAccent.opacity(0.5), radius: 15, x: 0, y: 8)
                    .padding(.horizontal, 24)
                }
            }
            .padding(.bottom, 16)

            .background(
                LinearGradient(colors: [(colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground)), .clear], startPoint: .bottom, endPoint: .top)
                    .frame(height: 100)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            )
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PremiumCardModifier: ViewModifier {
    let colorScheme: ColorScheme
    let themeManager: ThemeManager

    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.05 : 0.05), radius: 10, y: 5)
            .padding(.horizontal, 20)
    }
}
