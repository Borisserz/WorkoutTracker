import SwiftUI

// MARK: - 8. ЭКРАН "ТРЕНИРОВКА"
struct WorkoutView: View {
   @State private var showStreakPopup = false
   @State private var streakDays = 3
   
   var body: some View {
       NavigationStack {
           ZStack {
               PremiumDarkBackground()
               
               ScrollView(showsIndicators: false) {
                   VStack(alignment: .leading, spacing: 32) {
                       HStack {
                           Text("Тренировка")
                               .font(.system(size: 34, weight: .heavy, design: .rounded))
                               .foregroundStyle(.white)
                           Spacer()
                           Button {
                               UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                               withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { showStreakPopup = true }
                           } label: {
                               HStack(spacing: 6) {
                                   Image(systemName: "flame.fill").foregroundStyle(Color.neonOrange)
                                   Text("\(streakDays) дня").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                               }
                               .padding(.horizontal, 12).padding(.vertical, 8)
                               .background(.ultraThinMaterial, in: Capsule())
                               .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                               .shadow(color: Color.neonOrange.opacity(0.4), radius: 10, x: 0, y: 4)
                           }.buttonStyle(.plain)
                       }.padding(.top, 20)
                       
                       VStack(spacing: 20) {
                           PremiumGlassButton(title: "Начать пустую тренировку", subtitle: "Свободный режим", icon: "play.circle.fill", colorTint: Color.neonBlue) { }
                           PremiumGlassButton(title: "Умный конструктор", subtitle: "Сгенерировано под вас", icon: "wand.and.stars", colorTint: Color.neonPurple) { }
                       }
                       
                       VStack(alignment: .leading, spacing: 16) {
                           Text("Программы").font(.title2.weight(.bold)).foregroundStyle(.white)
                           HStack(spacing: 16) {
                               PremiumGlassButton(title: "Новая\nпрограмма", icon: "plus.app.fill", colorTint: Color.neonGreen, isSmall: true) { }
                               PremiumGlassButton(title: "Исследовать\nбазу", icon: "safari.fill", colorTint: Color.neonOrange, isSmall: true) { }
                           }
                       }.padding(.top, 10)
                       
                       Spacer(minLength: 100)
                   }.padding(.horizontal, 20)
               }
               
               if showStreakPopup {
                   StreakMascotPopup(streakDays: streakDays, isShowing: $showStreakPopup)
                       .transition(.asymmetric(insertion: .scale(scale: 0.8).combined(with: .opacity), removal: .scale(scale: 0.9).combined(with: .opacity)))
                       .zIndex(100)
               }
           }
       }
   }
}

// MARK: - 9. МАСКОТ И ПУЗЫРЬ
struct StreakMascotPopup: View {
   var streakDays: Int
   @Binding var isShowing: Bool
   @State private var dragOffset: CGSize = .zero
   @State private var isGlowing: Bool = false
   @State private var isFloating: Bool = false
   
   var body: some View {
       ZStack {
           Color.black.opacity(0.6).background(.ultraThinMaterial).ignoresSafeArea().onTapGesture { withAnimation(.spring()) { isShowing = false } }
           VStack(spacing: 5) {
               FierySpeechBubble(text: "Так держать!\nТы в огне! 🔥")
                   .offset(y: 15).zIndex(1)
                   .rotation3DEffect(.degrees(isGlowing ? 10 : 0), axis: (x: -dragOffset.height, y: dragOffset.width, z: 0.0), perspective: 0.3)
                   .offset(y: isFloating ? -5 : 5)
               
               ZStack {
                   RoundedRectangle(cornerRadius: 30)
                       .fill(LinearGradient(colors: [Color.neonOrange, Color.neonRed], startPoint: .topLeading, endPoint: .bottomTrailing))
                       .frame(width: 300, height: 300)
                       .overlay(Text("Здесь Маскот").bold().foregroundStyle(.white))
                       .overlay(RoundedRectangle(cornerRadius: 30).stroke(.white.opacity(0.5), lineWidth: 2))
                   
                   ZStack {
                       RoundedRectangle(cornerRadius: 6).fill(LinearGradient(colors: [.red, .orange], startPoint: .top, endPoint: .bottom))
                           .frame(width: 100, height: 46).rotationEffect(.degrees(-3))
                           .shadow(color: .black.opacity(0.5), radius: 10)
                       Text("\(streakDays) ДНЯ").font(.system(size: 26, weight: .black, design: .rounded)).foregroundStyle(.white).rotationEffect(.degrees(-3))
                   }.offset(x: -85, y: -94)
               }
               .shadow(color: Color.neonOrange.opacity(isGlowing ? 1.0 : 0.6), radius: isGlowing ? 60 : 30, x: 0, y: isGlowing ? 0 : 15)
               .rotation3DEffect(.degrees(isGlowing ? 25 : (isFloating ? 3 : -3)), axis: isGlowing ? (x: -dragOffset.height, y: dragOffset.width, z: 0.0) : (x: 1, y: 0, z: 0), perspective: 0.3)
               .scaleEffect(isGlowing ? 1.05 : 1.0)
               .offset(y: isFloating ? -8 : 8)
               .gesture(
                   DragGesture(minimumDistance: 0)
                       .onChanged { value in withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.6)) { isGlowing = true; dragOffset = CGSize(width: (value.location.x - 160) / 4, height: (value.location.y - 160) / 4) } }
                       .onEnded { _ in withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { isGlowing = false; dragOffset = .zero } }
               )
           }.onAppear { withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { isFloating = true } }
       }
   }
}
 
struct FierySpeechBubble: View {
   var text: String
   var body: some View {
       VStack(spacing: 0) {
           Text(text).font(.system(size: 18, weight: .heavy, design: .rounded)).multilineTextAlignment(.center).foregroundStyle(.white).padding(.horizontal, 24).padding(.vertical, 16)
               .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(LinearGradient(colors: [Color.neonOrange, Color.neonRed], startPoint: .topLeading, endPoint: .bottomTrailing)))
               .shadow(color: Color.neonRed.opacity(0.8), radius: 20, x: 0, y: 10)
               .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.4), lineWidth: 1))
           Path { path in
               path.move(to: CGPoint(x: 0, y: 0)); path.addLine(to: CGPoint(x: 24, y: 0)); path.addLine(to: CGPoint(x: 12, y: 16)); path.closeSubpath()
           }.fill(Color.neonRed).frame(width: 24, height: 16).offset(x: 20)
       }
   }
}
