//
//  AIQuerySheets.swift
//  WorkoutTracker
//

internal import SwiftUI

// MARK: - Шторка: Мой прогресс
struct ProgressAnalysisSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onGenerate: (String) -> Void
    
    @State private var selectedPeriod = "За неделю"
    @State private var selectedFocus = "Общий обзор"
    
    let periods = ["За неделю", "За месяц", "За всё время"]
    let focuses = ["Общий обзор", "Личные рекорды", "Регулярность и дисциплина"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Параметры анализа")) {
                    Picker("Период", selection: $selectedPeriod) {
                        ForEach(periods, id: \.self) { Text($0) }
                    }
                    Picker("Главный фокус", selection: $selectedFocus) {
                        ForEach(focuses, id: \.self) { Text($0) }
                    }
                }
            }
            .navigationTitle("Анализ прогресса")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    let prompt = "Проанализируй мой прогресс. Период: \(selectedPeriod). Сделай акцент на: \(selectedFocus). НЕ создавай план тренировки, только текстовый анализ."
                    onGenerate(prompt)
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    dismiss()
                } label: {
                    Text("Спросить тренера")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
                .padding()
                .background(Color(UIColor.systemBackground).shadow(radius: 5, y: -2))
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Шторка: Восстановление
struct RecoveryAdvisorSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onGenerate: (String) -> Void
    
    @State private var feeling = "Легкая крепатура"
    @State private var goal = "Что можно потренировать?"
    
    let feelings = ["Полон сил", "Легкая крепатура", "Всё болит"]
    let goals = ["Что можно потренировать?", "Активное восстановление (кардио/растяжка)", "Нужен ли полный отдых?"]
    
    var body: some View {
        NavigationStack {
            Form {
                // Выбор самочувствия В СТОЛБИК мелким шрифтом
                Section(header: Text("Твое самочувствие")) {
                    ForEach(feelings, id: \.self) { f in
                        Button {
                            feeling = f
                        } label: {
                            HStack {
                                Text(f)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Spacer()
                                if feeling == f {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Что планируем делать?")) {
                    ForEach(goals, id: \.self) { g in
                        Button {
                            goal = g
                        } label: {
                            HStack {
                                Text(g)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Spacer()
                                if goal == g {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Оценка восстановления")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    let prompt = "Оцени мое восстановление с учетом уставших мышц (в твоем контексте). Мое самочувствие: \(feeling). Мой вопрос/цель: \(goal). Дай короткий и четкий совет. НЕ создавай план тренировки, если я явно не выбрал 'Что можно потренировать?'."
                    onGenerate(prompt)
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    dismiss()
                } label: {
                    Text("Узнать статус")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue) // Сделали синим
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
                .padding()
                .background(Color(UIColor.systemBackground).shadow(radius: 5, y: -2))
            }
        }
        .presentationDetents([.medium, .large])
    }
}
