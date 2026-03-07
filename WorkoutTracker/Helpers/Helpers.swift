internal import SwiftUI

// MARK: - Input Validation Helper

struct InputValidator {
    // Maximum reasonable values
    static let maxWeight: Double = 500.0  // kg
    static let maxReps: Int = 1000
    static let maxDistance: Double = 1000.0  // km
    static let maxTime: Int = 86400  // 24 hours in seconds
    
    // Minimum values
    static let minWeight: Double = 0.0  // Minimum weight: 0 kg
    static let minReps: Int = 0  // Minimum reps: 0
    static let minDistance: Double = 0.0
    static let minTime: Int = 0
    
    /// Validates and clamps weight value (can be 0)
    static func validateWeight(_ value: Double) -> (isValid: Bool, clampedValue: Double, errorMessage: String?) {
        if value < 0 {
            return (false, minWeight, String(localized: "Weight cannot be negative"))
        }
        if value > maxWeight {
            return (false, maxWeight, String(localized: "Weight cannot exceed \(Int(maxWeight)) kg"))
        }
        return (true, value, nil)
    }
    
    /// Validates and clamps reps value (can be 0)
    static func validateReps(_ value: Int) -> (isValid: Bool, clampedValue: Int, errorMessage: String?) {
        if value < 0 {
            return (false, minReps, String(localized: "Reps cannot be negative"))
        }
        if value > maxReps {
            return (false, maxReps, String(localized: "Reps cannot exceed \(maxReps)"))
        }
        return (true, value, nil)
    }
    
    /// Validates and clamps distance value
    static func validateDistance(_ value: Double) -> (isValid: Bool, clampedValue: Double, errorMessage: String?) {
        if value < minDistance {
            return (false, minDistance, String(localized: "Distance cannot be negative"))
        }
        if value > maxDistance {
            return (false, maxDistance, String(localized: "Distance cannot exceed \(Int(maxDistance)) km"))
        }
        return (true, value, nil)
    }
    
    /// Validates and clamps time value (in seconds)
    static func validateTime(_ value: Int) -> (isValid: Bool, clampedValue: Int, errorMessage: String?) {
        if value < minTime {
            return (false, minTime, String(localized: "Time cannot be negative"))
        }
        if value > maxTime {
            return (false, maxTime, String(localized: "Time cannot exceed 24 hours"))
        }
        return (true, value, nil)
    }
}

struct SVGParser {
    
    // Кэш и блокировка для потокобезопасности
    private static let cacheLock = NSLock()
    private static var pathCache: [String: Path] = [:]
    
    static func path(from string: String) -> Path {
        // 1. Проверяем кэш. Если путь уже распарсен, мгновенно его возвращаем
        cacheLock.lock()
        if let cachedPath = pathCache[string] {
            cacheLock.unlock()
            return cachedPath
        }
        cacheLock.unlock()
        
        var path = Path()
        
        // Подготовка строки
        var formatted = string
            .replacingOccurrences(of: "([a-zA-Z])", with: " $1 ", options: .regularExpression)
            .replacingOccurrences(of: "-", with: " -")
            .replacingOccurrences(of: ",", with: " ")
        
        let scanner = Scanner(string: formatted)
        scanner.charactersToBeSkipped = .whitespacesAndNewlines
        
        var currentPoint = CGPoint.zero
        var startPoint = CGPoint.zero
        var lastCommand = " "
        
        while !scanner.isAtEnd {
            var command: NSString?
            if scanner.scanCharacters(from: .letters, into: &command) {
                lastCommand = (command as String?) ?? " "
            }
            
            switch lastCommand {
            case "M": // Move Absolute
                guard let x = scanner.scanDouble(), let y = scanner.scanDouble() else { break }
                currentPoint = CGPoint(x: x, y: y)
                startPoint = currentPoint
                path.move(to: currentPoint)
                
                // В SVG, если после M идут еще числа, они считаются как L
                lastCommand = "L"
                
            case "m": // Move Relative (ДОБАВЛЕНО)
                guard let dx = scanner.scanDouble(), let dy = scanner.scanDouble() else { break }
                currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                startPoint = currentPoint
                path.move(to: currentPoint)
                
                // В SVG, если после m идут еще числа, они считаются как l
                lastCommand = "l"
                
            case "L": // Line Absolute
                guard let x = scanner.scanDouble(), let y = scanner.scanDouble() else { break }
                currentPoint = CGPoint(x: x, y: y)
                path.addLine(to: currentPoint)
                
            case "l": // Line Relative
                guard let dx = scanner.scanDouble(), let dy = scanner.scanDouble() else { break }
                currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                path.addLine(to: currentPoint)
                
            case "H": // Horizontal Absolute
                guard let x = scanner.scanDouble() else { break }
                currentPoint = CGPoint(x: x, y: currentPoint.y)
                path.addLine(to: currentPoint)
                
            case "h": // Horizontal Relative
                guard let dx = scanner.scanDouble() else { break }
                currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y)
                path.addLine(to: currentPoint)
                
            case "V": // Vertical Absolute
                guard let y = scanner.scanDouble() else { break }
                currentPoint = CGPoint(x: currentPoint.x, y: y)
                path.addLine(to: currentPoint)
                
            case "v": // Vertical Relative
                guard let dy = scanner.scanDouble() else { break }
                currentPoint = CGPoint(x: currentPoint.x, y: currentPoint.y + dy)
                path.addLine(to: currentPoint)
                
            case "c": // Curve Relative
                guard let dx1 = scanner.scanDouble(), let dy1 = scanner.scanDouble(),
                      let dx2 = scanner.scanDouble(), let dy2 = scanner.scanDouble(),
                      let dx = scanner.scanDouble(), let dy = scanner.scanDouble() else { break }
                
                path.addCurve(
                    to: CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy),
                    control1: CGPoint(x: currentPoint.x + dx1, y: currentPoint.y + dy1),
                    control2: CGPoint(x: currentPoint.x + dx2, y: currentPoint.y + dy2)
                )
                currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                
            case "C": // Curve Absolute
                guard let x1 = scanner.scanDouble(), let y1 = scanner.scanDouble(),
                      let x2 = scanner.scanDouble(), let y2 = scanner.scanDouble(),
                      let x = scanner.scanDouble(), let y = scanner.scanDouble() else { break }
                
                path.addCurve(
                    to: CGPoint(x: x, y: y),
                    control1: CGPoint(x: x1, y: y1),
                    control2: CGPoint(x: x2, y: y2)
                )
                currentPoint = CGPoint(x: x, y: y)
                
            case "q": // Quadratic Relative
                guard let dx1 = scanner.scanDouble(), let dy1 = scanner.scanDouble(),
                      let dx = scanner.scanDouble(), let dy = scanner.scanDouble() else { break }
                path.addQuadCurve(
                    to: CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy),
                    control: CGPoint(x: currentPoint.x + dx1, y: currentPoint.y + dy1)
                )
                currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                
            case "Q": // Quadratic Absolute
                guard let x1 = scanner.scanDouble(), let y1 = scanner.scanDouble(),
                      let x = scanner.scanDouble(), let y = scanner.scanDouble() else { break }
                path.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x1, y: y1))
                currentPoint = CGPoint(x: x, y: y)
                
            case "a": // Arc Relative (упрощено до линии)
                guard let _ = scanner.scanDouble(), let _ = scanner.scanDouble(),
                      let _ = scanner.scanDouble(), let _ = scanner.scanDouble(),
                      let _ = scanner.scanDouble(),
                      let dx = scanner.scanDouble(), let dy = scanner.scanDouble() else { break }
                currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                path.addLine(to: currentPoint)
                
            case "A": // Arc Absolute (упрощено до линии)
                guard let _ = scanner.scanDouble(), let _ = scanner.scanDouble(),
                      let _ = scanner.scanDouble(), let _ = scanner.scanDouble(),
                      let _ = scanner.scanDouble(),
                      let x = scanner.scanDouble(), let y = scanner.scanDouble() else { break }
                currentPoint = CGPoint(x: x, y: y)
                path.addLine(to: currentPoint)
                
            case "z", "Z": // Close
                path.closeSubpath()
                currentPoint = startPoint
                // После Z команда сбрасывается, следующая должна быть M или m, если нет - парсинг прервется
                lastCommand = " "
                
            default:
                _ = scanner.scanDouble()
            }
        }
        
        // 2. Сохраняем распарсенный путь в кэш
        cacheLock.lock()
        pathCache[string] = path
        cacheLock.unlock()
        
        return path
    }
}

// MARK: - Empty State View Component

// MARK: - Muscle Display Helper

struct MuscleDisplayHelper {
    /// Маппинг слага в читаемое имя мышцы
    private static let slugToDisplayName: [String: String] = [
        "chest": "Chest",
        "upper-back": "Upper Back",
        "lats": "Lats",
        "lower-back": "Lower Back",
        "trapezius": "Trapezius",
        "deltoids": "Shoulders",
        "biceps": "Biceps",
        "triceps": "Triceps",
        "forearm": "Forearms",
        "abs": "Abs",
        "obliques": "Obliques",
        "gluteal": "Glutes",
        "hamstring": "Hamstrings",
        "quadriceps": "Quads",
        "adductors": "Adductors",
        "abductors": "Abductors",
        "legs": "Legs",
        "calves": "Calves",
        "neck": "Neck",
        "tibialis": "Tibialis",
        "hands": "Hands",
        "ankles": "Ankles",
        "feet": "Feet"
    ]
    
    /// Получить читаемые имена таргетных мускулов для упражнения
    static func getTargetMuscleNames(for exerciseName: String, muscleGroup: String) -> [String] {
        let muscleSlugs = MuscleMapping.getMuscles(for: exerciseName, group: muscleGroup)
        return muscleSlugs.compactMap { slugToDisplayName[$0] ?? $0.capitalized }
    }
    
    /// Получить строку с таргетными мускулами (через запятую)
    static func getTargetMusclesString(for exerciseName: String, muscleGroup: String) -> String {
        let names = getTargetMuscleNames(for: exerciseName, muscleGroup: muscleGroup)
        return names.isEmpty ? muscleGroup : names.joined(separator: ", ")
    }
}

// MARK: - Empty State View Component

struct EmptyStateView: View {
    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let iconSize: CGFloat
    let iconColor: Color
    
    init(
        icon: String,
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        iconSize: CGFloat = 60,
        iconColor: Color = .gray.opacity(0.5)
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.iconSize = iconSize
        self.iconColor = iconColor
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: iconSize))
                .foregroundColor(iconColor)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
