

internal import SwiftUI
internal import UniformTypeIdentifiers

struct SharedImageWrapper: Identifiable {
    let id = UUID()
    let image: UIImage
}

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

struct WorkoutShareCard: View {
    @Environment(ThemeManager.self) private var themeManager

    let workout: Workout

    private var totalVolume: Int {
        Int(workout.totalStrengthVolume)
    }

    private var topMuscles: [String] {
        var counts: [String: Int] = [:]
        for ex in workout.exercises {
            let group = ex.isSuperset ? (ex.subExercises.first?.muscleGroup ?? "Mixed") : ex.muscleGroup
            counts[group, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
    }

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 20) {
                headerSection

                titleSection
                
                statsGridSection

                tagsSection

                Spacer()

                footerSection
            }
            .padding(.top, 40)
        }
        .frame(width: 440, height: 720)
        .background(Color.black)
    }

    private var backgroundLayer: some View {
        ZStack {
            PastelTheme.canvas.ignoresSafeArea()

            Circle()
                .fill(PastelTheme.pastelEmerald.opacity(0.08))
                .frame(width: 320)
                .blur(radius: 90)
                .offset(y: -100)

            Circle()
                .fill(PastelTheme.pastelOat.opacity(0.05))
                .frame(width: 280)
                .blur(radius: 80)
                .offset(y: 200)
        }
    }

    private var headerSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(PastelTheme.pastelEmerald)

            Text(LocalizedStringKey("WORKOUT COMPLETE"))
                .font(.system(size: 12, weight: .black, design: .rounded))
                .tracking(2)
                .foregroundColor(PastelTheme.textPrimary)
        }
        .padding(.horizontal, 16)
        .frame(height: 36)
        .background(PastelTheme.cardSurfaceSubtle)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1))
    }

    private var titleSection: some View {
        VStack(spacing: 6) {
            Text(workout.title)
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundColor(PastelTheme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 20)

            Text(workout.date.formatted(date: .long, time: .shortened).uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(1)
                .foregroundColor(PastelTheme.textSecondary)
        }
        .padding(.top, 10)
    }

    private var statsGridSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                statGlassCard(title: "DURATION", value: "\(workout.durationSeconds / 60)m", icon: "stopwatch.fill", color: PastelTheme.pastelAmber)
                statGlassCard(title: "VOLUME", value: "\(totalVolume) kg", icon: "scalemass.fill", color: PastelTheme.pastelEmerald)
            }
            HStack(spacing: 12) {
                statGlassCard(title: "EXERCISES", value: "\(workout.exercises.count)", icon: "bolt.heart.fill", color: PastelTheme.pastelSlate)
                statGlassCard(title: "EFFORT", value: "\(workout.effortPercentage)%", icon: "chart.bar.fill", color: PastelTheme.pastelSage)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    @ViewBuilder
    private var tagsSection: some View {
        if !topMuscles.isEmpty {
            VStack(spacing: 10) {
                Text(LocalizedStringKey("TARGET MUSCLES"))
                    .font(.system(size: 10, weight: .black))
                    .tracking(2)
                    .foregroundColor(PastelTheme.textSecondary)

                HStack(spacing: 8) {
                    ForEach(topMuscles, id: \.self) { muscle in
                        Text(muscle.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(PastelTheme.cardSurfaceSubtle)
                            .foregroundColor(PastelTheme.pastelEmerald)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1))
                    }
                }
            }
            .padding(.top, 16)
        }
    }

    private var footerSection: some View {
        VStack(spacing: 4) {
            Image(systemName: "applewatch")
                .font(.system(size: 20))
                .foregroundStyle(PastelTheme.pastelOat)
            
            Text(LocalizedStringKey("TRACKED WITH WORKOUTTRACKER"))
                .font(.system(size: 10, weight: .black))
                .tracking(2)
                .foregroundColor(PastelTheme.textTertiary)
        }
        .padding(.bottom, 30)
    }

    private func statGlassCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(PastelTheme.cardSurfaceSubtle)
                        .frame(width: 30, height: 30)
                        .overlay(Circle().stroke(PastelTheme.cardBorder, lineWidth: 1))
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(color)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(PastelTheme.textPrimary)

                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundColor(PastelTheme.textSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
    }
}

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
}
