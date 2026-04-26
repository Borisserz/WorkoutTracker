import Foundation
internal import SwiftUI
import FirebaseFirestore
import Observation

@Observable
@MainActor
final class FirestoreProgramService {
    static let shared = FirestoreProgramService()
    
    // MARK: - ВОТ ЭТИ ПЕРЕМЕННЫЕ ИСКАЛ XCODE
    var legendaryRoutines: [LegendaryRoutine] = []
    var explorePrograms: [WorkoutProgramDefinition] = []
    
    var isLoading = false
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Функция скачивания данных из Firebase для отображения в UI
    func fetchAllPrograms() async {
        isLoading = true
        
        do {
            // 1. Качаем легендарные тренировки
            let legendarySnapshot = try await db.collection("legendary_routines").getDocuments()
            var fetchedLegendary: [LegendaryRoutine] = []
            
            for doc in legendarySnapshot.documents {
                // Преобразуем документ Firestore в нашу сетевую модель
                if let fbRoutine = try? doc.data(as: FBLegendaryRoutine.self) {
                    // Преобразуем сетевую модель в UI-модель (восстанавливаем цвета из HEX)
                    let routine = LegendaryRoutine(
                        title: fbRoutine.title,
                        eraTitle: fbRoutine.eraTitle,
                        shortVibe: fbRoutine.shortVibe,
                        loreDescription: fbRoutine.loreDescription,
                        gradientColors: fbRoutine.hexColors.compactMap { Color(hex: $0) },
                        difficulty: ProgramLevel(rawValue: fbRoutine.difficulty) ?? .intermediate,
                        estimatedMinutes: fbRoutine.estimatedMinutes,
                        benefits: fbRoutine.benefits,
                        exercises: fbRoutine.exercises
                    )
                    fetchedLegendary.append(routine)
                }
            }
            
            // 2. Качаем обычные программы (Explore)
            let programsSnapshot = try await db.collection("explore_programs").getDocuments()
            var fetchedPrograms: [WorkoutProgramDefinition] = []
            
            for doc in programsSnapshot.documents {
                if let fbProg = try? doc.data(as: FBWorkoutProgram.self) {
                    let prog = WorkoutProgramDefinition(
                        title: fbProg.title,
                        description: fbProg.descriptionText,
                        level: ProgramLevel(rawValue: fbProg.level) ?? .intermediate,
                        goal: ProgramGoal(rawValue: fbProg.goal) ?? .buildMuscle,
                        equipment: ProgramEquipment(rawValue: fbProg.equipment) ?? .fullGym,
                        gradientColors: fbProg.hexColors.compactMap { Color(hex: $0) },
                        isSingleRoutine: fbProg.isSingleRoutine,
                        routines: fbProg.routines
                    )
                    fetchedPrograms.append(prog)
                }
            }
            
            // Сохраняем скачанное в свойства класса
            self.legendaryRoutines = fetchedLegendary
            self.explorePrograms = fetchedPrograms
            print("☁️✅ Программы успешно загружены из Firestore!")
            
        } catch {
            print("☁️❌ Ошибка загрузки из Firestore: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    func uploadSharedPreset(_ presetDTO: WorkoutPresetDTO) async throws -> String {
          let collection = db.collection("shared_workouts")
          let document = collection.document()
         
          guard let jsonData = try? JSONEncoder().encode(presetDTO),
                let jsonDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
              throw URLError(.cannotDecodeRawData)
          }
          
        
          try await document.setData(jsonDict)
          return document.documentID
      }
      
      func downloadSharedPreset(id: String) async throws -> WorkoutPresetDTO {
          let document = try await db.collection("shared_workouts").document(id).getDocument()
          
          guard let data = document.data(),
                let jsonData = try? JSONSerialization.data(withJSONObject: data),
                let presetDTO = try? JSONDecoder().decode(WorkoutPresetDTO.self, from: jsonData) else {
              throw URLError(.cannotParseResponse)
          }
          
          return presetDTO
      }
}
