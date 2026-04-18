import SwiftUI
 
// MARK: - 0. ТОЧКА ВХОДА
@main
struct FitnessTrackerApp: App {
   var body: some Scene {
       WindowGroup {
           WorkoutTrackerUI()
               .preferredColorScheme(.dark) // Принудительная дорогая темная тема
       }
   }
}
