//
//  AIQuerySheets.swift
//  WorkoutTracker
//

internal import SwiftUI

// MARK: - Шторка: Мой Progress
struct ProgressAnalysisSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onGenerate: (String) -> Void
    @Environment(ThemeManager.self) private var themeManager // <--- ДОБАВЛЕНО
    @State private var selectedPeriod = "Past Week"
    @State private var selectedFocus = "General Overview"
    
    let periods = ["Past Week", "Past Month", "All Time"]
    let focuses = ["General Overview", "Personal Records", "Consistency and Discipline"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Analysis Parameters")) {
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(periods, id: \.self) { Text($0) }
                    }
                    Picker("Main Focus", selection: $selectedFocus) {
                        ForEach(focuses, id: \.self) { Text($0) }
                    }
                }
            }
            .navigationTitle("Progress Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {let isRussian = Locale.current.language.languageCode?.identifier == "ru"
                    let langRule = isRussian ? "ОТВЕЧАЙ НА РУССКОМ." : "REPLY IN ENGLISH."
                    let prompt = isRussian
                        ? "Проанализируй мой прогресс. Период: \(selectedPeriod). Сделай акцент на: \(selectedFocus). НЕ создавай план тренировки, только текстовый анализ. \(langRule)"
                        : "Analyze my progress. Period: \(selectedPeriod). Focus on: \(selectedFocus). Do NOT create a workout plan, text analysis only. \(langRule)"
                    onGenerate(prompt)
                    
                } label: {
                    Text("Ask Coach")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeManager.current.primaryAccent)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
                .padding()
                .background(themeManager.current.background.shadow(radius: 5, y: -2))
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Шторка: Восстановление
struct RecoveryAdvisorSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onGenerate: (String) -> Void
    @Environment(ThemeManager.self) private var themeManager // <--- ДОБАВЛЕНО
    @State private var feeling = "Light soreness"
    @State private var goal = "Everything hurtsWhat can I train?"
    
    let feelings = ["Full of energy", "Light soreness", "Everything hurts"]
    let goals = ["Everything hurtsWhat can I train?", "Active recovery (cardio/stretch)", "Do I need full rest?"]
    
    var body: some View {
        NavigationStack {
            Form {
                // Выбор самочувствия В СТОЛБИК мелким шрифтом
                Section(header: Text("How do you feel")) {
                    ForEach(feelings, id: \.self) { f in
                        Button {
                            feeling = f
                        } label: {
                            HStack {
                                Text(f)
                                    .font(.subheadline)
                                    .foregroundColor(themeManager.current.primaryText)
                                Spacer()
                                if feeling == f {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(themeManager.current.primaryAccent)
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("What's the plan?")) {
                    ForEach(goals, id: \.self) { g in
                        Button {
                            goal = g
                        } label: {
                            HStack {
                                Text(g)
                                    .font(.subheadline)
                                    .foregroundColor(themeManager.current.primaryText)
                                Spacer()
                                if goal == g {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(themeManager.current.primaryAccent)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Recovery Assessment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    let isRussian = Locale.current.language.languageCode?.identifier == "ru"
                    let langRule = isRussian ? "ОТВЕЧАЙ НА РУССКОМ." : "REPLY IN ENGLISH."
                    let prompt = isRussian
                        ? "Оцени мое восстановление. Самочувствие: \(feeling). Цель: \(goal). Дай короткий совет. НЕ создавай план тренировки (если я не просил). \(langRule)"
                        : "Assess my recovery. I feel: \(feeling). My goal: \(goal). Give brief advice. Do NOT create a workout plan unless requested. \(langRule)"
                    onGenerate(prompt)
                } label: {
                    Text("Get Status")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeManager.current.primaryAccent) 
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
                .padding()
                .background(themeManager.current.background.shadow(radius: 5, y: -2))
            }
        }
        .presentationDetents([.medium, .large])
    }
}
