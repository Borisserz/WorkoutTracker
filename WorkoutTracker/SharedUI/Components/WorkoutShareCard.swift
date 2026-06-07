

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
                    .foregroundColor(themeManager.current.background)
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
            // Base dark background
            Color(hex: "0a0a0e").ignoresSafeArea()

            // Dynamic Mesh/Aurora Glows
            Circle()
                .fill(themeManager.current.primaryAccent)
                .frame(width: 350)
                .blur(radius: 80)
                .offset(x: -150, y: -250)
                .opacity(0.4)

            Circle()
                .fill(Color.purple)
                .frame(width: 300)
                .blur(radius: 90)
                .offset(x: 180, y: 300)
                .opacity(0.35)
                
            Circle()
                .fill(Color.cyan)
                .frame(width: 200)
                .blur(radius: 60)
                .offset(x: -100, y: 150)
                .opacity(0.2)
        }
    }

    private var headerSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom))
                .shadow(color: .orange.opacity(0.5), radius: 5, y: 2)

            Text(LocalizedStringKey("WORKOUT COMPLETE"))
                .font(.system(size: 14, weight: .black, design: .rounded))
                .tracking(3)
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
    }

    private var titleSection: some View {
        VStack(spacing: 6) {
            Text(workout.title)
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .shadow(color: .black.opacity(0.5), radius: 2, y: 2)
                .padding(.horizontal, 20)

            Text(workout.date.formatted(date: .long, time: .shortened).uppercased())
                .font(.system(size: 12, weight: .bold))
                .tracking(1)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.top, 10)
    }

    private var statsGridSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                statGlassCard(title: "DURATION", value: "\(workout.durationSeconds / 60)m", icon: "stopwatch.fill", color: .yellow)
                statGlassCard(title: "VOLUME", value: "\(totalVolume) kg", icon: "scalemass.fill", color: .green)
            }
            HStack(spacing: 16) {
                statGlassCard(title: "EXERCISES", value: "\(workout.exercises.count)", icon: "bolt.heart.fill", color: .cyan)
                statGlassCard(title: "EFFORT", value: "\(workout.effortPercentage)%", icon: "chart.bar.fill", color: .orange)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    @ViewBuilder
    private var tagsSection: some View {
        if !topMuscles.isEmpty {
            VStack(spacing: 12) {
                Text(LocalizedStringKey("TARGET MUSCLES"))
                    .font(.system(size: 11, weight: .black))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.5))

                HStack(spacing: 10) {
                    ForEach(topMuscles, id: \.self) { muscle in
                        Text(muscle.uppercased())
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(colors: [themeManager.current.primaryAccent.opacity(0.8), themeManager.current.primaryAccent.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                            .shadow(color: themeManager.current.primaryAccent.opacity(0.4), radius: 8, y: 4)
                    }
                }
            }
            .padding(.top, 20)
        }
    }

    private var footerSection: some View {
        VStack(spacing: 4) {
            Image(systemName: "applewatch")
                .font(.system(size: 24))
                .foregroundStyle(LinearGradient(colors: [.white, .gray], startPoint: .top, endPoint: .bottom))
            
            Text(LocalizedStringKey("TRACKED WITH WORKOUTTRACKER"))
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.bottom, 30)
    }

    private func statGlassCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(color)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: color.opacity(0.5), radius: 8, y: 2)

                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .background(color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(LinearGradient(colors: [Color.white.opacity(0.4), Color.white.opacity(0.0)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
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
