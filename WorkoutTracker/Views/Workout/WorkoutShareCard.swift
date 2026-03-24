
//
//  WorkoutShareCard.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 28.12.25.
//
//  Вьюха, предназначенная для рендеринга в картинку (ImageRenderer).
//  Отображает красивую сводку по тренировке (статистика, мышцы, брендинг)
//  на темном градиентном фоне.
//

internal import SwiftUI
internal import UniformTypeIdentifiers

// Обертка для ActivityViewController (Share Sheet)
struct SharedImageWrapper: Identifiable {
    let id = UUID()
    let image: UIImage
}

// Карточка для шаринга Ачивок и Рекордов (Social Flex)
struct MilestoneShareCard: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let icon: String
    let colors: [Color]
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1a1a1a"), Color(hex: "000000")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Circle()
                .fill(colors.first?.opacity(0.2) ?? Color.blue.opacity(0.2))
                .frame(width: 400)
                .offset(x: -200, y: -300)
            
            Circle()
                .fill(colors.last?.opacity(0.2) ?? Color.purple.opacity(0.2))
                .frame(width: 300)
                .offset(x: 200, y: 300)
            
            VStack(spacing: 30) {
                HStack {
                    Image(systemName: "star.fill")
                        .font(.title)
                        .foregroundColor(.yellow)
                    Text(title)
                        .font(.headline)
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 80)
                
                Spacer()
                
                ZStack {
                    Circle()
                        .strokeBorder(
                            AngularGradient(gradient: Gradient(colors: colors), center: .center),
                            lineWidth: 20
                        )
                        .frame(width: 350, height: 350)
                        .shadow(color: colors.first?.opacity(0.5) ?? .clear, radius: 20)
                    
                    Image(systemName: icon)
                        .font(.system(size: 140))
                        .foregroundStyle(
                            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 5)
                }
                
                Text(subtitle)
                    .font(.system(size: 60, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                
                Spacer()
                
                HStack {
                    Image(systemName: "applewatch")
                    Text(LocalizedStringKey("Tracked with WorkoutTracker"))
                }
                .font(.title)
                .foregroundColor(.gray.opacity(0.5))
                .padding(.bottom, 80)
            }
        }
        .frame(width: 1080, height: 1080)
    }
}

struct WorkoutShareCard: View {
    
    // MARK: - Properties
    
    let workout: Workout
    
    // MARK: - Computed Logic
    
    /// Общий тоннаж (используем закэшированное значение из модели)
    private var totalVolume: Int {
        Int(workout.totalStrengthVolume)
    }
    
    /// Топ-3 группы мышц по количеству упражнений
    private var topMuscles: [String] {
        var counts: [String: Int] = [:]
        
        for ex in workout.exercises {
            // Если супер-сет, берем группу первого упражнения, иначе основную
            let group = ex.isSuperset ? (ex.subExercises.first?.muscleGroup ?? "Mixed") : ex.muscleGroup
            counts[group, default: 0] += 1
        }
        
        // Сортируем по убыванию частоты и берем первые 3
        return counts.sorted { $0.value > $1.value }
                     .prefix(3)
                     .map { $0.key }
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // 1. Фон (Градиент + Пузыри)
            backgroundLayer
            
            // 2. Контент
            VStack(spacing: 25) {
                
                headerSection
                
                titleSection
                
                Divider().background(Color.gray.opacity(0.3))
                
                statsGridSection
                
                tagsSection
                
                Spacer()
                
                footerSection
            }
        }
        .frame(width: 400, height: 600) // Фиксированный размер для корректного экспорта
        .cornerRadius(0) // Прямые углы для картинки
    }
    
    // MARK: - View Components
    
    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1a1a1a"), Color(hex: "000000")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Декоративные круги
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 300)
                .offset(x: -150, y: -200)
            
            Circle()
                .fill(Color.purple.opacity(0.1))
                .frame(width: 200)
                .offset(x: 150, y: 250)
        }
    }
    
    private var headerSection: some View {
        HStack {
            Image(systemName: "dumbbell.fill")
                .font(.title)
                .foregroundColor(.blue)
            
            Text(LocalizedStringKey("WORKOUT COMPLETE"))
                .font(.headline)
                .tracking(2) // Разрядка букв
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.top, 40)
    }
    
    private var titleSection: some View {
        VStack(spacing: 5) {
            Text(workout.title)
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text(workout.date.formatted(date: .long, time: .omitted))
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
    
    private var statsGridSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 30) {
            statCell(title: "DURATION", value: "\(workout.durationSeconds / 60) min", icon: "stopwatch", color: .yellow)
            statCell(title: "TOTAL VOLUME", value: "\(totalVolume) kg", icon: "scalemass", color: .green)
            statCell(title: "EXERCISES", value: "\(workout.exercises.count)", icon: "list.bullet", color: .blue)
            statCell(title: "AVG EFFORT", value: "\(workout.effortPercentage)%", icon: "flame.fill", color: .red)
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var tagsSection: some View {
        if !topMuscles.isEmpty {
            VStack(spacing: 10) {
                Text(LocalizedStringKey("TARGETED MUSCLES"))
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
    }
    
    private var footerSection: some View {
        HStack {
            Image(systemName: "applewatch")
            Text(LocalizedStringKey("Tracked with WorkoutTracker"))
        }
        .font(.caption)
        .foregroundColor(.gray.opacity(0.5))
        .padding(.bottom, 30)
    }
    
    // MARK: - Helpers
    
    private func statCell(title: String, value: String, icon: String, color: Color) -> some View {
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

// MARK: - Extensions

extension Color {
    /// Инициализация цвета через HEX строку (например "1a1a1a")
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

// MARK: - Shareable Model

/// Обертка для передачи картинки через ShareSheet
struct ShareableImage: Transferable {
    let uiImage: UIImage
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .jpeg) { item in
            if let data = item.uiImage.jpegData(compressionQuality: 0.9) {
                return data
            } else {
                return Data()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    WorkoutShareCard(workout: Workout.examples[0])
}
