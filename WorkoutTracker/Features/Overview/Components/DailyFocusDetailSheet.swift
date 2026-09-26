internal import SwiftUI

/// Deep sports-science workout focus & coaching advice bottom sheet.
/// Explains kinetic chains, recent fatigue, tactical tips, and recommended exercises.
struct DailyFocusDetailSheet: View {
    let report: BodyAnalysisReport
    let onGoToWorkout: () -> Void
    let onOpenCatalog: () -> Void

    @Environment(\.dismiss) private var dismiss

    init(
        report: BodyAnalysisReport,
        onGoToWorkout: @escaping () -> Void,
        onOpenCatalog: @escaping () -> Void
    ) {
        self.report = report
        self.onGoToWorkout = onGoToWorkout
        self.onOpenCatalog = onOpenCatalog
    }

    private var advice: NextWorkoutAdvice {
        report.nextWorkoutAdvice
    }

    private var cleanSplitTitle: String {
        advice.recommendedSplitTitle.replacingOccurrences(of: "Совет на следующую сессию: ", with: "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PastelTheme.canvas.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {

                        // MARK: - 1. Fatigue Context / Previous Muscle Strain Analysis
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(PastelTheme.pastelSlate)

                                Text("Анализ предыдущих нагрузок")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(PastelTheme.pastelSlate)
                            }

                            Text(advice.recentStrainSummary)
                                .font(.subheadline)
                                .lineSpacing(4)
                                .foregroundStyle(PastelTheme.textPrimary)
                        }
                        .pastelCard(padding: 16)

                        // MARK: - 2. Prescribed Target Split & Rationale
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(PastelTheme.pastelOat)

                                Text("Рекомендуемый сплит")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(PastelTheme.pastelOat)
                            }

                            Text(cleanSplitTitle)
                                .font(.title3.bold())
                                .foregroundStyle(PastelTheme.textPrimary)

                            Text(advice.physiologicalRationale)
                                .font(.subheadline)
                                .lineSpacing(3)
                                .foregroundStyle(PastelTheme.textSecondary)
                        }
                        .pastelCard(padding: 16)

                        // MARK: - 3. Tactical Coaching Tips
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(PastelTheme.pastelSage)

                                Text("Тактические советы тренера")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(PastelTheme.pastelSage)
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(advice.actionableTips, id: \.self) { tip in
                                    HStack(alignment: .top, spacing: 10) {
                                        Circle()
                                            .fill(PastelTheme.pastelSage)
                                            .frame(width: 5, height: 5)
                                            .padding(.top, 6)

                                        Text(tip)
                                            .font(.subheadline)
                                            .lineSpacing(2)
                                            .foregroundStyle(PastelTheme.textPrimary)
                                    }
                                }
                            }
                        }
                        .pastelCard(padding: 16)

                        // MARK: - 4. Recommended Exercises
                        if !advice.recommendedExercises.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 6) {
                                    Image(systemName: "dumbbell.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(PastelTheme.pastelLavender)

                                    Text("Рекомендуемые движения")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(PastelTheme.pastelLavender)
                                }

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(advice.recommendedExercises, id: \.self) { ex in
                                            HStack(spacing: 6) {
                                                Circle()
                                                    .fill(PastelTheme.pastelLavender)
                                                    .frame(width: 5, height: 5)

                                                Text(ex)
                                                    .font(.caption.weight(.medium))
                                                    .foregroundStyle(PastelTheme.textPrimary)
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(PastelTheme.cardSurfaceSubtle)
                                            .clipShape(Capsule())
                                            .overlay(Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1))
                                        }
                                    }
                                }
                            }
                            .pastelCard(padding: 16)
                        }

                        // MARK: - 5. Caution / Sparing Notes
                        if !advice.cautionNotes.isEmpty {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "shield.lefthalf.filled")
                                    .font(.system(size: 15))
                                    .foregroundStyle(PastelTheme.pastelAmber)
                                    .padding(.top, 1)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Внимание")
                                        .font(.caption.bold())
                                        .foregroundStyle(PastelTheme.pastelAmber)

                                    Text(advice.cautionNotes)
                                        .font(.caption)
                                        .foregroundStyle(PastelTheme.textSecondary)
                                        .lineSpacing(2)
                                }
                            }
                            .padding(14)
                            .background(PastelTheme.pastelAmber.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(PastelTheme.pastelAmber.opacity(0.2), lineWidth: 1)
                            )
                        }

                        // MARK: - 6. Action Buttons
                        HStack(spacing: 12) {
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                dismiss()
                                onGoToWorkout()
                            } label: {
                                HStack(spacing: 8) {
                                    Text("Перейти к тренировкам")
                                        .font(.subheadline.bold())
                                    Image(systemName: "arrow.right")
                                        .font(.caption.bold())
                                }
                                .foregroundStyle(PastelTheme.textOnOat)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(PastelTheme.pastelOat)
                                .clipShape(RoundedRectangle(cornerRadius: PastelTheme.buttonRadius, style: .continuous))
                            }
                            .buttonStyle(.plain)

                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                dismiss()
                                onOpenCatalog()
                            } label: {
                                Image(systemName: "books.vertical")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(PastelTheme.pastelOat)
                                    .frame(width: 50, height: 50)
                                    .background(PastelTheme.cardSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: PastelTheme.buttonRadius, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: PastelTheme.buttonRadius, style: .continuous)
                                            .stroke(PastelTheme.cardBorder, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 4)

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Совет на тренировку")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(PastelTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDragIndicator(.visible)
        .presentationDetents([.fraction(0.85), .large])
    }
}
