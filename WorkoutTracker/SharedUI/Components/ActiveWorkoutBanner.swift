

internal import SwiftUI
import SwiftData

struct ActiveWorkoutBannerContainer: View {
    @Environment(DIContainer.self) private var di

    @Query(filter: #Predicate<Workout> { $0.endTime == nil }, sort: \.date, order: .reverse)
    private var activeWorkouts: [Workout]

    var body: some View {

        if let activeWorkout = activeWorkouts.first, !di.appState.isInsideActiveWorkout {
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
    @Environment(ThemeManager.self) private var themeManager
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
        HStack(spacing: 16) {

            Button {
                returnToWorkout()
            } label: {
                Image(systemName: "chevron.up")
                    .font(.title3)
                    .foregroundColor(themeManager.current.primaryText)
                    .frame(width: 40, height: 40)
                    .background(themeManager.current.secondaryAccent.opacity(0.1))
                    .clipShape(Circle())
            }

            Button {
                returnToWorkout()
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .opacity(isBlinking ? 0.3 : 1.0)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isBlinking)

                        Text(LocalizedStringKey("Workout"))
                            .font(.headline)
                            .foregroundColor(themeManager.current.primaryText)

                        Text(workout.date, style: .timer)
                            .font(.headline)
                            .monospacedDigit()
                            .foregroundColor(themeManager.current.primaryText)
                    }

                    Text(LocalizationHelper.shared.translateName(currentExerciseName))
                        .font(.subheadline)
                        .foregroundColor(themeManager.current.secondaryText)
                        .lineLimit(1)
                }
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            Button {
                showDeleteAlert = true
            } label: {
                Image(systemName: "trash")
                    .font(.title3)
                    .foregroundColor(.red)
                    .frame(width: 40, height: 40)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(themeManager.current.secondaryAccent.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            isBlinking = true
        }
        .alert(LocalizedStringKey("Cancel Workout?"), isPresented: $showDeleteAlert) {
            Button(LocalizedStringKey("Delete"), role: .destructive) {

                if di.appState.selectedTab == 2 {

                }

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
