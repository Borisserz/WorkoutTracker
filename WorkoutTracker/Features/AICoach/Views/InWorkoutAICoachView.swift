

internal import SwiftUI
import SwiftData

struct InWorkoutAICoachView: View {
    @Bindable var workout: Workout
    @Bindable var viewModel: InWorkoutAICoachViewModel

    @Environment(WorkoutDetailViewModel.self) private var detailViewModel
    @AppStorage(Constants.UserDefaultsKeys.userGender.rawValue) private var userGender = "male"
    @Environment(TutorialManager.self) var tutorialManager

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "bolt.shield.fill")
                            .font(.title3)
                            .foregroundColor(PastelTheme.pastelLavender)
                        Text("Мышечное напряжение")
                            .font(.headline)
                            .bold()
                        Spacer()
                        Text("ИИ активен")
                            .font(.caption2)
                            .bold()
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(PastelTheme.cardSurfaceSubtle)
                            .foregroundColor(PastelTheme.pastelLavender)
                            .cornerRadius(6)
                    }

                    HStack(spacing: 20) {
                        BodyHeatmapView(
                            muscleIntensities: detailViewModel.workoutAnalytics.intensity,
                            isRecoveryMode: false,
                            isCompactMode: true,
                            userGender: userGender,
                            showLabels: false   
                        )
                        .frame(width: 80, height: 160)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.15), radius: 10)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("ИИ анализирует объем работы и мышечную нагрузку целевых групп.")
                                .font(.subheadline)
                                .foregroundColor(PastelTheme.textSecondary)
                                .lineSpacing(4)
                            Spacer()
                            HStack {
                                Circle().fill(PastelTheme.pastelSage).frame(width: 8, height: 8).symbolEffect(.pulse)
                                Text("Готов к корректировкам").font(.caption).foregroundColor(PastelTheme.pastelSage)
                            }
                        }
                    }
                }
                .padding(20)
                .background(PastelTheme.cardSurface)
                .cornerRadius(24)
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(PastelTheme.cardBorder, lineWidth: 1))


                VStack(alignment: .leading, spacing: 16) {
                    Text("Умные корректировки")
                        .font(.title3)
                        .bold()
                        .padding(.horizontal, 4)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                        smartActionTile(id: "busy", title: "Занят снаряд", icon: "lock.fill", command: "Equipment is taken, swap exercise", color: PastelTheme.pastelSlate)
                        smartActionTile(id: "heavy", title: "Тяжело", icon: "arrow.down.circle.fill", command: "Weight is too heavy, reduce load", color: PastelTheme.pastelAmber)
                        smartActionTile(id: "easy", title: "Легко", icon: "arrow.up.circle.fill", command: "Too easy, increase weight or intensity", color: PastelTheme.pastelSage)
                        smartActionTile(id: "finish", title: "Памп-финишер", icon: "flame.fill", command: "Add a final pump isolation exercise", color: PastelTheme.pastelLavender)
                    }
                }

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
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.activeProposal)
        .sheet(isPresented: $viewModel.showConsentSheet) {
            AIConsentSheet(onConsent: { viewModel.retryPendingCommand() })
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            if UserDefaults.standard.bool(forKey: "hasSeenFeatureDiscovery") && !UserDefaults.standard.bool(forKey: "hasSeenAICameraSpotlight") {
                if tutorialManager.currentStep == .completed || tutorialManager.currentStep == .discoverPhotoCompare {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        tutorialManager.setStep(.discoverAICamera)
                        UserDefaults.standard.set(true, forKey: "hasSeenAICameraSpotlight")
                    }
                }
            }
        }
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
                    .foregroundColor(.primary)
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

struct AIProposalPremiumCard: View {
    let proposal: SmartActionDTO
    let onApply: () -> Void
    let onDismiss: () -> Void
    @Environment(UnitsManager.self) var unitsManager

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Label("Рекомендация тренера", systemImage: "sparkles")
                    .font(.caption.bold())
                    .foregroundColor(PastelTheme.pastelLavender)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(PastelTheme.cardSurfaceSubtle)
                    .cornerRadius(8)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(PastelTheme.textMuted, Color.gray.opacity(0.2))
                }
            }

            Text(proposal.reasoning)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(PastelTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineSpacing(4)

            HStack(spacing: 15) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Упражнение").font(.system(size: 11, weight: .semibold)).foregroundColor(PastelTheme.textSecondary)
                    Text(LocalizationHelper.shared.translateName(proposal.exerciseName)).font(.subheadline).bold().lineLimit(1)
                }
                Divider().frame(height: 30)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Подходы").font(.system(size: 11, weight: .semibold)).foregroundColor(PastelTheme.textSecondary)
                    Text("\(proposal.setsRemaining)").font(.subheadline).bold()
                }
                Divider().frame(height: 30)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Вес").font(.system(size: 11, weight: .semibold)).foregroundColor(PastelTheme.textSecondary)
                    Text("\(Int(unitsManager.convertFromKilograms(proposal.weightValue))) \(unitsManager.weightUnitString())")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(PastelTheme.pastelSage)
                }
            }
            .padding()
            .background(PastelTheme.cardSurfaceSubtle)
            .cornerRadius(16)

            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                onApply()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("Применить к тренировке").bold()
                }
                .foregroundColor(PastelTheme.textOnOat)
                .frame(maxWidth: .infinity)
                .frame(height: PastelTheme.ButtonMetrics.heroHeight)
                .background(PastelTheme.pastelOat)
                .clipShape(RoundedRectangle(cornerRadius: PastelTheme.ButtonMetrics.heroRadius, style: .continuous))
                .shadow(color: PastelTheme.pastelOat.opacity(0.15), radius: 10, y: 4)
            }
        }
        .padding(24)
        .background(PastelTheme.cardSurface)
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(PastelTheme.cardBorder, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}
