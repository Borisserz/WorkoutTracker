internal import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var viewModel: WorkoutViewModel
    // ProgressManager нам больше не нужен, так как мы убрали уровень
    @Environment(\.dismiss) var dismiss
    
    // Состояние для выбранной ачивки (чтобы показать описание)
    @State private var selectedAchievement: Achievement?
    
    // Вычисляем ачивки на лету
    var achievements: [Achievement] {
        let streak = viewModel.calculateWorkoutStreak()
        return AchievementCalculator.calculateAchievements(workouts: viewModel.workouts, streak: streak)
    }
    
    // Сетка: 3 колонки
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 25) {
                    
                    // 1. HEADER (Только Аватар и Имя)
                    VStack(spacing: 15) {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.gray.opacity(0.3))
                            .overlay(
                                Circle().stroke(Color.blue, lineWidth: 3)
                            )
                            .shadow(radius: 5)
                        
                        VStack(spacing: 5) {
                            Text("Fitness Enthusiast") // Тут можно сделать поле для ввода имени
                                .font(.title2)
                                .bold()
                            
                            Text("Keep pushing your limits!")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 20)
                    
                    // 2. СТАТИСТИКА (Streak и кол-во)
                    HStack(spacing: 40) {
                        statItem(value: "\(viewModel.workouts.count)", label: "Workouts")
                        
                        VStack {
                            Image(systemName: "flame.fill")
                                .font(.title)
                                .foregroundColor(.orange)
                            Text("\(viewModel.calculateWorkoutStreak())")
                                .font(.title2).bold()
                            Text("Day Streak").font(.caption).foregroundColor(.secondary)
                        }
                        
                        let unlockedCount = achievements.filter { $0.isUnlocked }.count
                        statItem(value: "\(unlockedCount)", label: "Unlocked")
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // 3. СЕТКА АЧИВОК
                    VStack(alignment: .leading) {
                        Text("Achievements")
                            .font(.title3)
                            .bold()
                            .padding(.horizontal)
                            .padding(.bottom, 5)
                        
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(achievements) { achievement in
                                AchievementBadge(achievement: achievement)
                                    // ДОБАВИЛИ НАЖАТИЕ
                                    .onTapGesture {
                                        selectedAchievement = achievement
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
            // --- ВСПЛЫВАЮЩЕЕ ОКНО С ОПИСАНИЕМ ---
            .alert(item: $selectedAchievement) { achievement in
                Alert(
                    title: Text(achievement.title),
                    message: Text(achievement.description + "\n\n" + (achievement.isUnlocked ? "✅ Unlocked" : "🔒 Locked")),
                    dismissButton: .default(Text("Cool!"))
                )
            }
        }
    }
    
    func statItem(value: String, label: String) -> some View {
        VStack {
            Text(value).font(.title2).bold()
            Text(label).font(.caption).foregroundColor(.secondary)
        }
    }
}

// --- ЯЧЕЙКА АЧИВКИ ---
struct AchievementBadge: View {
    let achievement: Achievement
    
    var body: some View {
        VStack {
            ZStack {
                // Фон круга
                Circle()
                    .fill(achievement.isUnlocked ? achievement.color.opacity(0.15) : Color.gray.opacity(0.1))
                    .frame(width: 75, height: 75)
                    .shadow(color: achievement.isUnlocked ? achievement.color.opacity(0.3) : .clear, radius: 5)
                
                // Иконка
                Image(systemName: achievement.icon)
                    .font(.largeTitle) // Чуть крупнее
                    .foregroundColor(achievement.isUnlocked ? achievement.color : .gray)
            }
            .overlay(alignment: .bottomTrailing) {
                // Замочек, если закрыто
                if !achievement.isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(5)
                        .background(Circle().fill(Color.gray))
                        .offset(x: 0, y: 5)
                }
            }
            
            // Текст
            Text(achievement.title)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundColor(achievement.isUnlocked ? .primary : .secondary)
                .lineLimit(2)
                .frame(height: 35, alignment: .top) // Фиксированная высота для ровности сетки
            
            // Прогресс бар (например, 4/10)
            if !achievement.isUnlocked && !achievement.progress.isEmpty {
                Text(achievement.progress)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else if achievement.isUnlocked {
                // Галочка если открыто
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(achievement.color)
            }
        }
        .contentShape(Rectangle()) // Чтобы нажатие работало на всей области, включая пустоты
    }
}
