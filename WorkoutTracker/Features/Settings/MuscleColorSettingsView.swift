internal import SwiftUI
import SwiftData

struct MuscleColorSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var colorManager = MuscleColorManager.shared
    
    // ИСПРАВЛЕНИЕ: Оставляем только основные группы мышц (как они записаны в Workoutх)
    let muscles = [
        "Chest", "Back", "Legs", "Shoulders", "Arms", "Core"
    ]
    
    // Дефолтные пресеты цветов для быстрого выбора
    let colorPresets: [Color] = [
        .red, .orange, .yellow, .green, .blue, .purple, .pink, .teal, .indigo, .brown
    ]
    
    @State private var selectedMuscle: String? = nil
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text(LocalizedStringKey("Chart Colors")),
                        footer: Text(LocalizedStringKey("Customize the colors used to represent different muscle groups in your dashboard."))) {
                    
                    ForEach(muscles, id: \.self) { muscle in
                        HStack {
                            Text(LocalizedStringKey(muscle))
                            Spacer()
                            
                            // Текущий цвет
                            Circle()
                                .fill(colorManager.getColor(for: muscle))
                                .frame(width: 30, height: 30)
                                .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                                .onTapGesture {
                                    selectedMuscle = muscle
                                }
                        }
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("Customize Colors"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Done")) {
                        dismiss()
                    }
                }
            }
            // Шторка с выбором цвета
            .sheet(item: Binding(
                get: { selectedMuscle.map { IdentifiableString(id: $0) } },
                set: { selectedMuscle = $0?.id }
            )) { muscleItem in
                NavigationStack {
                    VStack(spacing: 30) {
                        Text(LocalizedStringKey("Choose Color for \(muscleItem.id)"))
                            .font(.headline)
                            .padding(.top)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 20) {
                            ForEach(colorPresets, id: \.self) { color in
                                Circle()
                                    .fill(color)
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Circle().stroke(Color.primary, lineWidth: colorManager.getColor(for: muscleItem.id) == color ? 3 : 0)
                                    )
                                    .onTapGesture {
                                        colorManager.save(muscle: muscleItem.id, hex: color.toHex() ?? "0000FF", context: modelContext)
                                        selectedMuscle = nil
                                    }
                            }
                        }
                        .padding()
                        
                        Spacer()
                    }
                    .navigationTitle(LocalizedStringKey("Select Color"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(LocalizedStringKey("Cancel")) {
                                selectedMuscle = nil
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }
}

// Утилита для работы с Sheet
struct IdentifiableString: Identifiable {
    let id: String
}

// Расширение для конвертации Color в HEX
extension Color {
    func toHex() -> String? {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1.0)
        
        if components.count >= 4 {
            a = Float(components[3])
        }
        
        if a != Float(1.0) {
            return String(format: "%02lX%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255), lroundf(a * 255))
        } else {
            return String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        }
    }
}
