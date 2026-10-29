internal import SwiftUI
internal import UniformTypeIdentifiers

struct SharedImageWrapper: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - Receipt Zig-Zag Perforation Shape
struct ReceiptZigZagShape: Shape {
    var toothWidth: CGFloat = 10
    var toothHeight: CGFloat = 5

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let topTeeth = max(1, Int(rect.width / toothWidth))
        let actualToothWidth = rect.width / CGFloat(topTeeth)

        // Top-left start
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + toothHeight))

        // Top teeth
        for i in 0..<topTeeth {
            let startX = rect.minX + CGFloat(i) * actualToothWidth
            let midX = startX + actualToothWidth / 2
            let endX = startX + actualToothWidth
            path.addLine(to: CGPoint(x: midX, y: rect.minY))
            path.addLine(to: CGPoint(x: endX, y: rect.minY + toothHeight))
        }

        // Right side
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - toothHeight))

        // Bottom teeth (reversed)
        for i in (0..<topTeeth).reversed() {
            let startX = rect.minX + CGFloat(i) * actualToothWidth
            let midX = startX + actualToothWidth / 2
            let endX = startX + actualToothWidth
            path.addLine(to: CGPoint(x: midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: startX, y: rect.maxY - toothHeight))
        }

        // Left side back to start
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + toothHeight))
        path.closeSubpath()
        return path
    }
}

// MARK: - Receipt Barcode Graphic
struct ReceiptBarcodeView: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<38, id: \.self) { i in
                let width: CGFloat = (i % 7 == 0 || i % 5 == 0) ? 3.5 : ((i % 3 == 0) ? 2 : 1)
                Rectangle()
                    .fill(PastelTheme.pastelOat.opacity(0.85))
                    .frame(width: width, height: (i % 8 == 0) ? 32 : 24)
            }
        }
    }
}

// MARK: - Milestone Share Card (Trophy / Level-Up)
struct MilestoneShareCard: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let descriptionText: LocalizedStringKey?
    let icon: String
    let colors: [Color]

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1a1a1a"), Color(hex: "000000")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(colors.first?.opacity(0.2) ?? themeManager.current.primaryAccent.opacity(0.2))
                .frame(width: 400)
                .offset(x: -200, y: -300)

            Circle()
                .fill(colors.last?.opacity(0.2) ?? Color.purple.opacity(0.2))
                .frame(width: 300)
                .offset(x: 200, y: 300)

            VStack(spacing: 30) {
                HStack {
                    Image(systemName: "star.fill")
                        .font(.title)
                        .foregroundColor(.yellow)
                    Text(title)
                        .font(.headline)
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 80)

                Spacer()

                ZStack {
                    Circle()
                        .strokeBorder(
                            AngularGradient(gradient: Gradient(colors: colors), center: .center),
                            lineWidth: 20
                        )
                        .frame(width: 350, height: 350)
                        .shadow(color: colors.first?.opacity(0.5) ?? .clear, radius: 20)

                    Image(systemName: icon)
                        .font(.system(size: 140))
                        .foregroundStyle(
                            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 5)
                }

                Text(subtitle)
                    .font(.system(size: 60, weight: .heavy, design: .rounded))
                    .foregroundColor(PastelTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 20)

                if let desc = descriptionText {
                    Text(desc)
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 50)
                        .padding(.top, 10)
                }

                Spacer()

                HStack {
                    Image(systemName: "applewatch")
                    Text(LocalizedStringKey("Tracked with WorkoutTracker"))
                }
                .font(.title)
                .foregroundColor(themeManager.current.secondaryAccent.opacity(0.5))
                .padding(.bottom, 80)
            }
        }
        .frame(width: 1080, height: 1080)
    }
}

// MARK: - Viral 9:16 Instagram Stories Athletic Receipt
struct WorkoutShareCard: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(UnitsManager.self) private var unitsManager

    let workout: Workout

    private var totalVolume: Int {
        Int(workout.totalStrengthVolume)
    }

    private var totalSetsCount: Int {
        workout.exercises.reduce(0) { $0 + $1.sortedSets.filter { $0.isCompleted }.count }
    }

    private var topMuscles: [String] {
        var counts: [String: Int] = [:]
        for ex in workout.exercises {
            let group = ex.isSuperset ? (ex.subExercises.first?.muscleGroup ?? "Mixed") : ex.muscleGroup
            counts[group, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
    }

    private var emotionalComparison: (title: String, subtitle: String, emoji: String) {
        let kg = workout.totalStrengthVolume
        if kg >= 14000 {
            let count = String(format: "%.1f", kg / 6000.0)
            return ("\(count) Африканских слона", "ТЯЖЕЛОВЕСНЫЙ ЗВЕРЬ", "🐘")
        } else if kg >= 8000 {
            let count = String(format: "%.1f", kg / 1850.0)
            return ("\(count) Tesla Model 3", "ЭЛЕКТРИЧЕСКАЯ МОЩЬ", "⚡️")
        } else if kg >= 4000 {
            let count = String(format: "%.1f", kg / 1400.0)
            return ("\(count) Ferrari F40", "СВЕРХСКОРОСТНОЙ ТОННАЖ", "🏎️")
        } else if kg >= 2000 {
            let count = String(format: "%.1f", kg / 800.0)
            return ("\(count) Белых медведя", "НЕУКРОТИМАЯ СИЛА", "🐻")
        } else if kg >= 800 {
            let count = String(format: "%.1f", kg / 300.0)
            return ("\(count) Рояля Steinway", "МОНУМЕНТАЛЬНЫЙ ОБЪЕМ", "🎹")
        } else if kg > 0 {
            let count = max(1, Int(kg / 50.0))
            return ("\(count) Мешков цемента", "КАЖДЫЙ ПОВТОР В ЦЕЛЬ", "🏋️")
        } else {
            return ("Готов к свершениям", "ПЕРВЫЙ СЕТ ВПЕРЕДИ", "🔥")
        }
    }

    private var completedExercises: [Exercise] {
        workout.exercises.filter { ex in
            ex.sortedSets.contains { $0.isCompleted }
        }
    }

    var body: some View {
        ZStack {
            // Background Canvas (OLED Cashmere Charcoal)
            PastelTheme.canvas.ignoresSafeArea()

            // Subtle Ambient Halos
            Circle()
                .fill(PastelTheme.pastelEmerald.opacity(0.12))
                .frame(width: 320)
                .blur(radius: 90)
                .offset(x: -80, y: -160)

            Circle()
                .fill(PastelTheme.pastelOat.opacity(0.08))
                .frame(width: 280)
                .blur(radius: 80)
                .offset(x: 100, y: 220)

            // Physical Thermal Receipt Ticket
            VStack(spacing: 0) {
                receiptContent
            }
            .clipShape(ReceiptZigZagShape(toothWidth: 12, toothHeight: 6))
            .overlay(
                ReceiptZigZagShape(toothWidth: 12, toothHeight: 6)
                    .stroke(PastelTheme.cardBorderFocused, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.55), radius: 24, x: 0, y: 12)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        // Strict 9:16 Aspect Ratio (1080x1920 stories equivalent when rendered @ 3x)
        .frame(width: 400, height: 711)
        .background(PastelTheme.canvas)
    }

    // MARK: - Receipt Ticket Body
    private var receiptContent: some View {
        VStack(spacing: 12) {
            // Receipt Header & Metadata
            receiptHeaderSection

            dashedSeparator

            // Workout Title & Date
            workoutTitleSection

            // Big Volume Hero Block with Emotional Comparison
            volumeHeroSection

            // 4-Quadrant HUD Telemetry Grid
            telemetryGridSection

            // Itemized Exercise Summary
            if !completedExercises.isEmpty {
                dashedSeparator
                exercisesLineItemsSection
            }

            // Target Muscles Pills
            if !topMuscles.isEmpty {
                musclesPillsSection
            }

            dashedSeparator

            // Barcode & Certified Slip Footer
            receiptFooterSection
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .background(PastelTheme.cardSurface)
    }

    // MARK: - Subsections
    private var receiptHeaderSection: some View {
        VStack(spacing: 4) {
            HStack {
                Text("WORKOUTTRACKER /// CERTIFIED RECEIPT")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.5)
                    .foregroundColor(PastelTheme.pastelOat)
                Spacer()
                Text("SLIP #\(abs(workout.id.hashValue) % 9000 + 1000)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(PastelTheme.textTertiary)
            }

            HStack {
                Text(workout.date.formatted(date: .abbreviated, time: .shortened).uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(PastelTheme.textSecondary)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(PastelTheme.pastelEmerald)
                        .frame(width: 6, height: 6)
                    Text("VERIFIED RECORD")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundColor(PastelTheme.pastelEmerald)
                }
            }
        }
    }

    private var workoutTitleSection: some View {
        VStack(spacing: 4) {
            Text(workout.title.uppercased())
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(PastelTheme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private var volumeHeroSection: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(totalVolume)")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(PastelTheme.textPrimary)
                Text("КГ ТОННАЖА")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .tracking(1)
                    .foregroundColor(PastelTheme.pastelOat)
            }

            // Emotional Comparison Badge (Elephant, Tesla, Ferrari)
            HStack(spacing: 6) {
                Text(emotionalComparison.emoji)
                    .font(.system(size: 16))
                Text("≈ \(emotionalComparison.title.uppercased())")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(0.5)
                    .foregroundColor(PastelTheme.textOnOat)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(PastelTheme.pastelOat)
            .clipShape(Capsule())
            .shadow(color: PastelTheme.pastelOat.opacity(0.3), radius: 8, x: 0, y: 2)
        }
        .padding(.vertical, 4)
    }

    private var telemetryGridSection: some View {
        HStack(spacing: 8) {
            receiptMiniStat(
                label: "ВРЕМЯ",
                value: "\(max(1, workout.durationSeconds / 60))м",
                color: PastelTheme.pastelAmber
            )
            receiptMiniStat(
                label: "СЕТЫ",
                value: "\(totalSetsCount)",
                color: PastelTheme.pastelEmerald
            )
            receiptMiniStat(
                label: "УПРАЖН.",
                value: "\(workout.exercises.count)",
                color: PastelTheme.pastelSlate
            )
            receiptMiniStat(
                label: "RPE",
                value: "\(workout.effortPercentage)%",
                color: PastelTheme.pastelSage
            )
        }
    }

    private func receiptMiniStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .tracking(0.5)
                .foregroundColor(PastelTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(PastelTheme.cardSurfaceSubtle)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
    }

    private var exercisesLineItemsSection: some View {
        VStack(spacing: 6) {
            ForEach(Array(completedExercises.prefix(3).enumerated()), id: \.element.id) { idx, ex in
                let completedCount = ex.sortedSets.filter { $0.isCompleted }.count
                let maxWeight = ex.sortedSets.filter { $0.isCompleted }.compactMap { $0.weight }.max() ?? 0

                HStack {
                    Text(String(format: "%02d.", idx + 1))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(PastelTheme.textTertiary)

                    Text(ex.name)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(PastelTheme.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Text("\(completedCount) сетов • \(Int(maxWeight)) кг")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(PastelTheme.textSecondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var musclesPillsSection: some View {
        HStack(spacing: 6) {
            ForEach(topMuscles, id: \.self) { muscle in
                Text(muscle.uppercased())
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(0.5)
                    .foregroundColor(PastelTheme.pastelEmerald)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(PastelTheme.cardSurfaceSubtle)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1))
            }
        }
    }

    private var receiptFooterSection: some View {
        VStack(spacing: 8) {
            ReceiptBarcodeView()

            HStack {
                Text("AUTHENTIC ATHLETIC HUD SLIP")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(PastelTheme.textTertiary)
                Spacer()
                Text("WORKOUTTRACKER")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .tracking(1.5)
                    .foregroundColor(PastelTheme.pastelOat)
            }
        }
    }

    private var dashedSeparator: some View {
        LineDashed()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .foregroundColor(PastelTheme.cardBorderFocused)
            .frame(height: 1)
            .padding(.vertical, 2)
    }
}

// MARK: - Dashed Line Shape
struct LineDashed: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

// MARK: - Transferable Representation
struct ShareableImage: Transferable {
    let uiImage: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .jpeg) { item in
            if let data = item.uiImage.jpegData(compressionQuality: 0.9) {
                return data
            } else {
                return Data()
            }
        }
    }
}

#Preview {
    WorkoutShareCard(workout: Workout.examples[0])
        .environment(ThemeManager.shared)
        .environment(UnitsManager.shared)
}
