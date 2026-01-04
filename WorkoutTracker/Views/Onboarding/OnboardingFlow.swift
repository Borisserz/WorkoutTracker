//
//  OnboardingFlow.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//

internal import SwiftUI

// MARK: - Модель для одного слайда онбординга
struct OnboardingItem: Identifiable {
    let id = UUID()
    let image: String
    let title: String
    let description: String
    let color: Color
}

// MARK: - Главный контейнер анбординга
struct OnboardingFlowView: View {
    @Binding var isOnboardingCompleted: Bool
    @EnvironmentObject var tutorialManager: TutorialManager
    
    // Используем TabView для навигации между шагами
    @State private var currentTab = 0
    
    // Данные для профиля
    @AppStorage("userName") private var userName = "Champion"
    @AppStorage("userBodyWeight") private var userBodyWeight = 75.0
    
    var body: some View {
        ZStack {
            // Фон
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            TabView(selection: $currentTab) {
                // ШАГ 1: Приветствие и Слайды
                OnboardingIntroView(onNext: { nextStep() })
                    .tag(0)
                
                // ШАГ 2: Данные пользователя
                UserDataInputView(name: $userName, weight: $userBodyWeight, onNext: { nextStep() })
                    .tag(1)
                
                // ШАГ 3: Разрешения
                // ИСПРАВЛЕНО: onNext вместо onFinish, и действие nextStep() вместо completeOnboarding()
                PermissionsView(onNext: {
                    nextStep()
                })
                .tag(2)
                
                // ШАГ 4: Выбор туториала
                TutorialChoiceView(onFinish: {
                    completeOnboarding()
                })
                .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentTab)
            // Блокируем свайп, навигация только кнопками
            .interactiveDismissDisabled()
        }
    }
    
    private func nextStep() {
        withAnimation {
            currentTab += 1
        }
    }
    
    private func completeOnboarding() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        withAnimation {
            isOnboardingCompleted = true
        }
    }
}

// MARK: - ШАГ 1: Интро
struct OnboardingIntroView: View {
    var onNext: () -> Void
    
    let items: [OnboardingItem] = [
        OnboardingItem(image: "dumbbell.fill", title: "Track Workouts", description: "Log your sets, reps, and weights with ease. Support for supersets included.", color: .blue),
        OnboardingItem(image: "figure.mind.and.body", title: "Muscle Recovery", description: "Smart heatmap tracks your muscle fatigue and suggests recovery times.", color: .red),
        OnboardingItem(image: "chart.xyaxis.line", title: "Analyze Progress", description: "Visualize your gains with detailed charts and personal records.", color: .purple)
    ]
    
    @State private var slideIndex = 0
    
    var body: some View {
        VStack {
            TabView(selection: $slideIndex) {
                ForEach(0..<items.count, id: \.self) { index in
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: items[index].image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 120)
                            .foregroundColor(items[index].color)
                            .padding()
                            .background(
                                Circle().fill(items[index].color.opacity(0.1))
                                    .frame(width: 220, height: 220)
                            )
                        
                        Text(items[index].title)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .padding(.top, 20)
                        
                        Text(items[index].description)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 30)
                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            
            // Кнопка Далее
            Button(action: {
                if slideIndex < items.count - 1 {
                    withAnimation { slideIndex += 1 }
                } else {
                    onNext()
                }
            }) {
                Text(slideIndex == items.count - 1 ? "Let's Set Up Profile" : "Next")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 50)
        }
    }
}

// MARK: - ШАГ 2: Ввод данных
struct UserDataInputView: View {
    @Binding var name: String
    @Binding var weight: Double
    var onNext: () -> Void
    
    @FocusState private var isNameFocused: Bool
    @State private var weightString: String = ""
    
    var body: some View {
        VStack(spacing: 25) {
            Spacer()
            
            Text("About You")
                .font(.largeTitle).bold()
            
            Text("This helps us personalize your profile and calculate stats.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Your Name").font(.caption).foregroundColor(.gray)
                    TextField("Name", text: $name)
                        .font(.title3)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .focused($isNameFocused)
                        .submitLabel(.next)
                }
                
                VStack(alignment: .leading) {
                    Text("Body Weight (kg)").font(.caption).foregroundColor(.gray)
                    TextField("75", text: $weightString)
                        .font(.title3)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .onChange(of: weightString) { _, newValue in
                            if let val = Double(newValue) {
                                weight = val
                            }
                        }
                }
            }
            .padding(.horizontal, 30)
            
            Spacer()
            
            Button(action: onNext) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(name.isEmpty || weightString.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(12)
            }
            .disabled(name.isEmpty || weightString.isEmpty)
            .padding(.horizontal, 30)
            .padding(.bottom, 50)
        }
        .onAppear {
            weightString = String(format: "%.0f", weight)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isNameFocused = true
            }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

// MARK: - ШАГ 3: Разрешения
struct PermissionsView: View {
    var onNext: () -> Void
    @State private var notificationsAllowed = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 80))
                .foregroundColor(.orange)
                .padding()
                .background(Circle().fill(Color.orange.opacity(0.1)).frame(width: 150, height: 150))
            
            Text("Stay on Track")
                .font(.largeTitle).bold()
            
            Text("Enable notifications to use the Rest Timer and get streak reminders. We promise not to spam.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button {
                requestNotifications()
            } label: {
                HStack {
                    Text(notificationsAllowed ? "Allowed" : "Enable Notifications")
                    if notificationsAllowed {
                        Image(systemName: "checkmark")
                    }
                }
                .fontWeight(.semibold)
                .padding()
                .frame(maxWidth: .infinity)
                .background(notificationsAllowed ? Color.green : Color.orange)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal, 50)
            .disabled(notificationsAllowed)
            
            Spacer()
            
            Button(action: onNext) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 50)
        }
    }
    
    private func requestNotifications() {
        NotificationManager.shared.requestPermission { granted in
            DispatchQueue.main.async {
                withAnimation {
                    self.notificationsAllowed = granted
                }
            }
        }
    }
}

// MARK: - ШАГ 4: Выбор обучения
struct TutorialChoiceView: View {
    var onFinish: () -> Void
    @EnvironmentObject var tutorialManager: TutorialManager
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 80))
                .foregroundColor(.purple)
                .padding()
                .background(Circle().fill(Color.purple.opacity(0.1)).frame(width: 150, height: 150))
            
            Text("Quick Tutorial")
                .font(.largeTitle).bold()
            
            Text("Would you like a quick interactive tour to learn how to create workouts and track progress?")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Spacer()
            
            VStack(spacing: 15) {
                // Кнопка ДА
                Button {
                    startTutorial()
                } label: {
                    Text("Start Tutorial")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                }
                
                // Кнопка НЕТ
                Button {
                    skipTutorial()
                } label: {
                    Text("No, I'll figure it out")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding()
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
    }
    
    private func startTutorial() {
        tutorialManager.reset()
        onFinish()
    }
    
    private func skipTutorial() {
        tutorialManager.complete()
        onFinish()
    }
} // <--- ВОТ ЭТА СКОБКА БЫЛА ПРОПУЩЕНА!

// Расширение теперь находится вне структуры
extension NotificationManager {
    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            completion(granted)
            if granted {
                print("🔔 Notifications allowed")
            } else if let error = error {
                print("❌ Notification error: \(error.localizedDescription)")
            }
        }
    }
}
