internal import SwiftUI

struct SVGParser {
    static func path(from string: String) -> Path {
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
        return path
    }
}
