// ============================================================
// FILE: WorkoutTracker/Features/AICoach/Views/InWorkoutAICoachView.swift
// ============================================================

internal import SwiftUI
import SwiftData

struct InWorkoutAICoachView: View {
    @Bindable var workout: Workout
    @Bindable var viewModel: InWorkoutAICoachViewModel
    
    @Environment(WorkoutDetailViewModel.self) private var detailViewModel
    @Environment(ThemeManager.self) private var themeManager // <--- ДОБАВЛЕНО: Инъекция менеджера тем
    @AppStorage(Constants.UserDefaultsKeys.userGender.rawValue) private var userGender = "male"

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                
                // --- 1. TOP: LIVE MUSCLE STATUS (Glass Card) ---
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "bolt.shield.fill")
                            .font(.title3)
                            .foregroundColor(themeManager.current.primaryAccent) // <--- ИЗМЕНЕНО
                        Text(LocalizedStringKey("Live Tension"))
                            .font(.headline)
                            .bold()
                        Spacer()
                        Text(LocalizedStringKey("AI Active"))
                            .font(.caption2)
                            .bold()
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(themeManager.current.primaryAccent.opacity(0.2)) // <--- ИЗМЕНЕНО
                            .foregroundColor(themeManager.current.primaryAccent) // <--- ИЗМЕНЕНО
                            .cornerRadius(6)
                    }
                    
                    HStack(spacing: 20) {
                        BodyHeatmapView(
                            muscleIntensities: detailViewModel.workoutAnalytics.intensity,
                            isRecoveryMode: false,
                            isCompactMode: true,
                            userGender: userGender
                        )
                        .frame(width: 80, height: 160)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                        .shadow(color: themeManager.current.primaryAccent.opacity(0.15), radius: 10) // <--- ИЗМЕНЕНО
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text(LocalizedStringKey("Coach is monitoring your output. High tension detected in target muscle groups."))
                                .font(.subheadline)
                                .foregroundColor(themeManager.current.secondaryText)
                                .lineSpacing(4)
                            Spacer()
                            HStack {
                                Circle().fill(Color.green).frame(width: 8, height: 8).symbolEffect(.pulse) // Семантический зеленый оставлен
                                Text(LocalizedStringKey("Ready for adjustments")).font(.caption).foregroundColor(.green)
                            }
                        }
                    }
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .cornerRadius(28)
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.1), lineWidth: 1))

                // --- 2. CENTER: SMART COMMANDS GRID ---
                VStack(alignment: .leading, spacing: 16) {
                    Text(LocalizedStringKey("Intelligent Adjustments"))
                        .font(.title3)
                        .bold()
                        .padding(.horizontal, 4)
                    
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                        // <--- ИЗМЕНЕНО: Использование темы для нейтральных кнопок, сохранение .orange и .green для семантики
                        smartActionTile(id: "busy", title: "Equipment Busy", icon: "lock.fill", command: "Equipment is taken, swap exercise", color: themeManager.current.primaryAccent)
                        smartActionTile(id: "heavy", title: "Too Heavy", icon: "arrow.down.circle.fill", command: "Weight is too heavy, reduce load", color: .orange)
                        smartActionTile(id: "easy", title: "Too Easy", icon: "arrow.up.circle.fill", command: "Too easy, increase weight or intensity", color: .green)
                        smartActionTile(id: "finish", title: "Add Finisher", icon: "flame.fill", command: "Add a final pump isolation exercise", color: themeManager.current.deepPremiumAccent)
                    }
                }

                // --- 3. BOTTOM: PROPOSAL CARD (Floating Look) ---
                if let proposal = viewModel.activeProposal {
                    AIProposalPremiumCard(proposal: proposal) {
                        viewModel.applyActiveProposal(to: workout)
                    } onDismiss: {
                        viewModel.discardProposal()
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
                        removal: .scale.combined(with: .opacity)
                    ))
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.activeProposal)
    }

    @ViewBuilder
    private func smartActionTile(id: String, title: String, icon: String, command: String, color: Color) -> some View {
        let isProcessing = viewModel.isProcessing && viewModel.activeCommandId == command
        
        Button {
            viewModel.sendSmartCommand(command, currentWorkout: workout)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    if isProcessing {
                        ProgressView().tint(color)
                    } else {
                        Image(systemName: icon)
                            .foregroundColor(color)
                            .font(.title3)
                    }
                }
                
                Text(LocalizedStringKey(title))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.current.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isProcessing ? color : Color.white.opacity(0.1), lineWidth: isProcessing ? 2 : 1)
            )
            .shadow(color: color.opacity(isProcessing ? 0.3 : 0.0), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isProcessing || !workout.isActive)
        .opacity(workout.isActive ? 1.0 : 0.5)
    }
}

// MARK: - AI Proposal Premium Card
struct AIProposalPremiumCard: View {
    let proposal: SmartActionDTO
    let onApply: () -> Void
    let onDismiss: () -> Void
    @Environment(UnitsManager.self) var unitsManager
    @Environment(ThemeManager.self) private var themeManager // <--- ДОБАВЛЕНО: Инъекция менеджера тем

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Label(LocalizedStringKey("Coach Recommendation"), systemImage: "sparkles")
                    .font(.caption.bold())
                    .foregroundColor(themeManager.current.primaryAccent) // <--- ИЗМЕНЕНО
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(themeManager.current.primaryAccent.opacity(0.1)) // <--- ИЗМЕНЕНО
                    .cornerRadius(8)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary, Color.gray.opacity(0.2))
                }
            }
            
            Text(proposal.reasoning)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(themeManager.current.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineSpacing(4)
            
            HStack(spacing: 15) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("EXERCISE")).font(.system(size: 10, weight: .bold)).foregroundColor(themeManager.current.secondaryText)
                    Text(LocalizationHelper.shared.translateName(proposal.exerciseName)).font(.subheadline).bold().lineLimit(1)
                }
                Divider().frame(height: 30)
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("SETS")).font(.system(size: 10, weight: .bold)).foregroundColor(themeManager.current.secondaryText)
                    Text("\(proposal.setsRemaining)").font(.subheadline).bold()
                }
                Divider().frame(height: 30)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(LocalizedStringKey("WEIGHT")).font(.system(size: 10, weight: .bold)).foregroundColor(themeManager.current.secondaryText)
                    Text("\(Int(unitsManager.convertFromKilograms(proposal.weightValue))) \(unitsManager.weightUnitString())")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(themeManager.current.primaryAccent) // <--- ИЗМЕНЕНО
                }
            }
            .padding()
            .background(Color.black.opacity(0.15))
            .cornerRadius(16)
            
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                onApply()
            }) {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                    Text(LocalizedStringKey("Apply to Workout")).bold()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(themeManager.current.primaryGradient) // <--- ИЗМЕНЕНО
                .foregroundColor(.white)
                .cornerRadius(16)
                .shadow(color: themeManager.current.primaryAccent.opacity(0.4), radius: 10, x: 0, y: 5) // <--- ИЗМЕНЕНО
            }
        }
        .padding(24)
        .background(themeManager.current.surface)
        .cornerRadius(32)
        .overlay(RoundedRectangle(cornerRadius: 32).stroke(themeManager.current.primaryAccent.opacity(0.3), lineWidth: 1.5)) // <--- ИЗМЕНЕНО
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
    }
}
