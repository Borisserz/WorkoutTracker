//
//  SmartWorkoutBuilderSheet.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 29.03.26.
//

//
//  SmartWorkoutBuilderSheet.swift
//  WorkoutTracker
//

internal import SwiftUI

struct SmartWorkoutBuilderSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    // Замыкание, которое вернет готовый промпт
    var onGenerate: (String) -> Void
    
    // Доступные мышцы
    private let availableMuscles = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core", "Cardio"]
    
    // Инвентарь
    enum Equipment: String, CaseIterable {
        case fullGym = "Full Gym"
        case dumbbells = "Dumbbells"
        case bodyweight = "Bodyweight"
        
        var localizedName: LocalizedStringKey {
            switch self {
            case .fullGym: return "Full Gym"
            case .dumbbells: return "Dumbbells"
            case .bodyweight: return "Bodyweight"
            }
        }
    }
    
    // State-переменные для параметров
    @State private var selectedMuscles: Set<String> = []
    @State private var selectedEquipment: Equipment = .fullGym
    @State private var duration: Double = 45.0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    
                    // 1. Секция: Целевые мышцы
                    VStack(alignment: .leading, spacing: 12) {
                        Text(LocalizedStringKey("Target Muscles"))
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                            ForEach(availableMuscles, id: \.self) { muscle in
                                Button {
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                    
                                    if selectedMuscles.contains(muscle) {
                                        selectedMuscles.remove(muscle)
                                    } else {
                                        selectedMuscles.insert(muscle)
                                    }
                                } label: {
                                    Text(LocalizedStringKey(muscle))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(selectedMuscles.contains(muscle) ? Color.accentColor : Color(UIColor.secondarySystemBackground))
                                        .foregroundColor(selectedMuscles.contains(muscle) ? .white : .primary)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedMuscles.contains(muscle) ? Color.accentColor : Color.gray.opacity(0.2), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // 2. Секция: Инвентарь
                    VStack(alignment: .leading, spacing: 12) {
                        Text(LocalizedStringKey("Equipment"))
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Picker("Equipment", selection: $selectedEquipment) {
                            ForEach(Equipment.allCases, id: \.self) { eq in
                                Text(eq.localizedName).tag(eq)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // 3. Секция: Время
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(LocalizedStringKey("Duration"))
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(Int(duration)) min")
                                .font(.title3)
                                .bold()
                                .foregroundColor(.accentColor)
                        }
                        
                        Slider(value: $duration, in: 15...120, step: 15)
                            .tint(.accentColor)
                        
                        HStack {
                            Text("15 min").font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Text("120 min").font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle(LocalizedStringKey("Workout Parameters"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Close")) { dismiss() }
                }
            }
            // Закрепленная кнопка генерации снизу
            .safeAreaInset(edge: .bottom) {
                Button {
                    generatePromptAndDismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.headline)
                        Text(LocalizedStringKey("Generate Plan"))
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .background(
                    Color(UIColor.systemBackground)
                        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: -5)
                )
            }
        }
        // Поддержка размеров шторки
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private func generatePromptAndDismiss() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        let musclesStr = selectedMuscles.isEmpty ? "Full Body" : selectedMuscles.joined(separator: ", ")
        
        // Формируем четкий промпт на английском для ИИ
        let prompt = "Create a \(Int(duration))-minute workout focusing on \(musclesStr). Available equipment: \(selectedEquipment.rawValue)."
        
        onGenerate(prompt)
        dismiss()
    }
}
