//
//  MuscleColorSettingsView.swift
//  WorkoutTracker
//
//  Модальное окно для настройки цветов групп мышц в круговой диаграмме
//

internal import SwiftUI

struct MuscleColorSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var colorManager = MuscleColorManager.shared
    
    // Все возможные группы мышц
    let muscleGroups = ["Chest", "Back", "Legs", "Arms", "Shoulders", "Core", "Cardio"]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(muscleGroups, id: \.self) { muscleGroup in
                    MuscleColorRow(
                        muscleGroup: muscleGroup,
                        colorManager: colorManager
                    )
                }
                
                Section {
                    Button(role: .destructive) {
                        colorManager.resetAllColors()
                    } label: {
                        HStack {
                            Spacer()
                            Text(LocalizedStringKey("Reset All Colors"))
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("Muscle Group Colors"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct MuscleColorRow: View {
    let muscleGroup: String
    @ObservedObject var colorManager: MuscleColorManager
    
    @State private var selectedColor: Color
    
    init(muscleGroup: String, colorManager: MuscleColorManager) {
        self.muscleGroup = muscleGroup
        self.colorManager = colorManager
        _selectedColor = State(initialValue: colorManager.getColor(for: muscleGroup))
    }
    
    var body: some View {
        HStack {
            // Цветной индикатор
            Circle()
                .fill(selectedColor)
                .frame(width: 30, height: 30)
                .overlay(
                    Circle()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
            
            Text(LocalizedStringKey(muscleGroup))
                .font(.body)
            
            Spacer()
            
            // ColorPicker
            ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                .labelsHidden()
                .onChange(of: selectedColor) { newColor in
                    colorManager.setColor(newColor, for: muscleGroup)
                }
            
            // Кнопка сброса
            Button {
                colorManager.resetColor(for: muscleGroup)
                selectedColor = MuscleColorManager.defaultColors[muscleGroup] ?? .gray
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .foregroundColor(.secondary)
                    .font(.body)
            }
        }
    }
}
