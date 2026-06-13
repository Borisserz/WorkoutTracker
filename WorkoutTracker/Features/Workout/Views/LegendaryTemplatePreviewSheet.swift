internal import SwiftUI

struct LegendaryTemplatePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager
    @Environment(PresetService.self) private var presetService
    
    let routine: LegendaryRoutine
    let onStart: () -> Void
    
    @State private var isSaving = false
    @State private var showSavedToast = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                (colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color(UIColor.secondarySystemBackground)).ignoresSafeArea()
                
                LinearGradient(colors: routine.gradientColors, startPoint: .top, endPoint: .bottom)
                    .opacity(0.15)
                    .frame(height: 400)
                    .ignoresSafeArea()
                    .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 32) {
                        
                        // Hall of Fame Title
                        VStack(spacing: 8) {
                            Text("Hall of Fame")
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                            
                            Text("Train like the legends of every era.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 16)
                        
                        // The Big Hero Card
                        VStack(spacing: 0) {
                            // Top part with gradient
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    HStack(spacing: 6) {
                                        Image(systemName: "star.fill").foregroundColor(.orange)
                                        Text(LocalizedStringKey(routine.eraTitle))
                                            .font(.system(size: 14, weight: .bold))
                                            .tracking(1.5)
                                            .foregroundColor(.orange)
                                    }
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: "stopwatch")
                                        Text(LocalizedStringKey("\(routine.estimatedMinutes) min"))
                                            .font(.system(size: 14, weight: .bold))
                                    }
                                    .foregroundColor(.white.opacity(0.8))
                                }
                                
                                Spacer().frame(height: 16)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(LocalizedStringKey(routine.title))
                                        .font(.system(size: 36, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    
                                    Text(LocalizedStringKey(routine.shortVibe))
                                        .font(.system(size: 16))
                                        .italic()
                                        .foregroundColor(.orange)
                                }
                            }
                            .padding(24)
                            .background(
                                LinearGradient(colors: routine.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            
                            // Bottom part with details
                            VStack(alignment: .leading, spacing: 20) {
                                Text(LocalizedStringKey(routine.loreDescription))
                                    .font(.system(size: 16, design: .rounded))
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineSpacing(5)
                                
                                HStack(spacing: 24) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "stopwatch.fill").foregroundColor(.gray)
                                        Text(LocalizedStringKey("~\(routine.estimatedMinutes) min")).fontWeight(.bold)
                                    }
                                    HStack(spacing: 6) {
                                        Image(systemName: "flame.fill").foregroundColor(.red)
                                        Text(LocalizedStringKey(routine.difficulty.rawValue)).fontWeight(.bold)
                                    }
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(routine.benefits, id: \.self) { benefit in
                                            Text(LocalizedStringKey(benefit))
                                                .font(.system(size: 12, weight: .bold))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(Color.black)
                                                .foregroundColor(.white)
                                                .overlay(Capsule().stroke(Color.orange, lineWidth: 1))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(LocalizedStringKey("Protocol Overview"))
                                        .font(.system(size: 13, weight: .black, design: .rounded))
                                        .tracking(1.5)
                                        .foregroundColor(.white.opacity(0.5))
                                        .textCase(.uppercase)
                                    
                                    VStack(spacing: 0) {
                                        ForEach(Array(routine.exercises.enumerated()), id: \.element.name) { index, exercise in
                                            HStack(spacing: 16) {
                                                ZStack {
                                                    Circle()
                                                        .stroke(LinearGradient(colors: routine.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                                                        .frame(width: 32, height: 32)
                                                    
                                                    Text("\(index + 1)")
                                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                                        .foregroundStyle(LinearGradient(colors: routine.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                                }
                                                
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(LocalizationHelper.shared.translateName(exercise.name))
                                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                                        .foregroundColor(.white)
                                                        .lineLimit(2)
                                                    
                                                    HStack(spacing: 8) {
                                                        HStack(spacing: 4) {
                                                            Text("\(exercise.sets)").foregroundColor(.white)
                                                            Text("sets")
                                                        }
                                                        Text("•").foregroundColor(.white.opacity(0.3))
                                                        HStack(spacing: 4) {
                                                            Text("\(exercise.reps)").foregroundColor(.white)
                                                            Text("reps")
                                                        }
                                                    }
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundColor(.gray)
                                                }
                                                Spacer()
                                                
                                                Image(systemName: exercise.type == "Cardio" ? "figure.run" : "dumbbell.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.white.opacity(0.2))
                                            }
                                            .padding(.vertical, 14)
                                            
                                            if index < routine.exercises.count - 1 {
                                                Divider()
                                                    .background(Color.white.opacity(0.1))
                                                    .padding(.leading, 48)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .background(Color.black.opacity(0.4))
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                                    )
                                }
                                .padding(.top, 8)
                                .padding(.bottom, 8)
                                
                                Button {
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.success)
                                    dismiss()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        onStart()
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Text(LocalizedStringKey("Start Routine"))
                                        Image(systemName: "bolt.fill")
                                    }
                                    .font(.title3.bold())
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        LinearGradient(colors: routine.gradientColors, startPoint: .leading, endPoint: .trailing)
                                    )
                                    .cornerRadius(16)
                                }
                                
                                Button {
                                    saveToLibrary()
                                } label: {
                                    HStack(spacing: 8) {
                                        Text(LocalizedStringKey(showSavedToast ? "Saved to Library!" : "Save to My Library"))
                                        Image(systemName: showSavedToast ? "checkmark.circle.fill" : "bookmark.fill")
                                    }
                                    .font(.headline)
                                    .foregroundColor(showSavedToast ? .green : .white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.white.opacity(showSavedToast ? 0.05 : 0.1))
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(showSavedToast ? Color.green.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                }
                                .disabled(isSaving || showSavedToast)
                            }
                            .padding(24)
                            .background(Color(red: 0.12, green: 0.12, blue: 0.12))
                        }
                        .cornerRadius(24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(LinearGradient(colors: routine.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                        )
                        .shadow(color: routine.gradientColors[0].opacity(0.4), radius: 20, x: 0, y: 10)
                        .padding(.horizontal, 20)
                        
                        Spacer().frame(height: 20)
                        
                        Spacer().frame(height: 40)
                    }
                }
                
                // Floating back button
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
        .presentationDragIndicator(.visible)
    }
    
    private func saveToLibrary() {
        guard !isSaving else { return }
        isSaving = true
        
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
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
    }
}
