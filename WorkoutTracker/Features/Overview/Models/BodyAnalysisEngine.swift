import Foundation
import SwiftData

struct MuscleReadinessItem: Identifiable, Sendable {
    var id: String { name }
    let name: String
    let percentage: Int
    let hoursRemaining: Int
}

/// Personalized coach advice for the next training session based on previous muscle strain.
struct NextWorkoutAdvice: Sendable {
    let recentStrainSummary: String
    let recommendedSplitTitle: String
    let physiologicalRationale: String
    let actionableTips: [String]
    let cautionNotes: String
    let recommendedExercises: [String]
}

/// Physiological analysis model representing deep readiness evaluation.
struct BodyAnalysisReport: Sendable {
    let overallReadiness: Int
    let cnsStatusTitle: String
    let executiveAssessment: String
    let recommendedTargetTitle: String
    let recommendedRestrictions: String
    let primeMuscles: [MuscleReadinessItem]
    let recoveringMuscles: [MuscleReadinessItem]
    let nextWorkoutAdvice: NextWorkoutAdvice
    let date: Date
}

enum BodyAnalysisEngine {
    
    /// Generates a comprehensive, sports-science evaluation without emojis or superficial text.
    static func generateReport(
        cnsScore: Double,
        recoveryDict: [String: Int],
        recentWorkouts: [Workout],
        fullRecoveryHours: Double = 48.0
    ) -> BodyAnalysisReport {
        let avgReadiness = recoveryDict.isEmpty ? 100 : (recoveryDict.values.reduce(0, +) / recoveryDict.count)
        
        // Group muscles into prime (>= 80%) and recovering (< 80%)
        var prime: [MuscleReadinessItem] = []
        var recovering: [MuscleReadinessItem] = []
        
        let displayOrder = [
            "chest", "upper-back", "deltoids", "biceps", "triceps", 
            "quadriceps", "hamstring", "gluteal", "lower-back", "abs", "calves"
        ]
        
        for slug in displayOrder {
            let pct = recoveryDict[slug] ?? 100
            let name = MuscleDisplayHelper.getDisplayName(for: slug)
            let remainingHours = max(0, Int(Double(100 - pct) / 100.0 * fullRecoveryHours))
            let item = MuscleReadinessItem(name: name, percentage: pct, hoursRemaining: remainingHours)
            
            if pct >= 80 {
                prime.append(item)
            } else {
                recovering.append(item)
            }
        }
        
        let chestPct = recoveryDict["chest"] ?? 100
        let backPct = recoveryDict["upper-back"] ?? 100
        let quadsPct = recoveryDict["quadriceps"] ?? 100
        let hamsPct = recoveryDict["hamstring"] ?? 100
        let lowBackPct = recoveryDict["lower-back"] ?? 100
        let tricepsPct = recoveryDict["triceps"] ?? 100
        let bicepsPct = recoveryDict["biceps"] ?? 100

        // Determine Next Workout Advice based on recent muscle strain
        let advice: NextWorkoutAdvice
        if recentWorkouts.isEmpty {
            advice = NextWorkoutAdvice(
                recentStrainSummary: "Накопленное утомление отсутствует. Все мышечные группы и центральная нервная система полностью восстановлены (100%).",
                recommendedSplitTitle: "Совет на следующую сессию: Прогрессивная силовая тренировка",
                physiologicalRationale: "Мышечные волокна и синапсы находятся в фазе максимальной готовности. Рекомендуется базовый силовой тренинг.",
                actionableTips: [
                    "Идеальный момент для плавного увеличения рабочих весов",
                    "Выполните 3–4 рабочих подхода в базовых многосуставных движениях",
                    "Интенсивность: RPE 8.0–8.5 с контролем амплитуды"
                ],
                cautionNotes: "Уделите 7–10 минут качественной суставной разминке перед первыми рабочими подходами.",
                recommendedExercises: ["Приседания со штангой", "Жим лёжа", "Подтягивания", "Жим стоя"]
            )
        } else if avgReadiness < 60 || cnsScore < 70 {
            advice = NextWorkoutAdvice(
                recentStrainSummary: "Обнаружено выраженное системное утомление мышц и ЦНС (средняя готовность \(avgReadiness)%).",
                recommendedSplitTitle: "Совет на следующую сессию: Активное восстановление или Делоад",
                physiologicalRationale: "Тканям требуется время на регенерацию гликогена и стабилизацию вегетативного тонуса.",
                actionableTips: [
                    "Замените тяжёлые силовые подходы на лёгкую кардио-сессию (пульс 110–125 уд/мин)",
                    "Выполните миофасциальный релиз (МФР) и стретчинг основных групп",
                    "Интенсивность: RPE не выше 5.0"
                ],
                cautionNotes: "Категорически исключите работу до отказа и форсированные повторения.",
                recommendedExercises: ["Ходьба с наклоном", "МФР на массажном валике", "Мобильность суставов", "Растяжка грудных мышц"]
            )
        } else if chestPct < 75 || tricepsPct < 75 {
            // Push was strained recently -> recommend Pull
            advice = NextWorkoutAdvice(
                recentStrainSummary: "В недавней сессии активно нагружены: Грудные мышцы и Трицепс (восстановление ~\(chestPct)%). Мышечные волокна находятся в фазе активной регенерации.",
                recommendedSplitTitle: "Совет на следующую сессию: Тяговый сплит (Спина и Бицепс)",
                physiologicalRationale: "Широчайшие мышцы и сгибатели плеча восстановились на \(backPct)% и обладают максимальной сократительной способностью.",
                actionableTips: [
                    "Сделайте акцент на тягу к поясу и подтягивания разным хватом",
                    "Целевой объём: 12–15 качественных рабочих подходов на спину и бицепс",
                    "Интенсивность: RPE 7.5–8.0 без закисления в первых сетах"
                ],
                cautionNotes: "Исключите жимовые движения под углом и глубокие отжимания ещё ~24 ч для защиты плечевых суставов.",
                recommendedExercises: ["Подтягивания", "Тяга штанги в наклоне", "Тяга верхнего блока", "Подъём гантелей на бицепс"]
            )
        } else if backPct < 75 || bicepsPct < 75 {
            // Pull was strained recently -> recommend Push or Legs
            advice = NextWorkoutAdvice(
                recentStrainSummary: "В недавней сессии задействованы: Спина, Широчайшие и Бицепс (восстановление ~\(backPct)%).",
                recommendedSplitTitle: "Совет на следующую сессию: Жимовой день (Грудь и Дельты)",
                physiologicalRationale: "Грудные мышцы и передние дельты полностью восполнили запасы гликогена (\(chestPct)%) и готовы к объёму.",
                actionableTips: [
                    "Приоритет: базовый жим лёжа и жим гантелей под углом",
                    "Сохраняйте нейтральное положение лопаток и контроль темпа",
                    "Интенсивность: RPE 7.5–8.0 с акцентом на растяжение грудных волокон"
                ],
                cautionNotes: "Избегайте становой тяги и тяги в наклоне, чтобы дать длинным мышцам спины восстановиться.",
                recommendedExercises: ["Жим штанги лёжа", "Жим гантелей сидя", "Разведения в стороны", "Французский жим"]
            )
        } else if quadsPct < 75 || hamsPct < 75 {
            // Legs strained -> recommend Upper
            advice = NextWorkoutAdvice(
                recentStrainSummary: "В недавней сессии нагружены: Квадрицепсы и Бицепс бедра (восстановление ~\(quadsPct)%).",
                recommendedSplitTitle: "Совет на следующую сессию: Верхняя часть тела (Upper Body)",
                physiologicalRationale: "Плечевой пояс, грудь и мышцы спины полностью отдохнули и готовы принять основной объём нагрузки.",
                actionableTips: [
                    "Сбалансируйте жимовые и тяговые упражнения в равной пропорции",
                    "Используйте суперсеты для экономии времени и плотности тренировки",
                    "Интенсивность: RPE 7.0–8.0"
                ],
                cautionNotes: "Полностью исключите осевую нагрузку на ноги: откажитесь от приседаний и выпадов.",
                recommendedExercises: ["Жим лёжа", "Тяга гантели к поясу", "Армейский жим стоя", "Молотковые сгибания"]
            )
        } else {
            // Balanced
            advice = NextWorkoutAdvice(
                recentStrainSummary: "Все основные мышечные группы восстановились выше 85%. Мышечная ткань адаптировалась к предыдущим тренировкам.",
                recommendedSplitTitle: "Совет на следующую сессию: Целевая силовая нагрузка",
                physiologicalRationale: "Скелетная мускулатура и вегетативная нервная система готовы к интенсивной работе без риска перегрузки.",
                actionableTips: [
                    "Выберите целевой сплит в зависимости от ваших недельных приоритетов",
                    "Сфокусируйтесь на технике в диапазоне 6–10 повторений",
                    "Интенсивность: RPE 8.0"
                ],
                cautionNotes: "Соблюдайте питьевой режим и паузы между подходами не менее 90–120 секунд.",
                recommendedExercises: ["Жим штанги лёжа", "Подтягивания с весом", "Приседания", "Жим над головой"]
            )
        }

        // Fallback if no workouts logged yet
        if recentWorkouts.isEmpty {
            return BodyAnalysisReport(
                overallReadiness: 100,
                cnsStatusTitle: "Baseline Homeostasis",
                executiveAssessment: "Muscular tissue is fully rested with zero residual neuromuscular fatigue. All kinetic chains are primed for maximum volume and progressive overload.",
                recommendedTargetTitle: "Full Body Foundation or Upper Split",
                recommendedRestrictions: "None. Systemic capacity is at peak readiness.",
                primeMuscles: prime,
                recoveringMuscles: [],
                nextWorkoutAdvice: advice,
                date: Date()
            )
        }
        
        // Executive assessment synthesis
        let cnsNarrative: String
        if cnsScore >= 85 {
            cnsNarrative = "Autonomic nervous system shows high vagal tone and optimal central recovery."
        } else if cnsScore >= 70 {
            cnsNarrative = "Central nervous system indicates moderate cumulative strain from recent training bouts."
        } else {
            cnsNarrative = "Elevated sympathetic activation and accumulated neural fatigue detected."
        }
        
        let muscularNarrative: String
        if lowBackPct < 70 || hamsPct < 70 {
            muscularNarrative = "The posterior chain is actively repairing micro-trauma from prior pulling volume. Meanwhile, the anterior chain shows high glycogen replenishment."
        } else if chestPct < 70 {
            muscularNarrative = "Pectoral and anterior deltoid fibers are undergoing active supercompensation. Back and lower-body structures are fully recovered."
        } else {
            muscularNarrative = "Primary stabilizers and major muscle groups maintain high cellular recovery across all kinetic planes."
        }
        
        let assessment = "\(cnsNarrative) \(muscularNarrative)"
        
        // Determine recommended focus
        let targetTitle: String
        let restrictions: String
        
        if chestPct >= 85 && (recoveryDict["triceps"] ?? 100) >= 80 {
            targetTitle = "Push Protocol (Chest, Deltoids, Triceps)"
            if lowBackPct < 75 {
                restrictions = "Avoid direct axial loading or unsupported spinal bending for 18h."
            } else {
                restrictions = "Standard volume tolerated. Focus on controlled eccentric tempo."
            }
        } else if backPct >= 85 && (recoveryDict["biceps"] ?? 100) >= 80 {
            targetTitle = "Pull Protocol (Lats, Upper Back, Biceps)"
            restrictions = "Maintain neutral lumbar position; avoid compounding lower-back fatigue."
        } else if quadsPct >= 85 {
            targetTitle = "Lower Body Hypertrophy (Quad-Dominant)"
            restrictions = "Prioritize machine stability (Leg Press, Hack Squat) to spare systemic energy."
        } else {
            targetTitle = "Active Recovery & Core Stabilization"
            restrictions = "Limit intensity to RPE 6; focus on tissue mobility and hydration replenishment."
        }
        
        let cnsTitle: String
        if cnsScore >= 85 {
            cnsTitle = "Optimal Autonomic Balance"
        } else if cnsScore >= 70 {
            cnsTitle = "Moderate Neural Recovery"
        } else {
            cnsTitle = "High Fatigue State"
        }
        
        return BodyAnalysisReport(
            overallReadiness: avgReadiness,
            cnsStatusTitle: cnsTitle,
            executiveAssessment: assessment,
            recommendedTargetTitle: targetTitle,
            recommendedRestrictions: restrictions,
            primeMuscles: prime,
            recoveringMuscles: recovering,
            nextWorkoutAdvice: advice,
            date: Date()
        )
    }
}
