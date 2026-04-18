import SwiftUI

// MARK: - 2. ВКЛАДКА "ОБЗОР"
struct OverviewTab: View {
   @State private var addedExercises: [ExerciseItem] = []
   
   @State private var showSettings = false
   @State private var showAIBot = false
   @State private var showExerciseSearch = false
   
   @State private var isFrontView = true
   @State private var selectedMuscle: String? = nil
   
   var body: some View {
       NavigationStack {
           ZStack(alignment: .topTrailing) {
               PremiumDarkBackground()
               
               ScrollView(showsIndicators: false) {
                   VStack(alignment: .leading, spacing: 30) {
                       
                       // Заголовок
                       HStack {
                           VStack(alignment: .leading, spacing: 4) {
                               Text("Обзор")
                                   .font(.system(size: 34, weight: .heavy, design: .rounded))
                                   .foregroundStyle(.white)
                               Text("Готов крушить рекорды? 🚀")
                                   .font(.subheadline)
                                   .fontWeight(.medium)
                                   .foregroundStyle(.white.opacity(0.6))
                           }
                           Spacer()
                           Button {
                               withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                   showSettings.toggle()
                               }
                           } label: {
                               Image(systemName: "gearshape.fill")
                                   .font(.system(size: 22))
                                   .foregroundStyle(.white)
                                   .padding(12)
                                   .background(.ultraThinMaterial, in: Circle())
                                   .overlay(Circle().stroke(LinearGradient(colors: [.white.opacity(0.6), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                                   .shadow(color: .white.opacity(0.1), radius: 10)
                           }
                       }
                       .padding(.top, 20)
                       
                       // НОВАЯ ФИЧА: Dribbble Кольца активности
                       DailyActivityRings()
                       
                       // НОВАЯ ФИЧА: Live Vitals
                       LiveVitalsCard()
                       
                       // 1. ОСТРОВОК (Диаграмма)
                       MusclePieChartIsland(exercises: addedExercises)
                       
                       // 2. ВОССТАНОВЛЕНИЕ МЫШЦ
                       VStack(alignment: .leading, spacing: 16) {
                           Text("Восстановление мышц")
                               .font(.title2.weight(.bold))
                               .foregroundStyle(.white)
                           
                           AnatomyRecoveryView(
                               isFrontView: $isFrontView,
                               selectedMuscle: $selectedMuscle
                           )
                       }
                       
                       // 3. ИИ АВТОПИЛОТ
                       PremiumGlassButton(
                           title: "ИИ Автопилот",
                           subtitle: "Твой карманный тренер",
                           icon: "brain.head.profile",
                           colorTint: Color.neonBlue
                       ) {
                           let impact = UIImpactFeedbackGenerator(style: .medium)
                           impact.impactOccurred()
                           showAIBot = true
                       }
                       
                       // 4. ПЛАН НА СЕГОДНЯ
                       VStack(alignment: .leading, spacing: 12) {
                           HStack {
                               Text("План на сегодня")
                                   .font(.title2.weight(.bold))
                                   .foregroundStyle(.white)
                               Spacer()
                               Button {
                                   let impact = UIImpactFeedbackGenerator(style: .light)
                                   impact.impactOccurred()
                                   showExerciseSearch = true
                               } label: {
                                   Image(systemName: "plus.circle.fill")
                                       .font(.system(size: 28))
                                       .foregroundStyle(Color.neonGreen)
                                       .shadow(color: Color.neonGreen.opacity(0.6), radius: 10)
                               }
                           }
                           
                           if addedExercises.isEmpty {
                               Text("Нажми +, чтобы добавить упражнения")
                                   .font(.subheadline)
                                   .foregroundStyle(.white.opacity(0.5))
                                   .padding(.top, 10)
                           } else {
                               VStack(spacing: 12) {
                                   ForEach(addedExercises) { ex in
                                       HStack {
                                           Circle()
                                               .fill(ex.group.color)
                                               .frame(width: 12, height: 12)
                                               .shadow(color: ex.group.color.opacity(0.8), radius: 5)
                                           
                                           Text(ex.name)
                                               .font(.system(size: 16, weight: .bold, design: .rounded))
                                               .foregroundStyle(.white)
                                           Spacer()
                                           Image(systemName: "checkmark.circle.fill")
                                               .foregroundStyle(Color.white.opacity(0.2))
                                       }
                                       .padding()
                                       .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                                       .overlay(
                                           RoundedRectangle(cornerRadius: 16)
                                               .stroke(LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                                       )
                                   }
                               }
                           }
                       }
                       
                       Spacer(minLength: 120)
                   }
                   .padding(.horizontal, 20)
               }
               
               if showSettings {
                   SettingsDropdownMenu(isShowing: $showSettings)
                       .padding(.top, 80)
                       .padding(.trailing, 20)
                       .zIndex(2)
               }
           }
       }
       .sheet(isPresented: $showExerciseSearch) { ExerciseSearchView(addedExercises: $addedExercises) }
       .sheet(isPresented: $showAIBot) { AIChatBotView() }
   }
}

// MARK: - НОВЫЕ DRIBBBLE ФИЧИ (Кольца и Пульс)
struct DailyActivityRings: View {
   @State private var animate = false
   
   var body: some View {
       HStack(spacing: 20) {
           ActivityRing(color: .neonRed, progress: 0.7, icon: "flame.fill", title: "Ккал")
           ActivityRing(color: .neonGreen, progress: 0.5, icon: "figure.run", title: "Мин")
           ActivityRing(color: .neonBlue, progress: 0.8, icon: "drop.fill", title: "Вода")
       }
       .padding(.vertical, 10)
       .onAppear {
           withAnimation(.spring(response: 1.5, dampingFraction: 0.7).delay(0.2)) {
               animate = true
           }
       }
   }
}
 
struct ActivityRing: View {
   var color: Color
   var progress: CGFloat
   var icon: String
   var title: String
   @State private var currentProgress: CGFloat = 0
   
   var body: some View {
       VStack(spacing: 8) {
           ZStack {
               Circle().stroke(color.opacity(0.15), lineWidth: 8).frame(width: 60, height: 60)
               Circle()
                   .trim(from: 0, to: currentProgress)
                   .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                   .frame(width: 60, height: 60)
                   .rotationEffect(.degrees(-90))
                   .shadow(color: color.opacity(0.6), radius: 8)
               Image(systemName: icon).foregroundStyle(color).font(.system(size: 18, weight: .bold))
           }
           Text(title).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.7))
       }
       .onAppear {
           withAnimation(.easeOut(duration: 1.5)) { currentProgress = progress }
       }
   }
}
 
struct LiveVitalsCard: View {
   @State private var isPulsing = false
   
   var body: some View {
       HStack(spacing: 16) {
           ZStack {
               Circle().fill(Color.neonRed.opacity(0.2)).frame(width: 40, height: 40)
                   .scaleEffect(isPulsing ? 1.3 : 1.0).opacity(isPulsing ? 0 : 1)
               Circle().fill(Color.neonRed.opacity(0.2)).frame(width: 40, height: 40)
                   .scaleEffect(isPulsing ? 1.1 : 1.0)
               Image(systemName: "heart.fill").foregroundStyle(Color.neonRed).font(.system(size: 20))
                   .scaleEffect(isPulsing ? 1.1 : 0.9)
           }
           
           VStack(alignment: .leading, spacing: 2) {
               Text("Текущий пульс").font(.caption).foregroundStyle(.white.opacity(0.6))
               HStack(alignment: .bottom, spacing: 2) {
                   Text("84").font(.system(size: 28, weight: .black, design: .rounded)).foregroundStyle(.white)
                   Text("BPM").font(.caption.bold()).foregroundStyle(Color.neonRed).padding(.bottom, 4)
               }
           }
           Spacer()
           Image(systemName: "waveform.path.ecg").font(.system(size: 30)).foregroundStyle(Color.neonRed.opacity(0.5))
       }
       .padding(20)
       .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
       .overlay(RoundedRectangle(cornerRadius: 24).stroke(LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
       .shadow(color: Color.neonRed.opacity(0.15), radius: 20, x: 0, y: 10)
       .onAppear {
           withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { isPulsing = true }
       }
   }
}
 
// MARK: - 3. ПЛАВАЮЩИЙ ОСТРОВОК С ДИАГРАММОЙ
struct MusclePieChartIsland: View {
   var exercises: [ExerciseItem]
   @State private var animateChart = false
   
   var chartData: [(color: Color, percentage: Double)] {
       let total = max(1, exercises.count)
       var data: [(Color, Double)] = []
       for group in MuscleGroupColor.allCases {
           let count = exercises.filter { $0.group == group }.count
           let percentage = Double(count) / Double(total)
           data.append((group.color, percentage))
       }
       return data
   }
   
   var body: some View {
       VStack {
           Text("Задействованные мышцы")
               .font(.system(size: 16, weight: .bold, design: .rounded))
               .foregroundStyle(.white.opacity(0.8))
           
           ZStack {
               Circle().stroke(Color.white.opacity(0.05), lineWidth: 20).frame(width: 150, height: 150)
               
               if exercises.isEmpty {
                   Text("Пусто").font(.headline).foregroundStyle(.gray)
               } else {
                   ForEach(0..<4, id: \.self) { index in
                       if chartData[index].percentage > 0 {
                           Circle()
                               .trim(from: trimStart(for: index), to: trimEnd(for: index))
                               .stroke(chartData[index].color, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                               .frame(width: 150, height: 150)
                               .rotationEffect(.degrees(-90))
                               .shadow(color: chartData[index].color.opacity(0.6), radius: 10)
                               .scaleEffect(animateChart ? 1 : 0.8)
                               .opacity(animateChart ? 1 : 0)
                               .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(Double(index) * 0.1), value: animateChart)
                       }
                   }
               }
           }
           .padding(.vertical, 10)
       }
       .frame(maxWidth: .infinity)
       .padding(24)
       .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
       .overlay(RoundedRectangle(cornerRadius: 32).stroke(LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))
       .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
       .onChange(of: exercises) { _ in
           animateChart = false
           DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { animateChart = true }
       }
       .onAppear { animateChart = true }
   }
   
   func trimStart(for index: Int) -> Double {
       if index == 0 { return 0 }
       return (0..<index).reduce(0) { $0 + chartData[$1].percentage }
   }
   
   func trimEnd(for index: Int) -> Double {
       return trimStart(for: index) + chartData[index].percentage
   }
}
 
// MARK: - 4. ИНТЕРАКТИВНЫЙ МАКЕТ ЧЕЛОВЕКА
struct AnatomyRecoveryView: View {
   @Binding var isFrontView: Bool
   @Binding var selectedMuscle: String?
   
   @State private var pulseReady = false
   @State private var floatFigure = false
   
   let frontMuscles = ["Грудные", "Пресс", "Квадрицепсы", "Бицепсы"]
   let backMuscles = ["Широчайшие", "Поясница", "Бицепс бедра", "Трицепсы"]
   
   var body: some View {
       VStack {
           HStack {
               AnatomyToggleButton(title: "Спереди", isSelected: isFrontView) { isFrontView = true; selectedMuscle = nil }
               AnatomyToggleButton(title: "Сзади", isSelected: !isFrontView) { isFrontView = false; selectedMuscle = nil }
           }
           .padding(.horizontal, 40)
           
           ZStack {
               VStack {
                   HStack {
                       Spacer()
                       VStack(alignment: .trailing) {
                           Text("Готовность").font(.caption.bold()).foregroundStyle(.white.opacity(0.5))
                           Text("87%")
                               .font(.system(size: 28, weight: .black, design: .rounded))
                               .foregroundStyle(Color.neonGreen)
                               .shadow(color: Color.neonGreen.opacity(0.6), radius: pulseReady ? 15 : 5)
                               .scaleEffect(pulseReady ? 1.05 : 0.95)
                       }
                   }
                   Spacer()
               }.padding()
               
               Image(systemName: "figure.stand")
                   .resizable()
                   .scaledToFit()
                   .frame(height: 250)
                   .foregroundStyle(.white.opacity(0.1))
                   .shadow(color: .white.opacity(0.2), radius: 5)
                   .offset(y: floatFigure ? -5 : 5)
               
               let currentMuscles = isFrontView ? frontMuscles : backMuscles
               let highlightColor = isFrontView ? Color.neonBlue : Color.neonRed
               
               ForEach(0..<currentMuscles.count, id: \.self) { index in
                   let muscle = currentMuscles[index]
                   let isSelected = selectedMuscle == muscle
                   
                   Button {
                       let impact = UIImpactFeedbackGenerator(style: .rigid)
                       impact.impactOccurred()
                       withAnimation(.spring()) { selectedMuscle = isSelected ? nil : muscle }
                   } label: {
                       Text(muscle)
                           .font(.system(size: 11, weight: .heavy))
                           .padding(.horizontal, 10).padding(.vertical, 6)
                           .background(isSelected ? highlightColor : Color.white.opacity(0.1))
                           .foregroundStyle(.white)
                           .clipShape(Capsule())
                           .overlay(Capsule().stroke(isSelected ? .clear : .white.opacity(0.3), lineWidth: 1))
                           .shadow(color: isSelected ? highlightColor.opacity(0.8) : .clear, radius: 10)
                           .scaleEffect(isSelected ? 1.15 : 1.0)
                   }
                   .offset(x: index % 2 == 0 ? -65 : 65, y: CGFloat(-80 + (index * 40)))
                   .offset(y: floatFigure ? -5 : 5)
               }
           }
           .frame(height: 280)
           .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
           .overlay(RoundedRectangle(cornerRadius: 24).stroke(LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
           .onAppear {
               withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { pulseReady = true }
               withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) { floatFigure = true }
           }
       }
   }
}
 
struct AnatomyToggleButton: View {
   let title: String; let isSelected: Bool; let action: () -> Void
   var body: some View {
       Button(action: {
           let impact = UISelectionFeedbackGenerator(); impact.selectionChanged()
           withAnimation(.spring()) { action() }
       }) {
           Text(title).font(.system(size: 14, weight: .bold, design: .rounded))
               .frame(maxWidth: .infinity).padding(.vertical, 10)
               .background(isSelected ? Color.neonBlue.opacity(0.2) : Color.clear)
               .foregroundStyle(isSelected ? Color.neonBlue : .white.opacity(0.6))
               .clipShape(Capsule())
               .overlay(Capsule().stroke(isSelected ? Color.neonBlue : .white.opacity(0.2), lineWidth: 1))
               .shadow(color: isSelected ? Color.neonBlue.opacity(0.5) : .clear, radius: 5)
       }
   }
}
