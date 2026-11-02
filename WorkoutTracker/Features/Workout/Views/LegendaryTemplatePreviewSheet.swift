internal import SwiftUI

/// Luxury modal preview sheet for a Legendary Routine.
/// Adheres strictly to PastelTheme (Strict Dark Mode #0E0F12) and Apple HIG HUD specifications.
/// Features mechanical architectural hero card, corner micro-screws, specular rim bevel highlight,
/// tier 1 fixed-height CTA (50pt) with two-phase tactile haptics, and zero neon slop.
struct LegendaryTemplatePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PresetService.self) private var presetService
    
    let routine: LegendaryRoutine
    let onStart: () -> Void
    
    @State private var isSaving = false
    @State private var showSavedToast = false
    
    var eraColor: Color {
        let lower = (routine.eraTitle + " " + routine.title).lowercased()
        if lower.contains("golden") || lower.contains("arnold") {
            return PastelTheme.pastelAmber
        } else if lower.contains("olympia") || lower.contains("dc") || lower.contains("brutality") {
            return PastelTheme.pastelPeach
        } else if lower.contains("calisthenics") || lower.contains("xero") {
            return PastelTheme.pastelSage
        } else if lower.contains("olympic") || lower.contains("bulgarian") || lower.contains("power") {
            return PastelTheme.pastelLavender
        }
        return PastelTheme.pastelOat
    }

    var eraIcon: String {
        let lower = (routine.eraTitle + " " + routine.title).lowercased()
        if lower.contains("calisthenics") || lower.contains("xero") {
            return "figure.strengthtraining.traditional"
        } else if lower.contains("arnold") || lower.contains("golden") {
            return "crown.fill"
        } else if lower.contains("olympia") || lower.contains("dc") || lower.contains("brutality") {
            return "trophy.fill"
        } else if lower.contains("olympic") || lower.contains("bulgarian") || lower.contains("power") {
            return "bolt.fill"
        } else if lower.contains("combat") || lower.contains("gladiator") {
            return "shield.fill"
        }
        return "star.fill"
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                PastelTheme.canvas.ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        
                        // Header Title Section
                        VStack(spacing: 6) {
                            Text("Hall of Fame")
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                                .foregroundStyle(PastelTheme.textPrimary)
                            
                            Text("Train like the legends of every era.")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(PastelTheme.textSecondary)
                        }
                        .padding(.top, 16)
                        
                        // Architectural Pressure Hero Card
                        heroPlateCard
                        
                        // Protocol Exercise Roster
                        exerciseRosterCard
                        
                        // Bottom Actions: Start Routine CTA (Tier 1) & Save Library (Tier 2)
                        actionsSection
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                
                // Floating Close Button
                HStack {
                    Button {
                        HapticManager.shared.impact(.light)
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(PastelTheme.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(PastelTheme.cardSurfaceSubtle)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(PastelTheme.cardBorder, lineWidth: 1))
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
        .preferredColorScheme(.dark)
        .presentationDragIndicator(.visible)
    }

    // MARK: - Hero Plate Card
    private var heroPlateCard: some View {
        ZStack {
            // Slab Background with Specular Top Rim
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(PastelTheme.cardSurface)
                .overlay(
                    LinearGradient(
                        colors: [Color.white.opacity(0.09), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                )
            
            // Corner Micro-Screws
            VStack {
                HStack {
                    Circle().fill(PastelTheme.cardBorder.opacity(0.4)).frame(width: 3.5, height: 3.5)
                    Spacer()
                    Circle().fill(PastelTheme.cardBorder.opacity(0.4)).frame(width: 3.5, height: 3.5)
                }
                Spacer()
                HStack {
                    Circle().fill(PastelTheme.cardBorder.opacity(0.4)).frame(width: 3.5, height: 3.5)
                    Spacer()
                    Circle().fill(PastelTheme.cardBorder.opacity(0.4)).frame(width: 3.5, height: 3.5)
                }
            }
            .padding(8)

            // Content
            VStack(alignment: .leading, spacing: 14) {
                // Top Row: Era Badge + Stopwatch
                HStack(alignment: .center) {
                    HStack(spacing: 5) {
                        Image(systemName: eraIcon)
                            .font(.system(size: 11, weight: .bold))
                        Text(LocalizedStringKey(routine.eraTitle))
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(eraColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(eraColor.opacity(0.14))
                    .clipShape(Capsule())
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "stopwatch")
                            .font(.system(size: 11, weight: .medium))
                        Text(LocalizedStringKey("\(routine.estimatedMinutes) min"))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(PastelTheme.textSecondary)
                }
                
                // Routine Title & Vibe
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(routine.title))
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    
                    Text(LocalizedStringKey(routine.shortVibe))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(eraColor)
                }
                
                // Lore Description
                Text(LocalizedStringKey(routine.loreDescription))
                    .font(.system(size: 13.5, weight: .regular, design: .rounded))
                    .foregroundStyle(PastelTheme.textSecondary)
                    .lineSpacing(4)
                
                // Badges: Difficulty & Benefits
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(eraColor)
                        Text(LocalizedStringKey(routine.difficulty.rawValue))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(PastelTheme.textPrimary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(PastelTheme.cardSurfaceSubtle)
                    .clipShape(Capsule())

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(routine.benefits, id: \.self) { benefit in
                                Text(LocalizedStringKey(benefit))
                                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                    .foregroundStyle(PastelTheme.textSecondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(PastelTheme.cardSurfaceSubtle)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(PastelTheme.cardBorder, lineWidth: 0.8))
                            }
                        }
                    }
                }
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 5)
    }

    // MARK: - Exercise Roster Card
    private var exerciseRosterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(LocalizedStringKey("Protocol Roster"))
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(PastelTheme.textSecondary)
                
                Spacer()
                
                Text("\(routine.exercises.count) exercises")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(eraColor)
            }
            
            VStack(spacing: 0) {
                ForEach(Array(routine.exercises.enumerated()), id: \.element.name) { index, exercise in
                    HStack(spacing: 12) {
                        // Numeric index badge
                        ZStack {
                            Circle()
                                .fill(PastelTheme.cardSurface)
                                .frame(width: 28, height: 28)
                                .overlay(Circle().stroke(eraColor.opacity(0.35), lineWidth: 1))
                            
                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundStyle(eraColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LocalizationHelper.shared.translateName(exercise.name))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(PastelTheme.textPrimary)
                                .lineLimit(1)
                            
                            HStack(spacing: 6) {
                                Text("\(exercise.sets) sets")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(PastelTheme.textSecondary)
                                Text("•")
                                    .font(.system(size: 8))
                                    .foregroundStyle(PastelTheme.textTertiary)
                                Text("\(exercise.reps) reps")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(PastelTheme.textSecondary)
                                if let rest = exercise.restSeconds {
                                    Text("•")
                                        .font(.system(size: 8))
                                        .foregroundStyle(PastelTheme.textTertiary)
                                    Text("\(rest)s rest")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(PastelTheme.textTertiary)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: exercise.type == "Cardio" ? "figure.run" : "dumbbell.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(PastelTheme.textTertiary)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    
                    if index < routine.exercises.count - 1 {
                        Divider()
                            .background(PastelTheme.cardBorder.opacity(0.5))
                            .padding(.leading, 48)
                    }
                }
            }
            .background(PastelTheme.cardSurfaceSubtle)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Actions Section
    private var actionsSection: some View {
        VStack(spacing: 10) {
            // Primary CTA: Start Routine (Tier 1 Height: 50pt)
            Button {
                HapticManager.shared.impact(.medium)
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                    HapticManager.shared.impact(.heavy)
                    HapticManager.shared.notification(.success)
                    onStart()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(LocalizedStringKey("Start Routine"))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(PastelTheme.textOnOat)
                .frame(maxWidth: .infinity)
                .frame(height: PastelTheme.ButtonMetrics.heroHeight)
                .background(PastelTheme.pastelOat)
                .clipShape(RoundedRectangle(cornerRadius: PastelTheme.ButtonMetrics.heroRadius, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())
            
            // Secondary CTA: Save to Library (Tier 2 Height: 42pt)
            Button {
                saveToLibrary()
            } label: {
                HStack(spacing: 6) {
                    Text(LocalizedStringKey(showSavedToast ? "Saved to Library!" : "Save to My Library"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Image(systemName: showSavedToast ? "checkmark.circle.fill" : "bookmark.fill")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(showSavedToast ? PastelTheme.pastelSage : PastelTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: PastelTheme.ButtonMetrics.splitHeight)
                .background(PastelTheme.cardSurfaceSubtle)
                .clipShape(RoundedRectangle(cornerRadius: PastelTheme.ButtonMetrics.splitRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PastelTheme.ButtonMetrics.splitRadius, style: .continuous)
                        .stroke(showSavedToast ? PastelTheme.pastelSage.opacity(0.4) : PastelTheme.cardBorder, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isSaving || showSavedToast)
        }
    }
    
    private func saveToLibrary() {
        guard !isSaving else { return }
        isSaving = true
        HapticManager.shared.impact(.light)
        
        let exerciseDTOs = routine.exercises.map { genDTO in
            ExerciseDTO(
                name: genDTO.name,
                muscleGroup: genDTO.muscleGroup,
                type: ExerciseType(rawValue: genDTO.type) ?? .strength,
                category: ExerciseCategory.determine(from: genDTO.name),
                effort: 50,
                isCompleted: false,
                setsList: (1...max(1, genDTO.sets)).map { i in
                    WorkoutSetDTO(
                        index: i,
                        weight: genDTO.recommendedWeightKg,
                        reps: genDTO.reps,
                        distance: nil,
                        time: nil,
                        isCompleted: false,
                        type: .normal
                    )
                },
                subExercises: nil,
                sets: genDTO.sets,
                reps: genDTO.reps,
                recommendedWeightKg: genDTO.recommendedWeightKg
            )
        }
        
        Task {
            await presetService.savePresetDTO(
                preset: nil,
                name: routine.title,
                icon: "star.fill",
                folderName: PresetService.savedRoutinesFolderName,
                exercises: exerciseDTOs
            )
            
            await MainActor.run {
                showSavedToast = true
                isSaving = false
                HapticManager.shared.notification(.success)
            }
        }
    }
}
