//
//  AIWeeklyReviewSheet.swift
//  WorkoutTracker
//

internal import SwiftUI

struct AIWeeklyReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    // Принимаем реальные данные из StatsView
    let currentStats: WorkoutViewModel.PeriodStats
    let previousStats: WorkoutViewModel.PeriodStats
    let weakPoints: [WorkoutViewModel.WeakPoint]
    let recentPRs: [WorkoutViewModel.PersonalRecord]
    
    @State private var isAnalyzing = false
    @State private var reviewText: String? = nil
    
    private let aiService = AILogicService(apiKey: Secrets.geminiApiKey)
    
    var body: some View {
        ZStack {
            // Фон
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            // Декоративные пятна на фоне (Glassmorphism)
            Circle()
                .fill(Color.purple.opacity(0.3))
                .blur(radius: 60)
                .frame(width: 300, height: 300)
                .offset(x: -100, y: -200)
            
            Circle()
                .fill(Color.blue.opacity(0.3))
                .blur(radius: 60)
                .frame(width: 300, height: 300)
                .offset(x: 150, y: 200)
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                        .font(.title2)
                    
                    Text(LocalizedStringKey("AI Performance Review"))
                        .font(.title2)
                        .bold()
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.title2)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .zIndex(1)
                
                // Контент
                if let text = reviewText {
                    // РЕЗУЛЬТАТ (Markdown)
                    ScrollView {
                        Text(.init(text))
                            .font(.body)
                            .lineSpacing(6)
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(LinearGradient(colors: [.purple.opacity(0.5), .blue.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                            )
                            .padding()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    
                } else if isAnalyzing {
                    // АНИМАЦИЯ ЗАГРУЗКИ
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 80, height: 80)
                                .modifier(PulsatingGlowEffect())
                            
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        }
                        
                        Text(LocalizedStringKey("Analyzing your week..."))
                            .font(.headline)
                            .foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
                            .modifier(BlinkingTextModifier())
                    }
                    .frame(maxHeight: .infinity)
                    .transition(.opacity)
                    
                } else {
                    // НАЧАЛЬНЫЙ ЭКРАН (Кнопка)
                    VStack(spacing: 24) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 100))
                            .foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .shadow(color: .purple.opacity(0.4), radius: 15, x: 0, y: 10)
                        
                        Text(LocalizedStringKey("Ready to dive into your stats?"))
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Button {
                            generateReview()
                        } label: {
                            HStack {
                                Image(systemName: "bolt.fill")
                                Text(LocalizedStringKey("Analyze My Week")).bold()
                            }
                            .font(.title3)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: .purple.opacity(0.4), radius: 10, x: 0, y: 5)
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
                    }
                    .frame(maxHeight: .infinity)
                    .transition(.opacity)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
    
    private func generateReview() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        withAnimation(.easeInOut) {
            isAnalyzing = true
        }
        
        let safeUnits = UnitsManager.shared.weightUnitString()
        let safePRs = recentPRs
        let safeWeakPoints = weakPoints
        let cStats = currentStats
        let pStats = previousStats
        let lang = Locale.current.language.languageCode?.identifier == "ru" ? "Russian" : "English"
        
        // ИСПРАВЛЕНИЕ: Выносим тяжелую сборку строк в фоновый поток (Detached Task)
        Task.detached(priority: .userInitiated) {
            let prNames = safePRs.isEmpty ? "None" : safePRs.map { "\($0.exerciseName) (\(Int($0.weight)) \(safeUnits))" }.joined(separator: ", ")
            let weakNames = safeWeakPoints.isEmpty ? "None" : safeWeakPoints.map { $0.muscleGroup }.joined(separator: ", ")
            
            let context = """
                THIS WEEK: \(cStats.workoutCount) workouts, \(Int(cStats.totalVolume)) \(safeUnits) total volume.
                PREVIOUS WEEK: \(pStats.workoutCount) workouts, \(Int(pStats.totalVolume)) \(safeUnits) total volume.
                NEW PERSONAL RECORDS THIS WEEK: \(prNames).
                IDENTIFIED WEAK POINTS (based on last 30 days): \(weakNames).
                """
            
            do {
                let markdownResponse = try await aiService.generatePerformanceReview(statsContext: context, language: lang)
                
                await MainActor.run {
                    let successGen = UINotificationFeedbackGenerator()
                    successGen.notificationOccurred(.success)
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        self.reviewText = markdownResponse
                        self.isAnalyzing = false
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation {
                        self.reviewText = "❌ **Error:** \(error.localizedDescription)"
                        self.isAnalyzing = false
                    }
                }
            }
        }
    }
}

// MARK: - Animations

struct PulsatingGlowEffect: ViewModifier {
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.5
    
    func body(content: Content) -> some View {
        content
            .background(
                Circle()
                    .fill(Color.purple.opacity(opacity))
                    .scaleEffect(scale)
                    .blur(radius: 10)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    scale = 1.3
                    opacity = 0.1
                }
            }
            .onDisappear {
                scale = 1.0
                opacity = 0.5
            }
    }
}

struct BlinkingTextModifier: ViewModifier {
    @State private var isBlinking = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isBlinking ? 0.4 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isBlinking = true
                }
            }
            .onDisappear {
                isBlinking = false
            }
    }
}
