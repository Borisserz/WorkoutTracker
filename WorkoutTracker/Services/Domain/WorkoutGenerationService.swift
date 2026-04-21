

import Foundation

struct WorkoutGenerationService: Sendable {

    private static func mapRecoveryNameToCatalogKey(_ name: String) -> String? {
        switch name.lowercased() {
        case "chest":
            return "Chest"
        case "back", "lower-back", "upper-back", "lats", "trapezius", "traps":
            return "Back"
        case "shoulders", "deltoids":
            return "Shoulders"
        case "arms", "biceps", "triceps", "forearm", "forearms":
            return "Arms"
        case "core", "abs", "obliques":
            return "Core"
        case "legs", "gluteal", "glutes", "hamstring", "hamstrings", "quadriceps", "quads", "calves", "tibialis", "adductors", "abductors":
            return "Legs"
        default:
            return nil 
        }
    }

    static func generateProactiveProposal(
           recoveryStatus: [MuscleRecoveryStatus],
           catalog: [String: [String]]
       ) -> ProactiveWorkoutProposal? {

           let getRec = { (slug: String) -> Int in
               recoveryStatus.first(where: { $0.muscleGroup == slug })?.recoveryPercentage ?? 100
           }

           let chestRec = getRec("chest")
           let triRec = getRec("triceps")
           let backRec = getRec("upper-back")
           let biRec = getRec("biceps")
           let quadRec = getRec("quadriceps")
           let hamRec = getRec("hamstring")

           var message = ""
           var exercises: [GeneratedExerciseDTO] = []
           var workoutTitle = ""

           if chestRec >= 90 && triRec < 60 {
               message = "Your Chest is \(chestRec)% recovered, but your Triceps are still at \(triRec)%. I built a custom Chest-isolation workout (45 mins) prioritizing cables over presses to save your joints."
               workoutTitle = "Chest Isolation (AI)"

               let pool = catalog["Chest"] ?? ["Dumbbell Flyes", "Cable Crossover", "Pec Deck"]
               let safePool = pool.filter { !$0.lowercased().contains("press") && !$0.lowercased().contains("push") }
               let finalExs = safePool.isEmpty ? pool : safePool

               for name in finalExs.shuffled().prefix(3) {
                   exercises.append(GeneratedExerciseDTO(name: name, muscleGroup: "Chest", type: "Strength", sets: 3, reps: 12, recommendedWeightKg: nil, restSeconds: 60))
               }

           } else if backRec >= 90 && biRec < 60 {
               message = "Your Back is \(backRec)% fresh, but your Biceps are fatigued (\(biRec)%). I've generated a straight-arm Back session to hit the lats without engaging the biceps."
               workoutTitle = "Back Isolation (AI)"

               let pool = catalog["Back"] ?? ["Lat Pulldown", "Straight Arm Pulldown"]
               for name in pool.shuffled().prefix(3) {
                   exercises.append(GeneratedExerciseDTO(name: name, muscleGroup: "Back", type: "Strength", sets: 3, reps: 12, recommendedWeightKg: nil, restSeconds: 60))
               }

           } else if quadRec >= 90 && hamRec >= 90 {
               message = "Legs are fully recovered (\(quadRec)%). Time to build some serious wheels. I've prepared a heavy lower body session. Grab your belt!"
               workoutTitle = "Heavy Legs (AI)"

               let pool = catalog["Legs"] ?? ["Squat", "Leg Press", "Lunges"]
               for name in pool.shuffled().prefix(3) {
                   exercises.append(GeneratedExerciseDTO(name: name, muscleGroup: "Legs", type: "Strength", sets: 4, reps: 8, recommendedWeightKg: nil, restSeconds: 120))
               }

           } else if chestRec < 50 && backRec < 50 && quadRec < 50 {
               message = "Your whole body is exhausted right now. I highly recommend taking a rest day, but if you must, here is a light Active Recovery & Stretching session."
               workoutTitle = "Active Recovery (AI)"

               exercises.append(GeneratedExerciseDTO(name: "Stretching", muscleGroup: "Cardio", type: "Duration", sets: 1, reps: 0, recommendedWeightKg: nil, restSeconds: 0))
               exercises.append(GeneratedExerciseDTO(name: "Walking", muscleGroup: "Cardio", type: "Duration", sets: 1, reps: 0, recommendedWeightKg: nil, restSeconds: 0))
           } else {

               return nil
           }

           let workoutDTO = GeneratedWorkoutDTO(title: workoutTitle, aiMessage: message, exercises: exercises)
           return ProactiveWorkoutProposal(message: message, workout: workoutDTO)
       }
}

enum WorkoutGenerationError: LocalizedError {
    case tooTired
    case noExercisesFound

    var errorDescription: String? {
        switch self {
        case .tooTired:
            return String(localized: "You don't have enough fully recovered muscles. Take a rest day or do light cardio!")
        case .noExercisesFound:
            return String(localized: "Could not find suitable exercises in the catalog.")
        }
    }
}
