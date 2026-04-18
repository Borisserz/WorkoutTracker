import SwiftUI

// MARK: - 6. ЧАТ С ИИ
struct AIChatBotView: View {
   @Environment(\.dismiss) var dismiss
   @State private var text = ""
   @State private var messages: [(text: String, isUser: Bool)] = [("Привет! Я твой ИИ-тренер. Чем могу помочь сегодня?", false)]
   
   var body: some View {
       NavigationStack {
           ZStack {
               Color.premiumBackground.ignoresSafeArea()
               VStack {
                   ScrollView {
                       VStack(spacing: 12) {
                           ForEach(0..<messages.count, id: \.self) { i in
                               let msg = messages[i]
                               HStack {
                                   if msg.isUser { Spacer() }
                                   Text(msg.text)
                                       .padding()
                                       .background(msg.isUser ? Color.neonBlue.opacity(0.8) : Color.white.opacity(0.1))
                                       .foregroundStyle(.white)
                                       .clipShape(RoundedRectangle(cornerRadius: 20))
                                       .shadow(color: msg.isUser ? Color.neonBlue.opacity(0.5) : .black.opacity(0.2), radius: 5)
                                       .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.2), lineWidth: msg.isUser ? 0 : 1))
                                   if !msg.isUser { Spacer() }
                               }.padding(.horizontal)
                           }
                       }.padding(.top)
                   }
                   HStack {
                       TextField("Напиши привет...", text: $text)
                           .padding(14)
                           .background(.ultraThinMaterial, in: Capsule())
                           .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
                           .foregroundStyle(.white)
                       
                       Button { sendMessage() } label: {
                           Image(systemName: "arrow.up.circle.fill").font(.system(size: 32))
                               .foregroundStyle(text.isEmpty ? .gray : Color.neonBlue)
                               .shadow(color: text.isEmpty ? .clear : Color.neonBlue.opacity(0.8), radius: 8)
                       }.disabled(text.isEmpty)
                   }.padding()
               }
           }
           .navigationTitle("ИИ Тренер")
           .navigationBarTitleDisplayMode(.inline)
           .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Закрыть") { dismiss() }.foregroundStyle(Color.neonBlue) } }
       }
   }
   
   func sendMessage() {
       let userText = text
       messages.append((userText, true))
       text = ""
       UIImpactFeedbackGenerator(style: .light).impactOccurred()
       DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
           messages.append((userText.lowercased().contains("привет") ? "Привет! Готов сегодня побить рекорды? 🔥" : "Пока я понимаю только слово «привет», но скоро я стану умнее! 😉", false))
           UINotificationFeedbackGenerator().notificationOccurred(.success)
       }
   }
}
