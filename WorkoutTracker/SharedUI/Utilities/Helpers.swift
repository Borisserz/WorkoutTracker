internal import SwiftUI

struct InputValidator {

    static let maxWeight: Double = 1500.0  

    static let maxReps: Int = 100

    static let maxDistance: Double = 100_000.0  

    static let maxTime: Int = 86400  

    static let minWeight: Double = 0.0  
    static let minReps: Int = 0  
    static let minDistance: Double = 0.0
    static let minTime: Int = 0

    static func validateWeight(_ value: Double) -> (isValid: Bool, clampedValue: Double, errorMessage: String?) {
        if value < 0 {
            return (false, minWeight, String(localized: "Weight cannot be negative"))
        }
        if value > maxWeight {
            return (false, maxWeight, String(localized: "Weight cannot exceed \(Int(maxWeight)) kg"))
        }
        return (true, value, nil)
    }

    static func validateReps(_ value: Int) -> (isValid: Bool, clampedValue: Int, errorMessage: String?) {
        if value < 0 {
            return (false, minReps, String(localized: "Reps cannot be negative"))
        }
        if value > maxReps {
            return (false, maxReps, String(localized: "Reps cannot exceed \(maxReps)"))
        }
        return (true, value, nil)
    }

    static func validateDistance(_ value: Double) -> (isValid: Bool, clampedValue: Double, errorMessage: String?) {
        if value < minDistance {
            return (false, minDistance, String(localized: "Distance cannot be negative"))
        }
        if value > maxDistance {
            return (false, maxDistance, String(localized: "Distance cannot exceed \(Int(maxDistance)) m"))
        }
        return (true, value, nil)
    }

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

import os 

struct SVGParser: Sendable {

    private static let cache = OSAllocatedUnfairLock(initialState: [String: Path]())

    static func path(from string: String) -> Path {

        if let cachedPath = cache.withLock({ $0[string] }) {
            return cachedPath
        }

        let newPath = parseString(string)

        cache.withLock { state in
            state[string] = newPath
        }

        return newPath
    }

    private static func parseString(_ string: String) -> Path {
        var path = Path()
        let formatted = string
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
            case "M":
                guard let x = scanner.scanDouble(), let y = scanner.scanDouble() else { break }
                currentPoint = CGPoint(x: x, y: y)
                startPoint = currentPoint
                path.move(to: currentPoint)
                lastCommand = "L"
            case "m":
                guard let dx = scanner.scanDouble(), let dy = scanner.scanDouble() else { break }
                currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                startPoint = currentPoint
                path.move(to: currentPoint)
                lastCommand = "l"
            case "L":
                guard let x = scanner.scanDouble(), let y = scanner.scanDouble() else { break }
                currentPoint = CGPoint(x: x, y: y)
                path.addLine(to: currentPoint)
            case "l":
                guard let dx = scanner.scanDouble(), let dy = scanner.scanDouble() else { break }
                currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                path.addLine(to: currentPoint)
            case "H":
                guard let x = scanner.scanDouble() else { break }
                currentPoint = CGPoint(x: x, y: currentPoint.y)
                path.addLine(to: currentPoint)
            case "h":
                guard let dx = scanner.scanDouble() else { break }
                currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y)
                path.addLine(to: currentPoint)
            case "V":
                guard let y = scanner.scanDouble() else { break }
                currentPoint = CGPoint(x: currentPoint.x, y: y)
                path.addLine(to: currentPoint)
            case "v":
                guard let dy = scanner.scanDouble() else { break }
                currentPoint = CGPoint(x: currentPoint.x, y: currentPoint.y + dy)
                path.addLine(to: currentPoint)
            case "c":
                guard let dx1 = scanner.scanDouble(), let dy1 = scanner.scanDouble(),
                      let dx2 = scanner.scanDouble(), let dy2 = scanner.scanDouble(),
                      let dx = scanner.scanDouble(), let dy = scanner.scanDouble() else { break }
                path.addCurve(
                    to: CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy),
                    control1: CGPoint(x: currentPoint.x + dx1, y: currentPoint.y + dy1),
                    control2: CGPoint(x: currentPoint.x + dx2, y: currentPoint.y + dy2)
                )
                currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
            case "C":
                guard let x1 = scanner.scanDouble(), let y1 = scanner.scanDouble(),
                      let x2 = scanner.scanDouble(), let y2 = scanner.scanDouble(),
                      let x = scanner.scanDouble(), let y = scanner.scanDouble() else { break }
                path.addCurve(
                    to: CGPoint(x: x, y: y),
                    control1: CGPoint(x: x1, y: y1),
                    control2: CGPoint(x: x2, y: y2)
                )
                currentPoint = CGPoint(x: x, y: y)
            case "q":
                guard let dx1 = scanner.scanDouble(), let dy1 = scanner.scanDouble(),
                      let dx = scanner.scanDouble(), let dy = scanner.scanDouble() else { break }
                path.addQuadCurve(
                    to: CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy),
                    control: CGPoint(x: currentPoint.x + dx1, y: currentPoint.y + dy1)
                )
                currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
            case "Q":
                guard let x1 = scanner.scanDouble(), let y1 = scanner.scanDouble(),
                      let x = scanner.scanDouble(), let y = scanner.scanDouble() else { break }
                path.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x1, y: y1))
                currentPoint = CGPoint(x: x, y: y)
            case "a", "A":
                guard let _ = scanner.scanDouble(), let _ = scanner.scanDouble(),
                      let _ = scanner.scanDouble(), let _ = scanner.scanDouble(),
                      let _ = scanner.scanDouble(),
                      let dx = scanner.scanDouble(), let dy = scanner.scanDouble() else { break }
                if lastCommand == "a" {
                    currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                } else {
                    currentPoint = CGPoint(x: dx, y: dy)
                }
                path.addLine(to: currentPoint)
            case "z", "Z":
                path.closeSubpath()
                currentPoint = startPoint
                lastCommand = " "
            default:
                _ = scanner.scanDouble()
            }
        }

        return path
    }
}

struct MuscleDisplayHelper {
    private static let slugToDisplayName: [String: String] = [
        "chest": "Chest", "upper-back": "Upper Back", "lats": "Lats", "lower-back": "Lower Back",
        "trapezius": "Trapezius", "deltoids": "Shoulders", "biceps": "Biceps", "triceps": "Triceps",
        "forearm": "Forearms", "abs": "Abs", "obliques": "Obliques", "gluteal": "Glutes",
        "hamstring": "Hamstrings", "quadriceps": "Quads", "adductors": "Adductors",
        "abductors": "Abductors", "legs": "Legs", "calves": "Calves", "neck": "Neck",
        "tibialis": "Tibialis", "hands": "Hands", "ankles": "Ankles", "feet": "Feet"
    ]

    static func getDisplayName(for slug: String) -> String {
        return slugToDisplayName[slug] ?? slug.capitalized
    }
    static func getTargetMuscleNames(for exerciseName: String, muscleGroup: String) -> [String] {
        let muscleSlugs = MuscleMapping.getMuscles(for: exerciseName, group: muscleGroup)
        return muscleSlugs.compactMap { slugToDisplayName[$0] ?? $0.capitalized }
    }

    static func getTargetMusclesString(for exerciseName: String, muscleGroup: String) -> String {
        let names = getTargetMuscleNames(for: exerciseName, muscleGroup: muscleGroup)
        return names.isEmpty ? muscleGroup : names.joined(separator: ", ")
    }
}

struct EmptyStateView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let iconSize: CGFloat
    let iconColor: Color
    
    var actionTitle: LocalizedStringKey? = nil
    var action: (() -> Void)? = nil

    @State private var isBreathing = false

    init(icon: String, title: LocalizedStringKey, message: LocalizedStringKey, iconSize: CGFloat = 60, iconColor: Color? = nil, actionTitle: LocalizedStringKey? = nil, action: (() -> Void)? = nil) {
        self.icon = icon; self.title = title; self.message = message; self.iconSize = iconSize;
        self.iconColor = iconColor ?? .cyan
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: iconSize * 1.8, height: iconSize * 1.8)
                    .blur(radius: isBreathing ? 15 : 5)
                    .scaleEffect(isBreathing ? 1.1 : 0.9)
                
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .light))
                    .foregroundStyle(LinearGradient(colors: [iconColor, iconColor.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .offset(y: isBreathing ? -5 : 5)
            }
            .padding(.bottom, 8)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                Text(message)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .gray : .secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: {
                    HapticManager.shared.impact(.medium)
                    action()
                }) {
                    Text(actionTitle)
                        .font(.system(size: 16, weight: .bold))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1), lineWidth: 1))
                }
                .padding(.top, 12)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white))
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.primary.opacity(0.05), lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 20, y: 10)
        .padding(.horizontal, 20)
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
    }
}

struct UnavailableMetricView: View {
    @Environment(\.colorScheme) private var colorScheme
    let icon: String
    let text: LocalizedStringKey
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.6))
        .clipShape(Capsule())
    }
}
