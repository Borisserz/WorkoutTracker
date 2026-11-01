# Inventory risk greps 2026-11-01

## File counts
  27 WorkoutTracker/Features/Workout/Views
  17 WorkoutTracker/SharedUI/Components
  15 WorkoutTracker/AppCore
  11 WorkoutTracker/Features/Stats/Components
  10 WorkoutTracker/Features/Profile
   9 WorkoutTracker/Features/Overview/Components
   8 WorkoutTracker/Services/System
   7 WorkoutTracker/Services/Domain
   7 WorkoutTracker/Features/ExerciseCatalog/Views
   7 WorkoutTracker/DataLayer/Models
   7 WorkoutTracker/Auth
   6 WorkoutTracker/MlVision
   6 WorkoutTracker/Features/AICoach/Views
   6 WorkoutTracker/DataLayer/Repositories
   6 WorkoutTracker/CoreLogic/Helpers
   5 WorkoutTracker/Features/SmartBuilder
   5 WorkoutTracker/Features/Onboarding
   5 WorkoutTracker/Features/Explore
   5 WorkoutTracker/CoreLogic/Managers
   4 WorkoutTracker/SharedUI/Utilities
   4 WorkoutTracker/Features/Workout/ViewModels
   4 WorkoutTracker/Features/Settings
   4 WorkoutTracker/Features/Overview
   4 WorkoutTracker/DataLayer/DTOs
   3 WorkoutTracker/Models
   3 WorkoutTracker/Features/ExerciseCatalog/ViewModels
   2 WorkoutTracker/Services/AI
   2 WorkoutTracker/Features/Explore/Models
   2 WorkoutTracker/Features/AICoach/ViewModels
   2 WorkoutTracker/DataLayer/Migrations
   1 WorkoutTracker/SharedUI/Modifiers
   1 WorkoutTracker/SharedUI
   1 WorkoutTracker/Services/Analytics
   1 WorkoutTracker/Features/Stats
   1 WorkoutTracker/Features/Promo
   1 WorkoutTracker/Features/Overview/Models
   1 WorkoutTracker/Features/Main
   1 WorkoutTracker/Features/Explore/Components
   1 WorkoutTracker/Features/AICoach

## fatalError

## force try / as!
WorkoutTracker/MlVision/CameraManager.swift:245:        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

## TODO FIXME HACK

## empty destructive/action buttons Button(...) { }
WorkoutTracker/Features/Onboarding/GuestSignUpPromptView.swift:103:            Button("OK", role: .cancel) { }
WorkoutTracker/Features/Onboarding/GodModeOnboarding.swift:89:            Button("OK", role: .cancel) { }
WorkoutTracker/Features/Settings/SettingsView.swift:58:                Button(LocalizedStringKey("OK"), role: .cancel) { }
WorkoutTracker/Features/Settings/SettingsView.swift:63:                Button("Cancel", role: .cancel) { }
WorkoutTracker/Features/Settings/SettingsView.swift:71:                Button("Cancel", role: .cancel) { }
WorkoutTracker/Features/Settings/SettingsView.swift:79:                Button("OK", role: .cancel) { }
WorkoutTracker/Features/Settings/SettingsView.swift:84:                Button("Cancel", role: .cancel) { }
WorkoutTracker/Features/Settings/SettingsView.swift:92:                Button("OK", role: .cancel) { }
WorkoutTracker/Features/Settings/SettingsView.swift:97:                Button("OK", role: .cancel) { }
WorkoutTracker/Features/Settings/SettingsView.swift:102:                Button("OK", role: .cancel) { }
WorkoutTracker/Features/Settings/SettingsView.swift:112:                Button(LocalizedStringKey("Cancel"), role: .cancel) { }
WorkoutTracker/Features/Settings/FeedbackView.swift:98:            Button(LocalizedStringKey("OK"), role: .cancel) { }
WorkoutTracker/Features/Explore/FolderDetailView.swift:61:            Button("Cancel", role: .cancel) { }
WorkoutTracker/AppCore/WorkoutTrackerApp.swift:251:                Button("OK", role: .cancel) { }
WorkoutTracker/AppCore/WorkoutTrackerApp.swift:265:                Button("OK", role: .cancel) { }
WorkoutTracker/Features/Profile/SmartCaptureView.swift:43:            Button(LocalizedStringKey("OK"), role: .cancel) { }
WorkoutTracker/Features/ExerciseCatalog/Views/ConfigureExerciseView.swift:117:                Button(LocalizedStringKey("OK"), role: .cancel) { }
WorkoutTracker/Features/Settings/PresetEditorView.swift:124:                Button(LocalizedStringKey("Cancel"), role: .cancel) { }
WorkoutTracker/Features/Settings/PresetEditorView.swift:549:                Button(LocalizedStringKey("OK"), role: .cancel) { }
WorkoutTracker/Features/Workout/Views/SupersetBuilderView.swift:52:                Button(LocalizedStringKey("Cancel"), role: .cancel) { }

## raw UIImpactFeedbackGenerator count
WorkoutTracker/SharedUI/Components/TimerSetupSheet.swift:1
WorkoutTracker/MlVision/AITrackerView.swift:1
WorkoutTracker/SharedUI/Components/SliderInputView.swift:1
WorkoutTracker/SharedUI/Components/RestTimerView.swift:6
WorkoutTracker/SharedUI/Components/ActiveWorkoutBanner.swift:1
WorkoutTracker/SharedUI/Components/ForceUpdateView.swift:1
WorkoutTracker/SharedUI/Components/DesignerComponents.swift:2
WorkoutTracker/Features/SmartBuilder/BuilderStepsViews.swift:1
WorkoutTracker/Features/AICoach/Views/AIWeeklyReviewSheet.swift:4
WorkoutTracker/Features/AICoach/Views/InWorkoutAICoachView.swift:1
WorkoutTracker/Features/Profile/WeightHistoryView.swift:1
WorkoutTracker/Features/AICoach/ViewModels/InWorkoutAICoachViewModel.swift:1
WorkoutTracker/Features/SmartBuilder/SmartGeneratorViewModel.swift:1
WorkoutTracker/Features/AICoach/SmartWorkoutBuilderSheet.swift:1
WorkoutTracker/Features/Settings/PresetEditorView.swift:8
WorkoutTracker/Features/SmartBuilder/SmartGeneratorEntryView.swift:1
WorkoutTracker/Features/Settings/SettingsView.swift:1
WorkoutTracker/Features/AICoach/Views/AIChatBotView.swift:2
WorkoutTracker/Features/AICoach/Views/AICoachComponents.swift:1
WorkoutTracker/Features/AICoach/Views/AICameraExerciseSelectorSheet.swift:1
WorkoutTracker/Features/Profile/AddWeightSheet.swift:1
WorkoutTracker/Features/Profile/ProgressComparisonView.swift:5
WorkoutTracker/Features/Profile/ProfileView.swift:2
WorkoutTracker/Features/ExerciseCatalog/Views/AddNewExerciseView.swift:1
WorkoutTracker/Features/ExerciseCatalog/Views/ExerciseHistoryView.swift:3
WorkoutTracker/Features/ExerciseCatalog/Views/ExerciseView.swift:1
WorkoutTracker/Features/ExerciseCatalog/Views/ConfigureExerciseView.swift:5
WorkoutTracker/Features/Overview/OverviewView.swift:1
WorkoutTracker/Features/Onboarding/GodModeOnboarding.swift:2
WorkoutTracker/Features/Stats/ProgressView.swift:11
WorkoutTracker/Features/Stats/Components/GoalComponents.swift:1
WorkoutTracker/Features/Explore/ProgramDetailView.swift:1
WorkoutTracker/Features/Workout/ViewModels/WorkoutDetailViewModel.swift:1
WorkoutTracker/Features/Workout/Views/LegendaryRoutinesView.swift:1
WorkoutTracker/Features/ExerciseCatalog/Views/OneRepMaxTabView.swift:1
WorkoutTracker/Features/Workout/Views/PremiumExerciseSearchBar.swift:2
WorkoutTracker/Features/Explore/AIProgramBuilderSheet.swift:1
WorkoutTracker/Features/Explore/AIProgramBuilderViewModel.swift:1
WorkoutTracker/Features/Workout/Views/ProgramDiscoveryView.swift:1
WorkoutTracker/Features/Workout/Views/SmartWorkoutRoutinesListView.swift:1

## Color.purple / .pink leftovers
WorkoutTracker/Features/Onboarding/OnboardingFlow.swift:681:                           colors: [.purple, .blue],
WorkoutTracker/SharedUI/Components/DesignerComponents.swift:218:        let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, .pink, .cyan]
WorkoutTracker/Features/Settings/MuscleColorSettingsView.swift:14:        .red, .orange, .yellow, .green, .blue, .purple, .pink, .teal, .indigo, .brown
WorkoutTracker/Features/SmartBuilder/SmartGeneratorEntryView.swift:113:                quickCard(title: "Dumbbell Only", icon: "scalemass.fill", color: .purple, desc: "Full Body, 45m") {
WorkoutTracker/Features/Explore/ExploreRoutinesView.swift:147:                                iconColor: .purple,
WorkoutTracker/Features/Stats/Components/TrainingStyleDetailView.swift:101:                legendItem(title: "Isolation", color: .purple, value: stats.isolationSets)
WorkoutTracker/Features/Stats/ProgressView.swift:1611:                    iconColor: .purple,
WorkoutTracker/Features/Stats/ProgressView.swift:1883:        MoodSticker(emoji: "🚀", title: "Dedication", subtitle: "Pure Focus", color: .purple, motivation: "Pure focus. Consistency is key! 🚀")
WorkoutTracker/Features/Workout/Views/ProgramDiscoveryView.swift:38:                gradientColors: [.purple, .indigo],

## systemGroupedBackground
WorkoutTracker/Features/Explore/ProgramDetailView.swift:16:            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
WorkoutTracker/Features/Explore/ProgramDetailView.swift:87:                LinearGradient(colors: [Color(UIColor.systemGroupedBackground), Color(UIColor.systemGroupedBackground).opacity(0)], startPoint: .bottom, endPoint: .top)
WorkoutTracker/Features/SmartBuilder/SmartGeneratorEntryView.swift:18:                (colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground)).ignoresSafeArea()
WorkoutTracker/Features/Explore/AIProgramBuilderSheet.swift:39:                (colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground))
WorkoutTracker/Features/Explore/AIProgramBuilderSheet.swift:251:                LinearGradient(colors: [colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground), .clear], startPoint: .bottom, endPoint: .top)
WorkoutTracker/Features/Explore/AIProgramBuilderSheet.swift:443:                LinearGradient(colors: [colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground), .clear], startPoint: .bottom, endPoint: .top)
WorkoutTracker/Features/Explore/FolderDetailView.swift:38:        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
WorkoutTracker/Features/SmartBuilder/GeneratedWorkoutResultView.swift:61:                Color(UIColor.systemGroupedBackground)
WorkoutTracker/Features/SmartBuilder/GeneratedWorkoutResultView.swift:240:                colors: [(colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground)), .clear],
WorkoutTracker/Features/Settings/PresetEditorView.swift:64:                (colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color.white)
WorkoutTracker/Features/Settings/PresetEditorView.swift:105:                    LinearGradient(colors: [(colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color.white), (colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color.white).opacity(0)], startPoint: .bottom, endPoint: .top)
WorkoutTracker/Features/Settings/PresetEditorView.swift:510:            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
WorkoutTracker/Features/Settings/PresetEditorView.swift:530:                        colors: [Color(UIColor.systemGroupedBackground), Color(UIColor.systemGroupedBackground).opacity(0)],
WorkoutTracker/Features/Explore/Components/ExploreComponents.swift:75:                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
WorkoutTracker/Features/Explore/Components/ExploreComponents.swift:116:                    Color(UIColor.systemGroupedBackground)
WorkoutTracker/Features/AICoach/Views/AICoachView.swift:1101:            (colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color(UIColor.secondarySystemBackground)).ignoresSafeArea()
WorkoutTracker/Features/AICoach/Views/AICoachView.swift:1559:                (colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color(UIColor.secondarySystemBackground)).ignoresSafeArea()
WorkoutTracker/Features/Overview/DetailedRecoveryView.swift:56:        .background(Color(UIColor.systemGroupedBackground))
WorkoutTracker/Features/Profile/WeightHistoryView.swift:39:                (colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color(UIColor.secondarySystemBackground))
WorkoutTracker/Features/Stats/Components/GoalComponents.swift:249:            .background(Color(UIColor.systemGroupedBackground))
WorkoutTracker/Features/AICoach/Views/AIChatBotView.swift:277:                (colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground))
WorkoutTracker/Features/Profile/BodyMeasurementsView.swift:96:                (colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color(UIColor.secondarySystemBackground))
WorkoutTracker/Features/AICoach/Views/AICameraExerciseSelectorSheet.swift:13:                (colorScheme == .dark ? PastelTheme.canvas : Color(UIColor.systemGroupedBackground))
WorkoutTracker/Features/Stats/Components/ProgressDetailSheets.swift:12:                (colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
WorkoutTracker/Features/Stats/Components/ProgressDetailSheets.swift:231:                (colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
WorkoutTracker/Features/Profile/ProgressComparisonView.swift:27:                Color(UIColor.systemGroupedBackground)
WorkoutTracker/Features/Profile/AddWeightSheet.swift:30:                (colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color(UIColor.secondarySystemBackground))
WorkoutTracker/Features/Profile/AddWeightSheet.swift:237:            LinearGradient(colors: [colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color(UIColor.secondarySystemBackground), .clear], startPoint: .bottom, endPoint: .top)
WorkoutTracker/Features/Stats/Components/TrainingStyleDetailView.swift:54:        .background(colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground))
WorkoutTracker/Features/Profile/ProfileView.swift:1415:            (colorScheme == .dark ? Color(red: 0.05, green: 0.05, blue: 0.07) : Color(UIColor.systemGroupedBackground)).edgesIgnoringSafeArea(.all)

## Cyrillic Text(" count approx
lines 60 files 18
