//
//  WorkoutShareCard.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 28.12.25.
//

//
//  WorkoutShareCard.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 28.12.25.
//

internal import SwiftUI
internal import UniformTypeIdentifiers

struct WorkoutShareCard: View {
    let workout: Workout
    
    // Вычисляем общий тоннаж
    var totalVolume: Int {
        Int(workout.exercises.reduce(0) { $0 + $1.computedVolume })
    }
    
    // Вычисляем топ-3 группы мышц
    var topMuscles: [String] {
        var counts: [String: Int] = [:]
        for ex in workout.exercises {
            let group = ex.isSuperset ? (ex.subExercises.first?.muscleGroup ?? "Mixed") : ex.muscleGroup
            counts[group, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
    }
    
    var body: some View {
        ZStack {
            // 1. ФОН (Темный градиент)
            LinearGradient(
                colors: [Color(hex: "1a1a1a"), Color(hex: "000000")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Декоративные круги на фоне
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 300)
                .offset(x: -150, y: -200)
            Circle()
                .fill(Color.purple.opacity(0.1))
                .frame(width: 200)
                .offset(x: 150, y: 250)
            
            VStack(spacing: 25) {
                
                // 2. ЗАГОЛОВОК
                HStack {
                    Image(systemName: "dumbbell.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                    Text("WORKOUT COMPLETE")
                        .font(.headline)
                        .tracking(2) // Разрядка букв
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 40)
                
                // 3. НАЗВАНИЕ И ДАТА
                VStack(spacing: 5) {
                    Text(workout.title)
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text(workout.date.formatted(date: .long, time: .omitted))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Divider().background(Color.gray.opacity(0.3))
                
                // 4. ГРИД СТАТИСТИКИ (Самое вкусное)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 30) {
                    // Время
                    statCell(title: "DURATION", value: "\(workout.duration) min", icon: "stopwatch", color: .yellow)
                    
                    // Объем (Тоннаж)
                    statCell(title: "TOTAL VOLUME", value: "\(totalVolume) kg", icon: "scalemass", color: .green)
                    
                    // Количество упражнений
                    statCell(title: "EXERCISES", value: "\(workout.exercises.count)", icon: "list.bullet", color: .blue)
                    
                    // Интенсивность
                    statCell(title: "AVG EFFORT", value: "\(workout.effortPercentage)%", icon: "flame.fill", color: .red)
                }
                .padding(.horizontal)
                
                // 5. ТОП МЫШЦ (Теги)
                if !topMuscles.isEmpty {
                    VStack(spacing: 10) {
                        Text("TARGETED MUSCLES")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                        
                        HStack {
                            ForEach(topMuscles, id: \.self) { muscle in
                                Text(muscle.uppercased())
                                    .font(.caption2)
                                    .bold()
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.white.opacity(0.1))
                                    .foregroundColor(.white)
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            }
                        }
                    }
                }
                
                Spacer()
                
                // 6. ФУТЕР (Брендинг)
                HStack {
                    Image(systemName: "applewatch")
                    Text("Tracked with WorkoutTracker")
                }
                .font(.caption)
                .foregroundColor(.gray.opacity(0.5))
                .padding(.bottom, 30)
            }
        }
        .frame(width: 400, height: 600) // Фиксированный размер для картинки
        .cornerRadius(0) // Прямоугольник для экспорта
    }
    
    // Вспомогательная ячейка
    func statCell(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            Text(value)
                .font(.title3)
                .bold()
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.gray)
        }
    }
}

// Вспомогательный экстеншен для HEX цветов
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
struct ShareableImage: Transferable {
    let uiImage: UIImage
    
    static var transferRepresentation: some TransferRepresentation {
        // Мы говорим: "Экспортируй это как JPEG"
        DataRepresentation(exportedContentType: .jpeg) { item in
            if let data = item.uiImage.jpegData(compressionQuality: 0.9) {
                return data
            } else {
                return Data()
            }
        }
    }}
#Preview {
    WorkoutShareCard(workout: Workout.examples[0])
}
