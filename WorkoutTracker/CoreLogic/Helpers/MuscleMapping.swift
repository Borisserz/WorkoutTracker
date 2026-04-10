// ============================================================
// FILE: WorkoutTracker/CoreLogic/Helpers/MuscleMapping.swift
// ============================================================

import Foundation

struct MuscleMapping {
    
    // MARK: - Constants
    private static let customMappingKey = "CustomExerciseMappings"
    
    private static var customMappingsFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("CustomExerciseMappings.json")
    }
    
    // Блокировка для потокобезопасного доступа к кэшу
    private static let cacheLock = NSLock()
    
    // Кэши в оперативной памяти для быстрого доступа
    private static var _cachedCustomMappings: [String: [String]]?
    private static var _jsonExerciseToMuscles: [String: [String]]?
    
    // Запасной вариант (Фолбэк), если упражнения вообще нигде нет
    static let groupToMuscles: [String: [String]] = [
        "Chest":     ["chest"],
        "Back":      ["upper-back", "lower-back", "trapezius"],
        "Legs":      ["quadriceps", "hamstring", "gluteal", "calves", "adductors"],
        "Shoulders": ["deltoids"],
        "Arms":      ["biceps", "triceps", "forearm"],
        "Core":      ["abs", "obliques"],
        "Cardio":    ["quadriceps", "hamstring", "calves", "cardio"]
    ]
    
    // MARK: - Logic
    
    /// Запускает асинхронную загрузку маппингов на старте приложения (без лагов)
    static func preload() {
        Task.detached(priority: .background) {
            _ = getCustomMappings()
            _ = getJSONMappings()
        }
    }
    
    // MARK: - JSON Mappings (НОВАЯ ДИНАМИЧЕСКАЯ ЛОГИКА)
    
    /// Читает exercises.json и автоматически создает карту мышц для тепловой карты
    private static func getJSONMappings() -> [String: [String]] {
        cacheLock.lock()
        if let cached = _jsonExerciseToMuscles {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()
        
        var mapping: [String: [String]] = [:]
        
        // Вспомогательная структура для быстрого парсинга нужных полей
        struct TempItem: Codable {
            let name: String
            let primaryMuscles: [String]?
            let secondaryMuscles: [String]?
        }
        
        if let url = Bundle.main.url(forResource: "exercises", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let items = try? JSONDecoder().decode([TempItem].self, from: data) {
            
            for item in items {
                var slugs = Set<String>()
                // Добавляем и основные, и второстепенные мышцы на тепловую карту
                item.primaryMuscles?.forEach { slugs.insert(mapToSlug($0)) }
                item.secondaryMuscles?.forEach { slugs.insert(mapToSlug($0)) }
                
                mapping[item.name.lowercased()] = Array(slugs)
            }
        }
        
        cacheLock.lock()
        _jsonExerciseToMuscles = mapping
        cacheLock.unlock()
        
        return mapping
    }
    
    /// Конвертирует названия мышц из JSON в технические "слаги", которые понимает SVG отрисовщик тела
    private static func mapToSlug(_ rawName: String) -> String {
        let lowercased = rawName.lowercased()
        switch lowercased {
        case "lower back", "lower-back": return "lower-back"
        case "middle back", "lats", "upper back", "traps", "trapezius": return "upper-back"
        case "forearms", "forearm": return "forearm"
        case "glutes", "gluteal": return "gluteal"
        case "hamstrings", "hamstring": return "hamstring"
        case "quadriceps", "quads": return "quadriceps"
        case "calves", "calf": return "calves"
        case "shoulders", "delts", "deltoids": return "deltoids"
        case "chest", "pectorals": return "chest"
        case "biceps": return "biceps"
        case "triceps": return "triceps"
        case "abdominals", "abs", "core": return "abs"
        case "obliques": return "obliques"
        case "adductors", "abductors": return "adductors"
        default: return lowercased.replacingOccurrences(of: " ", with: "-")
        }
    }
    
    // MARK: - Custom Mappings
    
    private static func getCustomMappings() -> [String: [String]] {
        cacheLock.lock()
        if let cached = _cachedCustomMappings {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()
        
        var loaded: [String: [String]] = [:]
        
        // Пытаемся прочитать из файла
        if let data = try? Data(contentsOf: customMappingsFileURL),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            loaded = decoded
        }
        // Фоллбэк (миграция): если файла нет, пробуем прочитать из UserDefaults
        else if let dict = UserDefaults.standard.dictionary(forKey: customMappingKey) as? [String: [String]] {
            loaded = dict
            
            // Сразу сохраняем в файл асинхронно
            Task.detached(priority: .background) {
                if let encoded = try? JSONEncoder().encode(dict) {
                    try? encoded.write(to: customMappingsFileURL)
                }
            }
            UserDefaults.standard.removeObject(forKey: customMappingKey)
        }
        
        cacheLock.lock()
        _cachedCustomMappings = loaded
        cacheLock.unlock()
        
        return loaded
    }
    
    static func updateCustomMapping(name: String, muscles: [String]?) {
        var currentMap = getCustomMappings()
        if let muscles = muscles {
            currentMap[name] = muscles
        } else {
            currentMap.removeValue(forKey: name)
        }
        
        cacheLock.lock()
        _cachedCustomMappings = currentMap
        cacheLock.unlock()
        
        let mapToSave = currentMap
        Task.detached(priority: .background) {
            if let encoded = try? JSONEncoder().encode(mapToSave) {
                try? encoded.write(to: customMappingsFileURL)
            }
        }
    }
    
    // MARK: - Final Resolution Function
    
    /// Возвращает список задействованных мышц для конкретного упражнения.
    static func getMuscles(for exerciseName: String, group: String) -> [String] {
        let nameKey = exerciseName.lowercased()
        
        // 1. Сначала ищем в динамическом JSON-словаре (база на 800+ упражнений)
        let jsonMap = getJSONMappings()
        if let muscles = jsonMap[nameKey], !muscles.isEmpty {
            return muscles
        }
        
        // 2. Если не нашли, ищем в ПОЛЬЗОВАТЕЛЬСКИХ (созданных вручную)
        let customMap = getCustomMappings()
        if let customMuscles = customMap[exerciseName] ?? customMap[nameKey], !customMuscles.isEmpty {
            return customMuscles
        }
        
        // 3. Если совсем ничего нет, возвращаем дефолт по группе
        return groupToMuscles[group] ?? []
    }
    
    static func isBackFacing(exerciseName: String) -> Bool {
        let name = exerciseName.lowercased()
        let backKeywords = [
            "deadlift", "row", "pull", "chin", "tricep",
            "glute", "hamstring", "calf", "calves", "back",
            "good morning", "shrug"
        ]
        return backKeywords.contains { name.contains($0) }
    }
}
