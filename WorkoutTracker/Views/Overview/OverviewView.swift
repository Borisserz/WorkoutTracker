// ============================================================
// FILE: WorkoutTracker/Views/Overview/OverviewView.swift
// ============================================================

internal import SwiftUI
import SwiftData
import Charts
import ActivityKit

struct OverviewView: View {
    // MARK: - Environment & State
    @Environment(\.modelContext) private var context
    
    @Environment(TutorialManager.self) var tutorialManager
    @Environment(WorkoutService.self) var workoutService
    @Environment(DashboardViewModel.self) var dashboardViewModel
    @Environment(UserStatsViewModel.self) var userStatsViewModel
    
    @Query private var recentWorkouts: [Workout]
    
    // Навигация и модальные окна
    @State private var showAddWorkout = false
    @State private var showSettings = false
    @State private var showMuscleColorSettings = false
    @State private var navigateToNewWorkout = false
    @State private var navigateToExercises = false
    @State private var navigateToDetailedRecovery = false
    
    @State private var showProfile = false
    @State private var generatedFreshWorkout: GeneratedWorkout?
    
    @State private var selectedChartMuscle: String? = nil
    @State private var isPulsing = false
    
    @StateObject private var colorManager = MuscleColorManager.shared
    
    init() {
        var desc = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        desc.fetchLimit = 1
        _recentWorkouts = Query(desc)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        if recentWorkouts.isEmpty {
                            emptyStateView
                        } else {
                            chartSection
                            recoverySection
                            generateFreshWorkoutBanner
                            topExercisesSection
                        }
                    }
                    .padding()
                }
                
                if !recentWorkouts.isEmpty {
                    Color.white.opacity(0.01)
                        .frame(width: 50, height: 50)
                        .contentShape(Rectangle())
                        .offset(x: -10, y: 0)
                        .spotlight(
                            step: .tapPlus,
                            manager: tutorialManager,
                            text: "Tap + to add a new workout",
                            alignment: .bottom
                        )
                        .allowsHitTesting(false)
                }
            }
            .navigationTitle(LocalizedStringKey("Overview"))
            .navigationDestination(isPresented: $navigateToNewWorkout) {
                if let firstWorkout = recentWorkouts.first {
                    WorkoutDetailView(workout: firstWorkout)
                }
            }
            .navigationDestination(isPresented: $navigateToExercises) {
                ExerciseView()
            }
            .navigationDestination(isPresented: $navigateToDetailedRecovery) {
                DetailedRecoveryView()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.primary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: WorkoutCalendarView()) {
                        Image(systemName: "calendar")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showAddWorkout) {
                AddWorkoutView(onWorkoutCreated: {
                    navigateToNewWorkout = true
                })
            }
            .sheet(isPresented: $showMuscleColorSettings) {
                MuscleColorSettingsView()
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
                    .environment(userStatsViewModel)
                    .environment(userStatsViewModel.progressManager)
            }
            .sheet(item: $generatedFreshWorkout) { generated in
                FreshWorkoutPreviewSheet(generatedWorkout: generated) {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    // Конвертируем GeneratedWorkout в GeneratedWorkoutDTO для сервиса
                    let dto = GeneratedWorkoutDTO(
                        title: generated.title,
                        aiMessage: "",
                        exercises: generated.exercises.map { ex in
                            GeneratedExerciseDTO(
                                name: ex.name,
                                muscleGroup: ex.muscleGroup,
                                type: ex.type.rawValue,
                                sets: ex.setsCount,
                                reps: ex.firstSetReps,
                                recommendedWeightKg: ex.firstSetWeight > 0 ? ex.firstSetWeight : nil,
                                restSeconds: nil
                            )
                        }
                    )
                    
                    Task {
                        await workoutService.startGeneratedWorkout(dto)
                        await MainActor.run {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                navigateToNewWorkout = true
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties & Logic
    
    private var recoveryDict: [String: Int] {
        var dict = [String: Int]()
        for status in dashboardViewModel.recoveryStatus {
            dict[status.muscleGroup] = status.recoveryPercentage
        }
        return dict
    }
    
    private var selectedMuscleInfo: MuscleCountDTO? {
        guard let selectedChartMuscle else { return nil }
        return dashboardViewModel.dashboardMuscleData.first(where: { $0.muscle == selectedChartMuscle })
    }
    
    // MARK: - View Sections
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 80))
                .foregroundColor(.blue.opacity(0.8))
            
            Text(LocalizedStringKey("Welcome to WorkoutTracker!"))
                .font(.title2).bold()
            
            Text(LocalizedStringKey("Your journey starts here. Create your first workout to begin tracking."))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button {
                showAddWorkout = true
                if tutorialManager.currentStep == .tapPlus {
                    tutorialManager.nextStep()
                }
            } label: {
                Text(LocalizedStringKey("Start Your First Workout"))
                    .font(.title3)
                    .bold()
                    .foregroundColor(.white)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(16)
                    .shadow(color: .blue.opacity(0.6), radius: isPulsing ? 15 : 5, x: 0, y: isPulsing ? 8 : 2)
                    .scaleEffect(isPulsing ? 1.03 : 0.97)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)
            }
            .padding(.top, 10)
            .onAppear {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    isPulsing = true
                }
            }
            .onDisappear {
                isPulsing = false
            }
            .spotlight(
                step: .tapPlus,
                manager: tutorialManager,
                text: "Tap here to create your first workout!",
                alignment: .top,
                yOffset: -10
            )
        }
        .padding(24)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(20)
        .padding(.top, 10)
    }

    private var recoverySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                navigateToDetailedRecovery = true
            } label: {
                HStack {
                    Text(LocalizedStringKey("Muscle Recovery"))
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(LocalizedStringKey("See details"))
                        .font(.caption)
                        .foregroundColor(.blue)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .simultaneousGesture(TapGesture().onEnded {
                if tutorialManager.currentStep == .recoveryCheck {
                    tutorialManager.nextStep()
                }
            })
            
            Divider()
            
            if recentWorkouts.isEmpty {
                Text(LocalizedStringKey("Complete a workout to see data"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                BodyHeatmapView(muscleIntensities: recoveryDict, isRecoveryMode: true)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .spotlight(
            step: .recoveryCheck,
            manager: tutorialManager,
            text: "Check your Muscle Recovery status here.",
            alignment: .top,
            yOffset: -10
        )
    }
    
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(LocalizedStringKey("Muscles Worked")).font(.headline).foregroundColor(.secondary)
                Spacer()
                Button {
                    showMuscleColorSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            if dashboardViewModel.dashboardMuscleData.isEmpty {
                Text(LocalizedStringKey("No workouts yet")).padding().frame(maxWidth: .infinity).foregroundColor(.secondary)
            } else {
                Chart(dashboardViewModel.dashboardMuscleData, id: \.muscle) { item in
                    SectorMark(angle: .value("Count", item.count), innerRadius: .ratio(0.6), angularInset: 2)
                        .cornerRadius(5)
                        .foregroundStyle(colorManager.getColor(for: item.muscle))
                        .opacity(selectedChartMuscle == nil || selectedChartMuscle == item.muscle ? 1.0 : 0.3)
                }
                .frame(height: 220)
                .chartBackground { proxy in
                    GeometryReader { geometry in
                        VStack {
                            if let selected = selectedMuscleInfo {
                                Text(LocalizedStringKey(selected.muscle)).font(.headline).multilineTextAlignment(.center)
                                Text(LocalizedStringKey("\(selected.count) sets")).font(.title2).bold().foregroundColor(.blue)
                            } else {
                                Text(LocalizedStringKey("Total")).font(.caption).foregroundColor(.secondary)
                                Text("\(dashboardViewModel.dashboardTotalExercises)").font(.title).bold().foregroundColor(.primary)
                            }
                        }
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    }
                }
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), alignment: .leading)], spacing: 12) {
                    ForEach(dashboardViewModel.dashboardMuscleData, id: \.muscle) { item in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(colorManager.getColor(for: item.muscle))
                                .frame(width: 10, height: 10)
                                .opacity(selectedChartMuscle == nil || selectedChartMuscle == item.muscle ? 1.0 : 0.3)
                            
                            Text(LocalizedStringKey(item.muscle))
                                .font(.caption)
                                .fontWeight(selectedChartMuscle == item.muscle ? .bold : .regular)
                                .foregroundColor(selectedChartMuscle == item.muscle ? .primary : .secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selectedChartMuscle == item.muscle {
                                    selectedChartMuscle = nil
                                } else {
                                    selectedChartMuscle = item.muscle
                                }
                            }
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .spotlight(
            step: .highlightChart,
            manager: tutorialManager,
            text: "See which muscles you train the most.",
            alignment: .top,
            yOffset: -10
        )
    }
    
    private var topExercisesSection: some View {
         VStack(alignment: .leading, spacing: 10) {
             if !dashboardViewModel.dashboardTopExercises.isEmpty {
                 HStack {
                     Text(LocalizedStringKey("Exercises")).font(.title2).bold()
                     Spacer()
                     Button {
                         navigateToExercises = true
                     } label: {
                         Text(LocalizedStringKey("See all")).font(.subheadline).foregroundColor(.blue)
                     }
                 }
                 .padding(.top, 10)
                 
                 ForEach(Array(dashboardViewModel.dashboardTopExercises.enumerated()), id: \.element.name) { index, item in
                     NavigationLink(destination: ExerciseHistoryView(exerciseName: item.name)) {
                         HStack {
                             rankIcon(rank: index + 1)
                             Text(LocalizedStringKey(item.name)).font(.headline).foregroundColor(.primary)
                             Spacer()
                             Text("\(item.count) times").font(.subheadline).foregroundColor(.secondary)
                             Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray)
                         }
                         .padding().background(Color(UIColor.secondarySystemBackground)).cornerRadius(10).shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                     }
                 }
             }
         }
     }
    
    private var generateFreshWorkoutBanner: some View {
        Button(action: {
            handleGenerateFreshWorkout()
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.yellow.opacity(0.2)).frame(width: 44, height: 44)
                    Image(systemName: "bolt.fill").foregroundColor(.yellow).font(.title2)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("Fresh Muscle Workout"))
                        .font(.headline).foregroundColor(.primary)
                    Text(LocalizedStringKey("Generate a routine for fully recovered muscles"))
                        .font(.caption).foregroundColor(.secondary).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray)
            }
            .padding().background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16).shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
        
    private func handleGenerateFreshWorkout() {
        do {
            let generated = try WorkoutGenerationService.generateFreshWorkout(
                recoveryStatus: dashboardViewModel.recoveryStatus,
                catalog: Exercise.catalog
            )
            generatedFreshWorkout = generated
        } catch {
            workoutService.showError(title: String(localized: "Too Tired!"), message: error.localizedDescription)
        }
    }
    
    @ViewBuilder
    private func rankIcon(rank: Int) -> some View {
        ZStack {
            Circle().fill(rank == 1 ? Color.yellow : rank == 2 ? Color.gray : rank == 3 ? Color.brown : Color.blue.opacity(0.1)).frame(width: 30, height: 30)
            Text("\(rank)").font(.caption).bold().foregroundColor(rank <= 3 ? .white : .blue)
        }.padding(.trailing, 5)
    }
}

// MARK: - Fresh Workout Preview Models & Views

struct GeneratedWorkout: Identifiable {
    let id = UUID()
    let title: String
    let exercises: [Exercise]
}

struct FreshWorkoutPreviewSheet: View {
    let generatedWorkout: GeneratedWorkout
    let onStart: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(generatedWorkout.exercises) { ex in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(ex.name).font(.headline)
                            Text(ex.muscleGroup)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(ex.setsCount) sets")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("Ready to Train"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Cancel")) { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    dismiss()
                    onStart()
                } label: {
                    Text(LocalizedStringKey("Start Workout"))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                }
                .padding()
                .background(Color(UIColor.systemBackground).shadow(color: .black.opacity(0.1), radius: 5, y: -5))
            }
        }
    }
}
