// ============================================================
// FILE: WorkoutTracker/Features/Explore/ProgramDetailView.swift
// ============================================================

internal import SwiftUI

struct ProgramDetailView: View {
    let program: WorkoutProgramDefinition
    @Environment(ThemeManager.self) private var themeManager
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
                            Text(LocalizedStringKey(program.title))
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .foregroundColor(themeManager.current.primaryText)
                            
                            HStack(spacing: 8) {
                                ProgramTag(text: program.level.rawValue, icon: "chart.bar.fill", color: themeManager.current.primaryAccent)
                                                               ProgramTag(text: program.goal.rawValue, icon: "target", color: themeManager.current.deepPremiumAccent)
                                                               ProgramTag(text: program.equipment.rawValue, icon: program.equipment.icon, color: themeManager.current.secondaryMidTone)
                                                           }
                            
                            Text(LocalizedStringKey(program.description))
                                .font(.body)
                                .foregroundColor(themeManager.current.secondaryText)
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
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme // 👈 ДОБАВЛЕНО
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
                        .contentTransition(.symbolEffect(.replace))
                    
                    Text("Сохранено")
                        .font(.headline)
                        .fontWeight(.bold)
                } else {
                    Image(systemName: "bolt.fill")
                        .font(.title3)
                    
                    Text(defaultTitle)
                        .font(.headline)
                        .fontWeight(.bold)
                }
            }
            .foregroundColor(.white) // 👈 ИСПРАВЛЕНИЕ: Текст всегда белый
            .frame(maxWidth: isSaved ? 140 : .infinity)
            .padding(.vertical, 18)
            .background(
                Group {
                    if isSaved {
                        Color.green
                    } else {
                        // 👈 ИСПРАВЛЕНИЕ: В светлой теме кнопка всегда синяя, в темной - градиент программы
                        if colorScheme == .dark {
                            LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing)
                        } else {
                            LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                        }
                    }
                }
            )
            .clipShape(Capsule())
            .shadow(color: isSaved ? .clear : (colorScheme == .dark ? gradientColors.first!.opacity(0.4) : .blue.opacity(0.4)), radius: 15, x: 0, y: 8)
            .scaleEffect(popScale)
        }
        .disabled(isSaving || isSaved)
        .onChange(of: isSaved) { _, saved in
            if saved {
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
struct RoutinePreviewCard: View {
    let routine: WorkoutPresetDTO
    let hideHeader: Bool
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme // 👈 ДОБАВЛЕНО
    var dayIndex: Int? = nil
    @State private var selectedHistoryExercise: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Header (Only show for Multi-Day Programs)
            if !hideHeader {
                HStack(spacing: 12) {
                    if UIImage(named: routine.icon) != nil {
                        Image(routine.icon).resizable().scaledToFit().frame(width: 24, height: 24)
                    } else {
                        Image(systemName: routine.icon) .foregroundColor(themeManager.current.primaryAccent)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if let day = dayIndex {
                            Text("День \(day)")
                                .font(.caption)
                                .foregroundColor(.blue) // 👈 АДАПТИВНО
                                .textCase(.uppercase)
                                .fontWeight(.bold)
                        }
                        Text(LocalizedStringKey(routine.name))
                            .font(.headline)
                            .foregroundColor(colorScheme == .dark ? .white : .black) // 👈
                    }
                    Spacer()
                }
                .padding()
                .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03)) // 👈
            }
            
            // Exercises List
            VStack(spacing: 0) {
                ForEach(Array(routine.exercises.enumerated()), id: \.offset) { index, ex in
                    Button {
                        selectedHistoryExercise = ex.name
                    } label: {
                        HStack {
                            Image(systemName: ex.type == .cardio ? "figure.run" : "dumbbell.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            
                            Text(LocalizationHelper.shared.translateName(ex.name))
                                .font(.subheadline)
                                .foregroundColor(colorScheme == .dark ? .white : .black) // 👈
                            
                            Spacer()
                            
                            let safeSets = ex.setsList ?? []
                            let repsCount = safeSets.first?.reps ?? 10
                            
                            Text("\(safeSets.count) x \(repsCount) повторений")
                                .font(.subheadline)
                                .foregroundColor(colorScheme == .dark ? .gray : .gray) // 👈
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    // Divider except for the last item
                    if index != routine.exercises.count - 1 {
                        Divider().padding(.leading, 48)
                    }
                }
                .padding(.vertical, hideHeader ? 8 : 0)
            }
            // 👈 АДАПТАЦИЯ ФОНА
            .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(colorScheme == .dark ? Color.clear : Color.black.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.03 : 0.05), radius: 5, x: 0, y: 2)
        }
    }
}
