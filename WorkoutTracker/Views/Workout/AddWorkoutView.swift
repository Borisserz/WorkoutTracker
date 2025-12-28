//
//  AddWorkoutView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 27.12.25.
//

internal import SwiftUI
import ActivityKit

struct AddWorkoutView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: WorkoutViewModel
    @Binding var workouts: [Workout]
    
    // 1. НОВОЕ: Замыкание, которое мы вызовем при успехе
    var onWorkoutCreated: (() -> Void)?
    
    @State private var title = ""
    @State private var selectedPreset: WorkoutPreset?
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Workout Name")) {
                    TextField("E.g. Evening Pump", text: $title)
                }
                
                Section(header: Text("Choose Template"),
                        footer: Text("You can change your prepared workouts in the settings..")) {
                    Button {
                        selectPreset(nil)
                    } label: {
                        HStack {
                            Image(systemName: "plus.square.dashed")
                                .font(.title2).foregroundColor(.gray)
                            VStack(alignment: .leading) {
                                Text("Empty Workout").foregroundColor(.primary)
                                Text("Start from scratch").font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedPreset == nil {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.blue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    ForEach(viewModel.presets) { preset in
                        Button {
                            selectPreset(preset)
                        } label: {
                            HStack {
                                Image(preset.icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 50, height: 50)
                                    .cornerRadius(8)
                                    .shadow(radius: 2)
                                VStack(alignment: .leading) {
                                    Text(preset.name).foregroundColor(.primary)
                                    Text("\(preset.exercises.count) exercises").font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                if selectedPreset?.id == preset.id {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                if let preset = selectedPreset {
                    Section(header: Text("Includes")) {
                        ForEach(preset.exercises) { ex in
                            Text(ex.name).foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Start Workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start Now") {
                        startWorkout()
                    }
                    .disabled(title.isEmpty && selectedPreset == nil)
                }
            }
            .onAppear {
                if title.isEmpty { setFormattedDateName() }
            }
        }
    }
    
    func selectPreset(_ preset: WorkoutPreset?) {
        withAnimation {
            selectedPreset = preset
            if let p = preset {
                title = p.name
            } else {
                setFormattedDateName()
            }
        }
    }
    
    func setFormattedDateName() {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE Workout"
        title = formatter.string(from: Date())
    }
    
    func startWorkout() {
        var exercisesToAdd: [Exercise] = []
        
        if let preset = selectedPreset {
            exercisesToAdd = preset.exercises.map { ex in
                Exercise(
                    id: UUID(),
                    name: ex.name,
                    muscleGroup: ex.muscleGroup,
                    sets: ex.sets,
                    reps: ex.reps,
                    weight: ex.weight,
                    effort: ex.effort
                )
            }
        }
        
        let newWorkout = Workout(
            title: title.isEmpty ? "New Workout" : title,
            date: Date(),
            endTime: nil,
            exercises: exercisesToAdd
        )
        
        // Вставляем в начало списка
        workouts.insert(newWorkout, at: 0)
        
        let attributes = WorkoutActivityAttributes(workoutTitle: title)
        let state = WorkoutActivityAttributes.ContentState(startTime: Date())
        
        do {
            let activity = try Activity<WorkoutActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            print("Live Activity started: \(activity.id)")
        } catch {
            print("Error Live Activity: \(error.localizedDescription)")
        }
        
        // 2. Сначала закрываем окно
        dismiss()
        
        // 3. Вызываем колбэк (говорим родителю: "Переходи!")
        // Делаем небольшую задержку, чтобы sheet успел закрыться
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onWorkoutCreated?()
        }
    }
}
