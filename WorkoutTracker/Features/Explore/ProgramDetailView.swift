// ============================================================
// FILE: WorkoutTracker/Features/Explore/ProgramDetailView.swift
// ============================================================

internal import SwiftUI

struct ProgramDetailView: View {
    let program: WorkoutProgramDefinition
    
    @Environment(PresetService.self) private var presetService
    @Environment(\.dismiss) private var dismiss
    
    @State private var isSaving = false
    @State private var isSaved = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    
                    // Parallax Header
                    GeometryReader { geo in
                        let minY = geo.frame(in: .global).minY
                        let isScrolled = minY > 0
                        let height = isScrolled ? 300 + minY : 300
                        let offset = isScrolled ? -minY : 0
                        
                        LinearGradient(colors: program.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                            .frame(width: geo.size.width, height: height)
                            .offset(y: offset)
                    }
                    .frame(height: 300)
                    
                    // Content Body
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // Title & Tags
                        VStack(alignment: .leading, spacing: 12) {
                            Text(program.title)
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 8) {
                                ProgramTag(text: program.level.rawValue, icon: "chart.bar.fill", color: .blue)
                                ProgramTag(text: program.goal.rawValue, icon: "target", color: .purple)
                                ProgramTag(text: program.equipment.rawValue, icon: program.equipment.icon, color: .orange)
                            }
                            
                            Text(program.description)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .lineSpacing(4)
                                .padding(.top, 4)
                        }
                        .padding(.top, 24)
                        
                        Divider()
                        
                        // Deep Routine Preview
                        VStack(alignment: .leading, spacing: 16) {
                            Text(program.isSingleRoutine ? "Exercises" : "Included Routines")
                                .font(.title3)
                                .fontWeight(.bold)
                            
                            if program.isSingleRoutine, let routine = program.routines.first {
                                RoutinePreviewCard(routine: routine, hideHeader: true)
                            } else {
                                ForEach(Array(program.routines.enumerated()), id: \.offset) { index, routine in
                                    RoutinePreviewCard(routine: routine, hideHeader: false, dayIndex: index + 1)
                                }
                            }
                        }
                        
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120) // Space for floating button
                }
            }
            .ignoresSafeArea(edges: .top)
            
            // Floating Morphing Save Button
            MorphingSaveButton(
                isSaving: isSaving,
                isSaved: isSaved,
                defaultTitle: program.isSingleRoutine ? "Save Routine" : "Save Program",
                gradientColors: program.gradientColors,
                action: saveProgramToLibrary
            )
            .padding(.bottom, 10)
            .padding(.horizontal, 20)
            .background(
                LinearGradient(colors: [Color(UIColor.systemGroupedBackground), Color(UIColor.systemGroupedBackground).opacity(0)], startPoint: .bottom, endPoint: .top)
                    .ignoresSafeArea()
            )
        }
        .task {
            // ✅ При открытии экрана проверяем, сохранена ли уже эта программа
            isSaved = await presetService.isProgramSaved(title: program.title, isSingleRoutine: program.isSingleRoutine)
        }
    }
    
    // MARK: - Save Logic (Strict Concurrency)
    private func saveProgramToLibrary() {
        guard !isSaving && !isSaved else { return }
        isSaving = true
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        Task { @MainActor in
            // Определяем папку: либо общая папка для синглов, либо папка с именем программы
            let targetFolder = program.isSingleRoutine ? PresetService.savedRoutinesFolderName : program.title
            
            for routine in program.routines {
                let mappedExercises = routine.exercises.map { Exercise(from: $0) }
                
                // Для синглов имя пресета должно совпадать с именем программы (для правильной проверки на дубликаты)
                let finalName = program.isSingleRoutine ? program.title : routine.name
                
                await presetService.savePreset(
                    preset: nil,
                    name: finalName,
                    icon: routine.icon,
                    folderName: targetFolder,
                    exercises: mappedExercises
                )
            }
            
            // Запускаем анимацию успеха
            isSaving = false
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isSaved = true
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

// MARK: - Morphing Save Button
struct MorphingSaveButton: View {
    var isSaving: Bool
    var isSaved: Bool
    var defaultTitle: String
    var gradientColors: [Color]
    var action: () -> Void
    
    @State private var popScale: CGFloat = 1.0
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isSaving {
                    ProgressView().tint(.white)
                } else if isSaved {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .contentTransition(.symbolEffect(.replace)) // iOS 17 fluid icon morphing
                    
                    Text("Saved")
                        .font(.headline)
                        .fontWeight(.bold)
                } else {
                    Image(systemName: "square.and.arrow.down.fill")
                        .font(.title3)
                    
                    Text(defaultTitle)
                        .font(.headline)
                        .fontWeight(.bold)
                }
            }
            .foregroundColor(.white)
            // Morph the width down to a pill shape when saved
            .frame(maxWidth: isSaved ? 140 : .infinity)
            .padding(.vertical, 18)
            .background(
                Group {
                    if isSaved {
                        // Премиальный серый цвет для состояния "Уже сохранено"
                        Color(UIColor.tertiaryLabel)
                    } else {
                        LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing)
                    }
                }
            )
            .clipShape(Capsule())
            .shadow(color: isSaved ? .clear : gradientColors.first!.opacity(0.4), radius: 15, x: 0, y: 8)
            .scaleEffect(popScale)
        }
        .disabled(isSaving || isSaved)
        .onChange(of: isSaved) { _, saved in
            if saved {
                // Micro-animation "Pop" effect
                withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
                    popScale = 1.08
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        popScale = 1.0
                    }
                }
            }
        }
    }
}

// MARK: - Deep Routine Preview Card
struct RoutinePreviewCard: View {
    let routine: WorkoutPresetDTO
    let hideHeader: Bool
    var dayIndex: Int? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Header (Only show for Multi-Day Programs)
            if !hideHeader {
                HStack(spacing: 12) {
                    if UIImage(named: routine.icon) != nil {
                        Image(routine.icon).resizable().scaledToFit().frame(width: 24, height: 24)
                    } else {
                        Image(systemName: routine.icon).foregroundColor(.blue).font(.title3)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if let day = dayIndex {
                            Text("Day \(day)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .fontWeight(.bold)
                        }
                        Text(routine.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.primary.opacity(0.05))
            }
            
            // Exercises List
            VStack(spacing: 0) {
                ForEach(Array(routine.exercises.enumerated()), id: \.offset) { index, ex in
                    HStack {
                        Image(systemName: ex.type == .cardio ? "figure.run" : "dumbbell.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        
                        Text(ex.name)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                                                
                                                // ✅ ИСПРАВЛЕНИЕ: Выносим логику из Text, чтобы не сводить компилятор с ума
                                                let safeSets = ex.setsList ?? []
                                                let repsCount = safeSets.first?.reps ?? 10
                                                
                                                Text("\(safeSets.count) x \(repsCount) reps")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                    
                    // Divider except for the last item
                    if index != routine.exercises.count - 1 {
                        Divider().padding(.leading, 48)
                    }
                }
            }
            .padding(.vertical, hideHeader ? 8 : 0)
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}
