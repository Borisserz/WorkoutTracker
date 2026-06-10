

import Foundation
internal import SwiftUI

struct TechniqueHelper {

    static func getDescription(for category: ExerciseCategory) -> String {
        switch category {
        case .squat:
            return NSLocalizedString("Stand with your feet shoulder-width apart. Lower your body by bending your knees and pushing your hips back, as if sitting into a chair. Keep your chest up and core engaged. Lower until your thighs are parallel to the ground, then push through your heels to return to the starting position.", comment: "")
        case .press:
            return NSLocalizedString("Lie on a flat bench with your feet flat on the floor. Grip the bar with hands slightly wider than shoulder-width. Lower the bar to your chest with control, then press it back up explosively. Keep your shoulders retracted and core tight throughout movement.", comment: "")
        case .deadlift:
            return NSLocalizedString("Stand with feet hip-width apart, bar over mid-foot. Hinge at the hips and bend your knees to grip the bar. Keep your back straight and chest up. Drive through your heels and extend your hips and knees simultaneously to lift the bar. Keep the bar close to your body throughout movement.", comment: "")
        case .pull:
            return NSLocalizedString("Grasp the bar or handles with an overhand or underhand grip. Pull the weight toward your torso, squeezing your shoulder blades together at the end of the movement. Keep your core engaged and avoid swinging. Lower the weight with control to complete the repetition.", comment: "")
        case .curl:
            return NSLocalizedString("Stand or sit with a dumbbell in each hand, arms fully extended. Keeping your elbows close to your body, curl the weights up by contracting your biceps. Squeeze at the top of the movement, then lower the weights slowly with control.", comment: "")
        default:
            return NSLocalizedString("Perform this exercise with proper form, focusing on controlled movements and full range of motion. Engage your core throughout the exercise and avoid using momentum. Consult with a fitness professional for specific technique guidance.", comment: "")
        }
    }

    static func getTips(for category: ExerciseCategory) -> [String] {
        switch category {
        case .squat:
            return [
                NSLocalizedString("Keep your knees in line with your toes, never let them cave inward", comment: ""),
                NSLocalizedString("Maintain a neutral spine throughout the entire movement", comment: ""),
                NSLocalizedString("Focus on pushing through your heels, not your toes", comment: ""),
                NSLocalizedString("Don't let your knees go past your toes when descending", comment: ""),
                NSLocalizedString("Keep your chest up and gaze forward to maintain proper posture", comment: "")
            ]
        case .press:
            return [
                NSLocalizedString("Keep your shoulder blades retracted and pressed into the bench", comment: ""),
                NSLocalizedString("Lower the bar with control - don't let it drop onto your chest", comment: ""),
                NSLocalizedString("Keep your feet firmly planted on the floor for stability", comment: ""),
                NSLocalizedString("Maintain a slight arch in your lower back (not excessive)", comment: ""),
                NSLocalizedString("Press the bar in a straight line up and slightly back", comment: "")
            ]
        case .deadlift:
            return [
                NSLocalizedString("Keep the bar close to your body - it should almost scrape your shins", comment: ""),
                NSLocalizedString("Start with your hips higher than your knees", comment: ""),
                NSLocalizedString("Drive through your heels and extend your hips forward at the top", comment: ""),
                NSLocalizedString("Never round your back - keep it neutral throughout", comment: ""),
                NSLocalizedString("Breathe out as you lift and breathe in as you lower", comment: "")
            ]
        default:
            return [
                NSLocalizedString("Focus on proper form over the amount of weight", comment: ""),
                NSLocalizedString("Control the negative (lowering) portion of the movement", comment: ""),
                NSLocalizedString("Keep your core engaged throughout the exercise", comment: ""),
                NSLocalizedString("Breathe properly - exhale on exertion, inhale on return", comment: ""),
                NSLocalizedString("If you feel sharp pain, stop immediately and consult a professional", comment: "")
            ]
        }
    }
}

struct TechniqueSheetView: View {
    let exerciseName: String
    let category: ExerciseCategory

    @Environment(\.dismiss) var dismiss
    @Environment(ThemeManager.self) private var themeManager 

    @State private var dbItem: ExerciseDBItem? = nil
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    if isLoading {
                        ProgressView("Loading details...")
                            .frame(maxWidth: .infinity)
                            .padding(.top, 50)
                    } else {
                        if let item = dbItem {
                            ExerciseVideoView(urlString: item.gifUrl)
                                .padding(.bottom, 8)

                            if let primary = item.primaryMuscles, !primary.isEmpty {

                                musclesSection(title: "Target Muscles", muscles: primary, color: themeManager.current.primaryAccent, icon: "figure.strengthtraining.traditional")
                            }

                            if let secondary = item.secondaryMuscles, !secondary.isEmpty {

                                musclesSection(title: "Synergist Muscles", muscles: secondary, color: themeManager.current.secondaryMidTone, icon: "figure.mixed.cardio")
                            }

                            let stepsToDisplay = LocalizationHelper.shared.translateInstructions(for: exerciseName) ?? item.instructions ?? []

                            if !stepsToDisplay.isEmpty {
                                VStack(alignment: .leading, spacing: 20) {
                                    HStack {
                                        Image(systemName: "list.number")
                                            .foregroundColor(themeManager.current.primaryAccent)
                                        Text(LocalizedStringKey("How to Perform"))
                                            .font(.headline)
                                    }

                                    VStack(alignment: .leading, spacing: 16) {
                                        ForEach(Array(stepsToDisplay.enumerated()), id: \.offset) { index, step in
                                            HStack(alignment: .top, spacing: 16) {
                                                Text("\(index + 1)")
                                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                                    .foregroundColor(.white)
                                                    .frame(width: 28, height: 28)
                                                    .background(
                                                        LinearGradient(colors: [themeManager.current.primaryAccent, themeManager.current.primaryAccent.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                                    )
                                                    .clipShape(Circle())
                                                    .shadow(color: themeManager.current.primaryAccent.opacity(0.3), radius: 4, y: 2)

                                                Text(step)
                                                    .font(.subheadline)
                                                    .lineSpacing(6)
                                                    .foregroundColor(Color.primary.opacity(0.8))
                                            }
                                        }
                                    }
                                }
                                .padding(20)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(themeManager.current.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .shadow(color: Color.black.opacity(0.05), radius: 15, y: 5)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                                )
                            } else {
                                fallbackView
                            }

                        } else {
                            fallbackView
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(LocalizationHelper.shared.translateName(exerciseName))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Done")) { dismiss() }
                }
            }
            .task {
                let item = await ExerciseDatabaseService.shared.getExerciseItem(for: exerciseName)
                await MainActor.run {
                    self.dbItem = item
                    self.isLoading = false
                }
            }
        }
    }

    private func musclesSection(title: String, muscles: [String], color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon).foregroundColor(color)
                Text(LocalizedStringKey(title)).font(.headline)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(muscles, id: \.self) { muscle in
                        Text(LocalizedStringKey(muscle.capitalized))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(color.opacity(0.1))
                            .foregroundColor(color)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(color.opacity(0.2), lineWidth: 1))
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeManager.current.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 15, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }

    private var fallbackView: some View {
        Group {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .foregroundColor(themeManager.current.primaryAccent)
                    Text(LocalizedStringKey("How to Perform"))
                        .font(.headline)
                }
                Text(TechniqueHelper.getDescription(for: category))
                    .font(.subheadline)
                    .lineSpacing(6)
                    .foregroundColor(Color.primary.opacity(0.8))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(themeManager.current.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 15, y: 5)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text(LocalizedStringKey("Key Tips"))
                        .font(.headline)
                }

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(TechniqueHelper.getTips(for: category), id: \.self) { tip in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green) 
                                .font(.system(size: 16))
                                .padding(.top, 2)
                            Text(tip)
                                .font(.subheadline)
                                .lineSpacing(4)
                                .foregroundColor(Color.primary.opacity(0.9))
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(themeManager.current.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 15, y: 5)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
    }
}
