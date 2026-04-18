import SwiftUI

// MARK: - 5. ПОИСК УПРАЖНЕНИЙ
struct ExerciseSearchView: View {
   @Environment(\.dismiss) var dismiss
   @Binding var addedExercises: [ExerciseItem]
   @State private var searchText = ""
   
   let database = [
       ExerciseItem(name: "Жим штанги лёжа", group: .red),
       ExerciseItem(name: "Скручивания (Пресс)", group: .yellow),
       ExerciseItem(name: "Отжимания", group: .red),
       ExerciseItem(name: "Подтягивания", group: .blue),
       ExerciseItem(name: "Приседания со штангой", group: .green)
   ]
   
   var searchResults: [ExerciseItem] {
       if searchText.isEmpty { return database }
       return database.filter { $0.name.lowercased().contains(searchText.lowercased()) }
   }
   
   var body: some View {
       NavigationStack {
           ZStack {
               Color.premiumBackground.ignoresSafeArea()
               VStack {
                   TextField("Поиск упражнений...", text: $searchText)
                       .padding(12)
                       .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                       .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.2), lineWidth: 1))
                       .foregroundStyle(.white)
                       .padding()
                   
                   List(searchResults) { exercise in
                       Button {
                           let impact = UINotificationFeedbackGenerator()
                           impact.notificationOccurred(.success)
                           addedExercises.append(exercise)
                           dismiss()
                       } label: {
                           HStack {
                               Circle().fill(exercise.group.color).frame(width: 16, height: 16).shadow(color: exercise.group.color.opacity(0.8), radius: 5)
                               Text(exercise.name).foregroundStyle(.white).font(.headline)
                               Spacer()
                               Image(systemName: "plus.circle").foregroundStyle(Color.neonBlue)
                           }
                       }
                       .listRowBackground(Color.clear)
                   }.listStyle(.plain)
               }
           }
           .navigationTitle("Упражнения")
           .navigationBarTitleDisplayMode(.inline)
           .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Готово") { dismiss() }.foregroundStyle(Color.neonBlue) } }
       }
   }
}
