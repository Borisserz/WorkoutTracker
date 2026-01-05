internal import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var viewModel: WorkoutViewModel
    @Environment(\.dismiss) var dismiss
    
    // --- ДАННЫЕ ПОЛЬЗОВАТЕЛЯ ---
    @AppStorage("userName") private var userName = "Fitness Enthusiast"
    @AppStorage("userBodyWeight") private var userBodyWeight = 75.0
    @AppStorage("userGender") private var userGender = "male" // "male" or "female"
    
    // Состояния для редактирования
    @State private var isEditingName = false
    @State private var isEditingWeight = false
    @State private var tempName = ""
    @State private var tempWeight = ""
    
    @State private var selectedAchievement: Achievement?
    
    // Ачивки
    var achievements: [Achievement] {
        let streak = viewModel.calculateWorkoutStreak()
        return AchievementCalculator.calculateAchievements(workouts: viewModel.workouts, streak: streak)
    }
    
    // Рекорды
    var personalRecords: [WorkoutViewModel.BestResult] {
        return viewModel.getAllPersonalRecords()
    }
    
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 25) {
                    
                    // 1. HEADER (Аватар, Имя, Вес)
                    VStack(spacing: 15) {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.gray.opacity(0.3))
                            .overlay(Circle().stroke(Color.blue, lineWidth: 3))
                            .shadow(radius: 5)
                        
                        VStack(spacing: 8) {
                            // ИМЯ (Кликабельное)
                            HStack {
                                Text(userName).font(.title2).bold()
                                Image(systemName: "pencil").font(.caption).foregroundColor(.blue)
                            }
                           
                            
                            // ВЕС (Кликабельный)
                            HStack {
                                Text("Weight: \(String(format: "%.1f", userBodyWeight)) kg")
                                    .font(.subheadline).foregroundColor(.secondary)
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.1)).cornerRadius(8)
                            }
                            
                            // ПЕРЕКЛЮЧАТЕЛЬ ПОЛА
                            Picker("Gender", selection: $userGender) {
                                Text("Male").tag("male")
                                Text("Female").tag("female")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 200)
                            
                        }
                    }
                    .padding(.top, 20)
                    
                    // 2. СЕТКА АЧИВОК
                    VStack(alignment: .leading) {
                        Text("Achievements").font(.title3).bold().padding(.horizontal)
                        
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(achievements) { achievement in
                                AchievementBadge(achievement: achievement).onTapGesture {
                                   selectedAchievement = achievement
                                    
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                }
                        }
                    }
                    .padding(.horizontal)
                    }
                    
                    Divider()
                    
                    // 3. ЛИЧНЫЕ РЕКОРДЫ (НОВАЯ СЕКЦИЯ)
                    if !personalRecords.isEmpty {
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Personal Records").font(.title3).bold().padding(.horizontal)
                            
                            VStack(spacing: 0) {
                                ForEach(personalRecords) { record in
                                    HStack {
                                        // Иконка типа
                                        Image(systemName: getIcon(for: record.type))
                                            .foregroundColor(getColor(for: record.type))
                                            .frame(width: 30)
                                        
                                        Text(LocalizedStringKey(record.exerciseName))
                                            .font(.body)
                                        
                                        Spacer()
                                        
                                        Text(record.value)
                                            .font(.headline)
                                            .foregroundColor(.blue)
                                    }
                                    .padding()
                                    
                                    if record.id != personalRecords.last?.id {
                                        Divider().padding(.leading, 50)
                                    }
                                }
                            }
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    } else {
                        Text("Complete workouts to see your records!")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
            // АЛЕРТЫ
            .alert("Change Name", isPresented: $isEditingName) {
                TextField("Name", text: $tempName)
                Button("Save") { if !tempName.isEmpty { userName = tempName } }
                Button("Cancel", role: .cancel) { }
            }
            .alert("Update Body Weight", isPresented: $isEditingWeight) {
                TextField("Weight (kg)", text: $tempWeight).keyboardType(.decimalPad)
                Button("Save") { if let val = Double(tempWeight) { userBodyWeight = val } }
                Button("Cancel", role: .cancel) { }
            }
            .alert(item: $selectedAchievement) { achievement in
                Alert(
                    title: Text(achievement.title),
                    message: Text(achievement.description + "\n\n" + (achievement.isUnlocked ? "✅ Unlocked" : "🔒 Locked")),
                    dismissButton: .default(Text("Cool!"))
                )
            }
        }
    }
    
    // Вспомогательные функции для иконок
    func getIcon(for type: ExerciseType) -> String {
        switch type {
        case .strength: return "dumbbell.fill"
        case .cardio: return "figure.run"
        case .duration: return "stopwatch.fill"
        }
    }
    
    func getColor(for type: ExerciseType) -> Color {
        switch type {
        case .strength: return .blue
        case .cardio: return .orange
        case .duration: return .purple
        }
    }
}

// AchievementBadge без изменений (но должен быть в проекте)
struct AchievementBadge: View {
    let achievement: Achievement
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? achievement.color.opacity(0.15) : Color.gray.opacity(0.1))
                    .frame(width: 75, height: 75)
                Image(systemName: achievement.icon)
                    .font(.largeTitle)
                    .foregroundColor(achievement.isUnlocked ? achievement.color : .gray)
            }
            .overlay(alignment: .bottomTrailing) {
                if !achievement.isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.caption).foregroundColor(.white)
                        .padding(5).background(Circle().fill(Color.gray))
                        .offset(x: 0, y: 5)
                }
            }
            Text(achievement.title)
                .font(.caption).fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundColor(achievement.isUnlocked ? .primary : .secondary)
                .lineLimit(2)
                .frame(height: 35, alignment: .top)
        }
        .contentShape(Rectangle())
    }
}
