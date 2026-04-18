import SwiftUI

// MARK: - МОДЕЛИ ДАННЫХ
enum MuscleGroupColor: CaseIterable {
   case red, yellow, blue, green
   
   var color: Color {
       switch self {
       case .red: return Color.neonRed
       case .yellow: return Color.neonYellow
       case .blue: return Color.neonBlue
       case .green: return Color.neonGreen
       }
   }
}
 
struct ExerciseItem: Identifiable, Equatable {
   let id = UUID()
   let name: String
   let group: MuscleGroupColor
}
