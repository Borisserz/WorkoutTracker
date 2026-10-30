

internal import SwiftUI
import SwiftData

struct ActiveWorkoutBannerContainer: View {
    @Environment(DIContainer.self) private var di

    @Query(filter: #Predicate<Workout> { $0.endTime == nil }, sort: \.date, order: .reverse)
    private var activeWorkouts: [Workout]

    var body: some View {
        if let activeWorkout = activeWorkouts.first,
           abs(activeWorkout.date.timeIntervalSinceNow) < 12 * 3600,
           !di.appState.isInsideActiveWorkout {
            ActiveWorkoutBanner(workout: activeWorkout)
                .padding(.horizontal, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(99)
        }
    }
}

struct ActiveWorkoutBanner: View {
    @Environment(DIContainer.self) private var di
    @Environment(WorkoutService.self) private var workoutService
    @Environment(RestTimerManager.self) private var timerManager
    let workout: Workout

    @State private var showDeleteAlert = false
    @State private var isBlinking = false

    private var currentExerciseName: String {
        if workout.exercises.isEmpty {
            return String(localized: "In progress...")
        }
        if let activeEx = workout.exercises.first(where: { !$0.isCompleted }) {
            return activeEx.name
        }
        return String(localized: "Finishing up...")
    }

    var body: some View {
        HStack(spacing: 14) {
            // Left Action / Expand Indicator
            Button {
                returnToWorkout()
            } label: {
                ZStack {
                    Circle()
                        .fill(PastelTheme.cardSurfaceSubtle)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "chevron.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(PastelTheme.pastelOat)
                }
            }
            .buttonStyle(.plain)

            // Center details (tap anywhere to return)
            Button {
                returnToWorkout()
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(PastelTheme.pastelSage)
                            .frame(width: 8, height: 8)
                            .opacity(isBlinking ? 0.35 : 1.0)
                            .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: isBlinking)

                        Text(LocalizedStringKey("Workout"))
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundColor(PastelTheme.textSecondary)

                        Text(workout.date, style: .timer)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .monospacedDigit()
                            .foregroundColor(PastelTheme.textPrimary)
                    }

                    Text(LocalizationHelper.shared.translateName(currentExerciseName))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(PastelTheme.textTertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            // Right Close / Delete Button
            Button {
                showDeleteAlert = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.12))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.red.opacity(0.9))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(PastelTheme.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 6)
        .onAppear {
            isBlinking = true
        }
        .alert(LocalizedStringKey("Cancel Workout?"), isPresented: $showDeleteAlert) {
            Button(LocalizedStringKey("Delete"), role: .destructive) {
                timerManager.stopRestTimer()

                Task {
                    await workoutService.deleteWorkout(workout)
                }
            }
        }
    }

    private func returnToWorkout() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        di.appState.selectedTab = 2
        di.appState.returnToActiveWorkoutId = workout.persistentModelID
    }
}
