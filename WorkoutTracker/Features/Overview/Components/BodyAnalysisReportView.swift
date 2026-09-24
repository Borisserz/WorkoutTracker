internal import SwiftUI

/// Deep physiological and neuromuscular readiness report.
/// Sports-science editorial design with calm pastel tones and zero emojis.
struct BodyAnalysisReportView: View {
    let report: BodyAnalysisReport
    var onGoToWorkout: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var selectedMuscleTab: MuscleTab = .prime

    enum MuscleTab: String, CaseIterable, Identifiable {
        case prime = "Готовы к нагрузке"
        case recovering = "Восстановление"

        var id: String { rawValue }
    }

    init(report: BodyAnalysisReport, onGoToWorkout: (() -> Void)? = nil) {
        self.report = report
        self.onGoToWorkout = onGoToWorkout
    }

    private var readinessColor: Color {
        if report.overallReadiness >= 80 {
            return PastelTheme.pastelSage
        } else if report.overallReadiness >= 55 {
            return PastelTheme.pastelAmber
        } else {
            return PastelTheme.pastelPeach
        }
    }

    private var readinessSummaryText: String {
        if report.overallReadiness >= 85 {
            return "Пиковая готовность к нагрузке"
        } else if report.overallReadiness >= 70 {
            return "Оптимальная рабочая форма"
        } else if report.overallReadiness >= 55 {
            return "Умеренное накопленное утомление"
        } else {
            return "Требуется активный отдых"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PastelTheme.canvas.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        
                        // MARK: - 1. Hero Readiness Score Card
                        HStack(alignment: .center, spacing: 16) {
                            ZStack {
                                Circle()
                                    .stroke(PastelTheme.cardSurfaceSubtle, lineWidth: 8)
                                    .frame(width: 82, height: 82)

                                Circle()
                                    .trim(from: 0, to: CGFloat(report.overallReadiness) / 100.0)
                                    .stroke(
                                        readinessColor,
                                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                    )
                                    .frame(width: 82, height: 82)
                                    .rotationEffect(.degrees(-90))

                                VStack(spacing: 0) {
                                    Text("\(report.overallReadiness)%")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundStyle(PastelTheme.textPrimary)
                                }
                            }

                            VStack(alignment: .leading, spacing: 5) {
                                Text("Системная готовность")
                                    .font(.caption)
                                    .foregroundStyle(PastelTheme.textSecondary)

                                Text(readinessSummaryText)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(readinessColor)

                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(PastelTheme.pastelLavender)
                                        .frame(width: 5, height: 5)

                                    Text("ЦНС: \(report.cnsStatusTitle)")
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(PastelTheme.pastelLavender)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(PastelTheme.cardSurfaceSubtle)
                                .clipShape(Capsule())
                            }

                            Spacer()
                        }
                        .pastelCard(padding: 16)

                        // MARK: - 2. Executive Assessment
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 7) {
                                Image(systemName: "waveform.path.ecg")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(PastelTheme.pastelSage)

                                Text("Физиологическое резюме")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(PastelTheme.textPrimary)
                            }

                            Text(report.executiveAssessment)
                                .font(.subheadline)
                                .lineSpacing(4)
                                .foregroundStyle(PastelTheme.textSecondary)
                        }
                        .pastelCard(padding: 16)

                        // MARK: - 3. Recommended Protocol & Restrictions
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Рекомендованный протокол")
                                .font(.subheadline.bold())
                                .foregroundStyle(PastelTheme.textPrimary)

                            VStack(alignment: .leading, spacing: 10) {
                                // Target split
                                HStack(alignment: .top, spacing: 10) {
                                    Circle()
                                        .fill(PastelTheme.pastelSage)
                                        .frame(width: 7, height: 7)
                                        .padding(.top, 5)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Целевой фокус")
                                            .font(.caption2)
                                            .foregroundStyle(PastelTheme.textTertiary)

                                        Text(report.recommendedTargetTitle)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(PastelTheme.textPrimary)
                                    }
                                }

                                Divider()
                                    .background(PastelTheme.cardBorder)

                                // Sparing / restriction
                                HStack(alignment: .top, spacing: 10) {
                                    Circle()
                                        .fill(PastelTheme.pastelAmber)
                                        .frame(width: 7, height: 7)
                                        .padding(.top, 5)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Меры предосторожности")
                                            .font(.caption2)
                                            .foregroundStyle(PastelTheme.textTertiary)

                                        Text(report.recommendedRestrictions)
                                            .font(.subheadline)
                                            .foregroundStyle(PastelTheme.textSecondary)
                                    }
                                }
                            }
                        }
                        .pastelCard(padding: 16)

                        // MARK: - 4. Muscle Breakdown Tabs (Full-width, clean list)
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Состояние мышечных групп")
                                .font(.subheadline.bold())
                                .foregroundStyle(PastelTheme.textPrimary)

                            // Segmented Picker
                            Picker("Мышцы", selection: $selectedMuscleTab) {
                                Text("Готовы (\(report.primeMuscles.count))").tag(MuscleTab.prime)
                                Text("Восстановление (\(report.recoveringMuscles.count))").tag(MuscleTab.recovering)
                            }
                            .pickerStyle(.segmented)

                            // List of muscles
                            let currentList = (selectedMuscleTab == .prime) ? report.primeMuscles : report.recoveringMuscles

                            if currentList.isEmpty {
                                HStack(spacing: 10) {
                                    Image(systemName: "checkmark.seal")
                                        .font(.title3)
                                        .foregroundStyle(PastelTheme.pastelSage)

                                    Text(selectedMuscleTab == .prime ? "Все мышцы на восстановлении" : "Все мышцы полностью отдохнули")
                                        .font(.subheadline)
                                        .foregroundStyle(PastelTheme.textSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(currentList) { item in
                                        HStack(alignment: .center, spacing: 12) {
                                            Circle()
                                                .fill(item.percentage >= 80 ? PastelTheme.pastelSage : (item.percentage >= 55 ? PastelTheme.pastelAmber : PastelTheme.pastelPeach))
                                                .frame(width: 7, height: 7)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.name)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(PastelTheme.textPrimary)

                                                Text(item.percentage >= 80 ? "Полностью восстановлены" : "~\(item.hoursRemaining) ч до суперкомпенсации")
                                                    .font(.caption2)
                                                    .foregroundStyle(PastelTheme.textSecondary)
                                            }

                                            Spacer()

                                            Text("\(item.percentage)%")
                                                .font(.caption.bold())
                                                .foregroundStyle(item.percentage >= 80 ? PastelTheme.textOnOat : PastelTheme.textPrimary)
                                                .padding(.horizontal, 9)
                                                .padding(.vertical, 4)
                                                .background(item.percentage >= 80 ? PastelTheme.pastelSage : PastelTheme.cardSurfaceSubtle)
                                                .clipShape(Capsule())
                                                .overlay(
                                                    Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1)
                                                )
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(PastelTheme.cardSurfaceSubtle)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(PastelTheme.cardBorder, lineWidth: 1)
                                        )
                                    }
                                }
                            }
                        }
                        .pastelCard(padding: 16)

                        // MARK: - 5. Primary Action
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            dismiss()
                            onGoToWorkout?()
                        } label: {
                            HStack(spacing: 8) {
                                Text(onGoToWorkout != nil ? "Перейти к тренировкам" : "Закрыть отчёт")
                                    .font(.subheadline.bold())
                                if onGoToWorkout != nil {
                                    Image(systemName: "arrow.right")
                                        .font(.caption.bold())
                                }
                            }
                            .foregroundStyle(PastelTheme.textOnOat)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(PastelTheme.pastelOat)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Анализ тела")
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
    }
}
