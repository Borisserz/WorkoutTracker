// ============================================================
// FILE: WorkoutTracker/Features/SmartBuilder/GeneratedWorkoutResultView.swift
// ============================================================

internal import SwiftUI

struct GeneratedWorkoutResultView: View {
    @Bindable var vm: SmartGeneratorViewModel
    @Environment(UnitsManager.self) var unitsManager
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var colorManager = MuscleColorManager.shared
    
    // Передаем правильный DTO!
    var onStart: ([ExerciseDTO]) -> Void
    
    private var muscleDistribution: [(String, Double)] {
        var totalSets: Int = 0
        for ex in vm.generatedExercises {
            totalSets += (ex.setsList ?? []).count
        }
        guard totalSets > 0 else { return [] }
        let totalSetsDouble = Double(totalSets)
        
        var counts: [String: Int] = [:]
        for ex in vm.generatedExercises {
            let setsCount = (ex.setsList ?? []).count
            counts[ex.muscleGroup, default: 0] += setsCount
        }
        
        var result: [(String, Double)] = []
        for (muscle, count) in counts {
            let percentage = (Double(count) / totalSetsDouble) * 100.0
            result.append((muscle, percentage))
        }
        result.sort { $0.1 > $1.1 }
        return result
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            backgroundLayer
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection
                    muscleFocusSection
                    exerciseListSection
                }
                .padding(.bottom, 120)
            }
            
            floatingStartButton
        }
        .navigationTitle("Your Program")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - View Components
    
    private var backgroundLayer: some View {
        Group {
            if colorScheme == .dark {
                themeManager.current.background
            } else {
                Color(UIColor.systemGroupedBackground)
            }
        }
        .ignoresSafeArea()
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 50))
                .foregroundStyle(themeManager.current.primaryGradient)
                .shadow(color: themeManager.current.deepPremiumAccent.opacity(0.4), radius: 10, y: 5)
            
            Text("Routine Ready")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundColor(colorScheme == .dark ? .white : .black)
        }
        .padding(.top, 20)
    }
    
    private var muscleFocusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Muscle Focus")
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
            
            VStack(spacing: 16) {
                ForEach(muscleDistribution, id: \.0) { item in
                    muscleRow(name: item.0, percentage: item.1)
                }
            }
        }
        .padding(20)
        .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.05 : 0.08), radius: 10, y: 5)
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private func muscleRow(name: String, percentage: Double) -> some View {
        let muscleColor = colorManager.getColor(for: MuscleCategoryMapper.getBroadCategory(for: name))
        let widthFactor = CGFloat(percentage / 100.0)
        
        HStack(spacing: 12) {
            Text(LocalizedStringKey(name))
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .frame(width: 80, alignment: .leading)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                    Capsule()
                        .fill(muscleColor)
                        .frame(width: max(0, geo.size.width * widthFactor))
                        .shadow(color: muscleColor.opacity(0.5), radius: 5, x: 0, y: 0)
                }
            }
            .frame(height: 10)
            
            Text("\(Int(percentage))%")
                .font(.caption).bold()
                .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                .frame(width: 40, alignment: .trailing)
        }
    }
    
    private var exerciseListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Exercises")
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                ForEach(Array(vm.generatedExercises.enumerated()), id: \.element.name) { index, ex in
                    exerciseCard(index: index, ex: ex)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // ✅ ИСПРАВЛЕНИЕ ТИПА: Заменено с GeneratedExerciseDTO на ExerciseDTO
    @ViewBuilder
    private func exerciseCard(index: Int, ex: ExerciseDTO) -> some View {
        let muscleColor = colorManager.getColor(for: MuscleCategoryMapper.getBroadCategory(for: ex.muscleGroup))
        let safeSets = ex.setsList ?? []
        let reps = safeSets.first?.reps ?? 10
        let weight = safeSets.first?.weight ?? 0.0
        
        HStack(spacing: 16) {
            // Номер
            ZStack {
                Circle()
                    .fill(muscleColor.opacity(0.15))
                    .frame(width: 46, height: 46)
                Text("\(index + 1)")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(muscleColor)
            }
            
            // Название и группа
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizationHelper.shared.translateName(ex.name))
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .lineLimit(2)
                
                Text(LocalizedStringKey(ex.muscleGroup))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(muscleColor)
            }
            
            Spacer()
            
            // Сеты и повторения
            VStack(alignment: .trailing, spacing: 4) {
                if ex.type == .strength {
                    Text("\(safeSets.count) × \(reps)")
                        .font(.subheadline).bold()
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    
                    if weight > 0 {
                        let conv = unitsManager.convertFromKilograms(weight)
                        Text("\(Int(conv)) \(unitsManager.weightUnitString())")
                            .font(.caption).bold()
                            .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                    } else {
                        Text("Bodyweight")
                            .font(.caption)
                            .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                    }
                } else {
                    let timeSec = safeSets.first?.time ?? 0
                    Text("\(timeSec / 60) мин")
                        .font(.subheadline).bold()
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }
            }
        }
        .padding(16)
        .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 5, y: 2)
    }
    
    private var floatingStartButton: some View {
        VStack {
            Spacer()
            Button {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onStart(vm.generatedExercises)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.fill").font(.title2)
                    Text("START WORKOUT").font(.title3).bold().tracking(1.0)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(themeManager.current.primaryGradient)
                .clipShape(Capsule())
                .shadow(color: themeManager.current.deepPremiumAccent.opacity(0.5), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 24)
            }
        }
        .padding(.bottom, 16)
        .background(
            LinearGradient(
                colors: [(colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground)), .clear],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: 100)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea()
            .allowsHitTesting(false)
        )
    }
}
