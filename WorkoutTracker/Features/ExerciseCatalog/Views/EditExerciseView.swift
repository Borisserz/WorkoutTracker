// FILE: WorkoutTracker/Features/ExerciseCatalog/Views/EditExerciseView.swift
internal import SwiftUI
import SwiftData

struct EditExerciseView: View {
    
    // MARK: - Environment & Bindings
    @Environment(\.dismiss) var dismiss
    @Environment(ThemeManager.self) private var themeManager // <--- ДОБАВЛЕНО: Инъекция темы
    
    @Bindable var exercise: Exercise
    
    var body: some View {
        Form {
            configSection
            effortSection
            saveButton
        }
        .navigationTitle("Edit Exercise")
    }
    
    // MARK: - View Components
    private var configSection: some View {
        Section(header: Text(LocalizedStringKey("Configuration"))) {
            HStack {
                Text(LocalizedStringKey("Exercise"))
                Spacer()
                Text(LocalizationHelper.shared.translateName(exercise.name)).bold()
            }
        }
    }
       
    private var effortSection: some View {
        Section(header: Text(LocalizedStringKey("Effort (RPE)"))) {
            HStack {
                Text("\(exercise.effort)/10")
                    .bold()
                    .foregroundColor(effortColor(exercise.effort))
                
                Slider(value: Binding(get: { Double(exercise.effort) }, set: { exercise.effort = Int($0) }), in: 1...10, step: 1)
                    .tint(effortColor(exercise.effort))
            }
            Text(LocalizedStringKey("1 = Easy, 10 = Failure"))
                .font(.caption)
                .foregroundColor(themeManager.current.secondaryText)
        }
    }
       
    private var saveButton: some View {
        Button(LocalizedStringKey("Save Changes")) {
            dismiss()
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.borderedProminent)
        .tint(themeManager.current.primaryAccent) // <--- ИЗМЕНЕНО: Кнопка сохранения тоже будет в цвете темы
    }
    
    // MARK: - Logic / Helpers
    
    private func effortColor(_ value: Int) -> Color {
        // RPE (Усилие) остается семантической тепловой шкалой:
        switch value {
        case 1...4: return .green
        case 5...7: return .orange
        case 8...10: return .red
        default: return themeManager.current.primaryAccent // <--- ИЗМЕНЕНО: Фолбэк на цвет темы
        }
    }
}
