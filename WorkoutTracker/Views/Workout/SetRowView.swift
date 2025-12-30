internal import SwiftUI

struct SetRowView: View {
    @Binding var set: WorkoutSet
    let exerciseType: ExerciseType
    let isLastSet: Bool
    
    // Callback сообщает, нужно ли запускать таймер
    var onCheck: (_ shouldStartTimer: Bool) -> Void
    
    // --- ОБЕРТКА ДЛЯ БИНДИНГА ---
    // Превращает Binding<Double?> в Binding<Double>, где nil становится 0
    func binding(for optionalValue: Binding<Double?>) -> Binding<Double> {
        return Binding<Double>(
            get: { optionalValue.wrappedValue ?? 0 },
            set: { optionalValue.wrappedValue = $0 == 0 ? nil : $0 } // Если ввели 0, сохраняем как nil
        )
    }
    
    // Такая же обертка для Int?
    func binding(for optionalValue: Binding<Int?>) -> Binding<Int> {
        return Binding<Int>(
            get: { optionalValue.wrappedValue ?? 0 },
            set: { optionalValue.wrappedValue = $0 == 0 ? nil : $0 }
        )
    }

    var body: some View {
        HStack(spacing: 8) {
            // 1. НОМЕР СЕТА
            Text("\(set.index)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            // 2. ПОЛЯ ВВОДА (В зависимости от типа)
            switch exerciseType {
            case .strength:
                // ВЕС
                inputField(value: binding(for: $set.weight), placeholder: "kg", width: 60)
                // ПОВТОРЫ
                inputField(value: Binding(get: { Double(binding(for: $set.reps).wrappedValue) }, set: { set.reps = Int($0) }), placeholder: "reps", width: 50)
                
            case .cardio:
                // ДИСТАНЦИЯ
                inputField(value: binding(for: $set.distance), placeholder: "km", width: 60)
                // ВРЕМЯ
                inputField(value: Binding(get: { Double(binding(for: $set.time).wrappedValue) }, set: { set.time = Int($0) }), placeholder: "min", width: 50)
                
            case .duration:
                // ВРЕМЯ (Статика)
                inputField(value: Binding(get: { Double(binding(for: $set.time).wrappedValue) }, set: { set.time = Int($0) }), placeholder: "sec", width: 80)
            }
            
            Spacer()
            
            // 3. КНОПКА ТИПА СЕТА (N <-> W)
            Button {
                set.type = (set.type == .normal) ? .warmup : .normal
            } label: {
                Text(set.type.rawValue)
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 24, height: 24)
                    .background(set.type.color.opacity(0.8))
                    .foregroundColor(set.type == .warmup ? .black : .white)
                    .clipShape(Circle())
            }
            .buttonStyle(BorderlessButtonStyle())
            
            // 4. ГАЛОЧКА (CHECKBOX)
            Button(action: toggleComplete) {
                Image(systemName: set.isCompleted ? "checkmark.square.fill" : "square")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundColor(set.isCompleted ? .green : .gray.opacity(0.5))
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(.vertical, 6)
        .background(set.isCompleted ? Color.green.opacity(0.05) : Color.clear)
        .cornerRadius(6)
        // Блокируем редактирование, если сет выполнен
        .disabled(set.isCompleted)
    }
    
    // Универсальное поле ввода теперь принимает Binding<Double>
    func inputField(value: Binding<Double>, placeholder: String, width: CGFloat) -> some View {
        TextField(placeholder, value: value, format: .number)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)
            .frame(width: width)
            .opacity(set.isCompleted ? 0.6 : 1.0)
    }
    
    // Логика нажатия на галочку
    func toggleComplete() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            set.isCompleted.toggle()
        }
        
        if set.isCompleted {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            // Запускаем таймер, только если это НЕ последний сет
            onCheck(!isLastSet)
        }
    }
}
