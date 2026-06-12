

internal import SwiftUI
import SwiftData

struct LegendaryRoutinesView: View {
    @Environment(DIContainer.self) private var di
    @Environment(WorkoutService.self) private var workoutService
    @Environment(\.dismiss) private var dismiss

    @State private var routines: [LegendaryRoutine] = []
    @State private var activeRoutineID: UUID?

    @State private var currentBackgroundColors: [Color] = [.black, .gray]
    @State private var isStartingWorkout = false

    var body: some View {
        ZStack {

            MorphingBackgroundView(colors: currentBackgroundColors)
                .ignoresSafeArea()

            VStack(spacing: 0) {

                VStack(spacing: 4) {
                    Text(LocalizedStringKey("Hall of Fame"))
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)

                    Text(LocalizedStringKey("Train like the legends of every era."))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 20)
                .padding(.bottom, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(routines) { routine in
                            LegendaryCardView(routine: routine) {
                                startRoutine(routine)
                            }
                            .containerRelativeFrame(.horizontal, count: 1, spacing: 16)
                            .scrollTransition(axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1.0 : 0.85)
                                    .rotation3DEffect(
                                        .degrees(phase.value * -15),
                                        axis: (x: 0, y: 1, z: 0),
                                        perspective: 0.5
                                    )
                                    .opacity(phase.isIdentity ? 1.0 : 0.6)
                                    .blur(radius: phase.isIdentity ? 0 : 3)
                            }
                            .id(routine.id)
                        }
                    }
                    .padding(.vertical, 20)
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $activeRoutineID)
                .safeAreaPadding(.horizontal, 32) 

                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
                    if FirestoreProgramService.shared.legendaryRoutines.isEmpty {
                        await FirestoreProgramService.shared.fetchAllPrograms()
                    }
                    self.routines = FirestoreProgramService.shared.legendaryRoutines

                    if activeRoutineID == nil, let first = routines.first {
                        activeRoutineID = first.id
                        currentBackgroundColors = first.gradientColors
                    }
                }
        .onChange(of: activeRoutineID) { _, newID in
            if let id = newID, let routine = routines.first(where: { $0.id == id }) {
                withAnimation(.easeInOut(duration: 0.8)) {
                    currentBackgroundColors = routine.gradientColors
                }
                let gen = UISelectionFeedbackGenerator()
                gen.selectionChanged()
            }
        }
        .overlay {
            if isStartingWorkout {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    ProgressView().tint(.white).scaleEffect(1.5)
                }
            }
        }
    }

    private func startRoutine(_ routine: LegendaryRoutine) {
        guard !isStartingWorkout else { return }
        isStartingWorkout = true

        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        Task { @MainActor in

            let generatedDTO = GeneratedWorkoutDTO(
                title: routine.title,
                aiMessage: "Entering \(routine.eraTitle). \(routine.loreDescription)",
                exercises: routine.exercises
            )

            await workoutService.startGeneratedWorkout(generatedDTO)

            if let newWorkout = await workoutService.fetchLatestWorkout() {
                di.appState.returnToActiveWorkoutId = newWorkout.persistentModelID
                di.appState.selectedTab = 2 
            }

            isStartingWorkout = false
            dismiss()
        }
    }
}

struct LegendaryCardView: View {
    let routine: LegendaryRoutine
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "star.fill")
                        .font(.title3)
                        .foregroundStyle(
                            LinearGradient(
                                colors: routine.gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text(LocalizedStringKey(routine.eraTitle))
                        .font(.headline)
                        .fontWeight(.heavy)
                        .tracking(2)
                        .foregroundColor(.white)
                }

                Text(LocalizedStringKey(routine.title))
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .shadow(color: routine.gradientColors.first?.opacity(0.5) ?? .clear, radius: 10, x: 0, y: 4)

                Text(LocalizedStringKey(routine.shortVibe))
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(
                        LinearGradient(
                            colors: routine.gradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        (routine.gradientColors.first ?? .black).opacity(0.3),
                        Color.black.opacity(0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            // Content Section
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {

                    Text(LocalizedStringKey(routine.loreDescription))
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 20) {
                        HStack(spacing: 4) {
                            Image(systemName: "stopwatch.fill").foregroundColor(.white.opacity(0.6))
                            Text(LocalizedStringKey("~\(routine.estimatedMinutes) min")).fontWeight(.bold)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill").foregroundColor(routine.gradientColors.last ?? .orange)
                            Text(LocalizedStringKey(routine.difficulty.rawValue)).fontWeight(.bold)
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)

                    HStack {
                        ForEach(routine.benefits.prefix(3), id: \.self) { benefit in
                            Text(LocalizedStringKey(benefit))
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.4))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            LinearGradient(
                                                colors: routine.gradientColors,
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                                .foregroundColor(.white)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(LocalizedStringKey("Exercises in Protocol:"))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))

                        Text(LocalizedStringKey("\(routine.exercises.count) main exercises included."))
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.white)
                    }
                    .padding(.top, 10)
                }
                .padding(24)
            }

            Spacer(minLength: 20)

            // Button Section
            Button(action: onStart) {
                HStack {
                    Text(LocalizedStringKey("Start Routine"))
                        .font(.title3)
                        .fontWeight(.bold)
                    Image(systemName: "bolt.fill")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    LinearGradient(
                        colors: routine.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(20)
                .shadow(color: (routine.gradientColors.first ?? .white).opacity(0.5), radius: 15, x: 0, y: 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(
            ZStack {
                Color.black.opacity(0.5)
                LinearGradient(
                    colors: [
                        (routine.gradientColors.first ?? .clear).opacity(0.1),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark) 
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: routine.gradientColors + [.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .shadow(color: (routine.gradientColors.first ?? .black).opacity(0.3), radius: 25, x: 0, y: 15)
    }
}

struct MorphingBackgroundView: View {
    var colors: [Color]
    @State private var isAnimating = false

    var body: some View {
        ZStack {

            Color(hex: "0A0A0A").ignoresSafeArea()

            Circle()
                .fill(colors.first ?? .blue)
                .frame(width: 450, height: 450)
                .blur(radius: 120)
                .offset(
                    x: isAnimating ? 150 : -100,
                    y: isAnimating ? -250 : 200
                )

            Circle()
                .fill(colors.last ?? .purple)
                .frame(width: 400, height: 400)
                .blur(radius: 120)
                .offset(
                    x: isAnimating ? -200 : 150,
                    y: isAnimating ? 250 : -150
                )

            if colors.count > 2 {
                Circle()
                    .fill(colors[1])
                    .frame(width: 300, height: 300)
                    .blur(radius: 120)
                    .offset(
                        x: isAnimating ? -50 : 50,
                        y: isAnimating ? 50 : -50
                    )
            }

            Color.black.opacity(0.4)
                .ignoresSafeArea()
        }

        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }

        .animation(.easeInOut(duration: 1.2), value: colors)
    }
}
