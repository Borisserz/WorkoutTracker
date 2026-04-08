// ============================================================
// FILE: WorkoutTracker/Views/Overview/OverviewView.swift
// ============================================================
internal import SwiftUI
import SwiftData
import Charts
import ActivityKit

// MARK: - 1. Router (Чистая логика навигации)

@Observable
@MainActor
final class OverviewRouter {
    var path = NavigationPath()
    var activeSheet: SheetDestination? = nil
    
    enum SheetDestination: Identifiable {
        case settings
        case addWorkout
        case muscleColor
        case profile
        case freshWorkout(GeneratedWorkout)
        
        var id: String {
            switch self {
            case .settings: return "settings"
            case .addWorkout: return "addWorkout"
            case .muscleColor: return "muscleColor"
            case .profile: return "profile"
            case .freshWorkout(let w): return "fresh_\(w.id)"
            }
        }
    }
    
    enum RouteDestination: Hashable {
        case workoutDetail(Workout)
        case exercises
        case detailedRecovery
    }
    
    func push(_ route: RouteDestination) {
        path.append(route)
    }
    
    func present(_ sheet: SheetDestination) {
        activeSheet = sheet
    }
    
    func dismissSheet() {
        activeSheet = nil
    }
}

// MARK: - 2. Main View

struct OverviewView: View {
    // MARK: - Environment
    @Environment(\.modelContext) private var context
    @Environment(TutorialManager.self) var tutorialManager
    @Environment(WorkoutService.self) var workoutService
    @Environment(DashboardViewModel.self) var dashboardViewModel
    @Environment(UserStatsViewModel.self) var userStatsViewModel
    @Environment(DIContainer.self) private var di
    @AppStorage(Constants.UserDefaultsKeys.userGender.rawValue) private var userGender = "male"
    @Query(sort: \Workout.date, order: .reverse) private var recentWorkouts: [Workout]
    
    // MARK: - State
    @State private var router = OverviewRouter()
    
    // Только UI стейты остаются во View
    @State private var selectedChartMuscle: String? = nil
    @State private var isPulsing = false
    @StateObject private var colorManager = MuscleColorManager.shared
    
    var body: some View {
        NavigationStack(path: $router.path) {
            ZStack(alignment: .topTrailing) {
                ScrollView {
                    VStack(spacing: 20) {
                        if recentWorkouts.isEmpty {
                            emptyStateView
                        } else {
                            chartSection
                            recoverySection
                            proactiveAutopilotBanner
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
                        .spotlight(step: .tapPlus, manager: tutorialManager, text: "Tap + to add a new workout", alignment: .bottom)
                        .allowsHitTesting(false)
                }
            }
            .navigationTitle(LocalizedStringKey("Overview"))
            .navigationDestination(for: OverviewRouter.RouteDestination.self) { route in
                switch route {
                case .workoutDetail(let workout):
                    WorkoutDetailView(workout: workout, viewModel: di.makeWorkoutDetailViewModel())
                case .exercises:
                    ExerciseView()
                case .detailedRecovery:
                    DetailedRecoveryView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { router.present(.settings) } label: {
                        Image(systemName: "gearshape.fill").foregroundColor(.primary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: WorkoutCalendarView()) {
                        Image(systemName: "calendar")
                    }
                }
            }
            .sheet(item: $router.activeSheet) { sheet in
                switch sheet {
                case .settings:
                    SettingsView()
                case .addWorkout:
                    AddWorkoutView(onWorkoutCreated: {
                        // ✅ FIX: Безопасный поиск созданной тренировки на MainActor
                        Task { @MainActor in
                            var descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
                            descriptor.fetchLimit = 1
                            if let newWorkout = try? context.fetch(descriptor).first {
                                router.push(.workoutDetail(newWorkout))
                            }
                        }
                    })
                case .muscleColor:
                    MuscleColorSettingsView()
                case .profile:
                    ProfileView()
                        .environment(userStatsViewModel)
                        .environment(userStatsViewModel.progressManager)
                case .freshWorkout(let generated):
                    FreshWorkoutPreviewSheet(generatedWorkout: generated) {
                        handleFreshWorkoutAccept(generated)
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var recoveryDict: [String: Int] {
        var dict = [String: Int]()
        for status in dashboardViewModel.recoveryStatus { dict[status.muscleGroup] = status.recoveryPercentage }
        return dict
    }
    
    private var selectedMuscleInfo: MuscleCountDTO? {
        guard let selectedChartMuscle else { return nil }
        return dashboardViewModel.dashboardMuscleData.first(where: { $0.muscle == selectedChartMuscle })
    }
    
    // MARK: - View Sections
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.strengthtraining.traditional").font(.system(size: 80)).foregroundColor(.blue.opacity(0.8))
            Text(LocalizedStringKey("Welcome to WorkoutTracker!")).font(.title2).bold()
            Text(LocalizedStringKey("Your journey starts here. Create your first workout to begin tracking.")).font(.body).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
            
            Button {
                router.present(.addWorkout)
                if tutorialManager.currentStep == .tapPlus { tutorialManager.nextStep() }
            } label: {
                Text(LocalizedStringKey("Start Your First Workout"))
                    .font(.title3).bold().foregroundColor(.white).padding(.vertical, 20).frame(maxWidth: .infinity)
                    .background(Color.blue).cornerRadius(16)
                    .shadow(color: .blue.opacity(0.6), radius: isPulsing ? 15 : 5, x: 0, y: isPulsing ? 8 : 2)
                    .scaleEffect(isPulsing ? 1.03 : 0.97)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)
            }
            .padding(.top, 10)
            .onAppear { Task { @MainActor in try? await Task.sleep(nanoseconds: 100_000_000); isPulsing = true } }
            .onDisappear { isPulsing = false }
            .spotlight(step: .tapPlus, manager: tutorialManager, text: "Tap here to create your first workout!", alignment: .top, yOffset: -10)
        }
        .padding(24).background(Color(UIColor.secondarySystemBackground)).cornerRadius(20).padding(.top, 10)
    }

    private var recoverySection: some View {
            VStack(alignment: .leading, spacing: 10) {
                // ✅ FIX: Заменяем NavigationLink на Button с вызовом роутера
                Button {
                    router.push(.detailedRecovery)
                } label: {
                    HStack {
                        Text(LocalizedStringKey("Muscle Recovery")).font(.headline).foregroundColor(.primary)
                        Spacer()
                        Text(LocalizedStringKey("See details")).font(.caption).foregroundColor(.blue)
                        Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .simultaneousGesture(TapGesture().onEnded { if tutorialManager.currentStep == .recoveryCheck { tutorialManager.nextStep() } })
                
                Divider()
                if recentWorkouts.isEmpty {
                               Text(LocalizedStringKey("Complete a workout to see data")).font(.caption).foregroundColor(.secondary)
                           } else {
                               BodyHeatmapView(muscleIntensities: recoveryDict, isRecoveryMode: true, userGender: userGender)
                           
                }
            }
            .padding().background(Color.gray.opacity(0.1)).cornerRadius(12)
            .spotlight(step: .recoveryCheck, manager: tutorialManager, text: "Check your Muscle Recovery status here.", alignment: .top, yOffset: -10)
        }
    
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(LocalizedStringKey("Muscles Worked")).font(.headline).foregroundColor(.secondary)
                Spacer()
                Button { router.present(.muscleColor) } label: { Image(systemName: "gearshape.fill").font(.caption).foregroundColor(.secondary) }
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
                            Circle().fill(colorManager.getColor(for: item.muscle)).frame(width: 10, height: 10)
                                .opacity(selectedChartMuscle == nil || selectedChartMuscle == item.muscle ? 1.0 : 0.3)
                            Text(LocalizedStringKey(item.muscle)).font(.caption).fontWeight(selectedChartMuscle == item.muscle ? .bold : .regular)
                                .foregroundColor(selectedChartMuscle == item.muscle ? .primary : .secondary).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.easeInOut(duration: 0.2)) { selectedChartMuscle = selectedChartMuscle == item.muscle ? nil : item.muscle }
                        }
                    }
                }.padding(.top, 8).padding(.horizontal, 4)
            }
        }
        .padding().background(Color(UIColor.secondarySystemBackground)).cornerRadius(12)
        .spotlight(step: .highlightChart, manager: tutorialManager, text: "See which muscles you train the most.", alignment: .top, yOffset: -10)
    }
    
    private var topExercisesSection: some View {
          VStack(alignment: .leading, spacing: 10) {
              if !dashboardViewModel.dashboardTopExercises.isEmpty {
                  HStack {
                      Text(LocalizedStringKey("Exercises")).font(.title2).bold()
                      Spacer()
                      // ✅ FIX: Заменяем NavigationLink на Button с вызовом роутера
                      Button { router.push(.exercises) } label: { Text(LocalizedStringKey("See all")).font(.subheadline).foregroundColor(.blue) }
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
    
    @ViewBuilder
        private var proactiveAutopilotBanner: some View {
            if let proposal = dashboardViewModel.proactiveProposal {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                            .foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        Text("AI Autopilot")
                            .font(.headline)
                            .fontWeight(.heavy)
                            .foregroundColor(.primary)
                        Spacer()
                        ActiveWorkoutIndicator()
                    }
                    
                    // Context Message
                    Text(LocalizedStringKey(proposal.message))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // One-Tap Start Button
                    Button {
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        
                        // Блокируем двойное нажатие
                        dashboardViewModel.proactiveProposal = nil
                        
                        Task {
                            await workoutService.startGeneratedWorkout(proposal.workout)
                            if let newWorkout = await workoutService.fetchLatestWorkout() {
                                await MainActor.run {
                                    router.push(.workoutDetail(newWorkout))
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text("Start Now")
                                .font(.headline)
                            Image(systemName: "arrow.right.circle.fill")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(20)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(LinearGradient(colors: [.purple.opacity(0.5), .blue.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
            } else {
                           // Фолбэк, если AI не нашел явного паттерна (классическая кнопка)
                           Button(action: {
                               Task { // ✅ Обернули в Task, так как обращаемся к актору
                                   do {
                                       let currentCatalog = await ExerciseDatabaseService.shared.getCatalog()
                                       let generated = try WorkoutGenerationService.generateFreshWorkout(
                                           recoveryStatus: dashboardViewModel.recoveryStatus,
                                           catalog: currentCatalog // ✅ ИСПОЛЬЗУЕМ JSON КАТАЛОГ
                                       )
                                       await MainActor.run {
                                           router.present(.freshWorkout(generated))
                                       }
                                   } catch {
                                       await MainActor.run {
                                           di.appState.showError(title: String(localized: "Too Tired!"), message: error.localizedDescription)
                                       }
                                   }
                               }
                           }) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle().fill(Color.yellow.opacity(0.2)).frame(width: 44, height: 44)
                            Image(systemName: "bolt.fill").foregroundColor(.yellow).font(.title2)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("Fresh Muscle Workout")).font(.headline).foregroundColor(.primary)
                            Text(LocalizedStringKey("Generate a routine for fully recovered muscles")).font(.caption).foregroundColor(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray)
                    }
                    .padding().background(Color(UIColor.secondarySystemBackground)).cornerRadius(16).shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
            }
        } // ✅ ВОТ ЭТА СКОБКА БЫЛА ПРОПУЩЕНА В ТВОЕМ КОДЕ

        @ViewBuilder
        private func rankIcon(rank: Int) -> some View {
            ZStack {
                Circle().fill(rank == 1 ? Color.yellow : rank == 2 ? Color.gray : rank == 3 ? Color.brown : Color.blue.opacity(0.1)).frame(width: 30, height: 30)
                Text("\(rank)").font(.caption).bold().foregroundColor(rank <= 3 ? .white : .blue)
            }.padding(.trailing, 5)
        }
    // MARK: - Actions
    
    private func handleFreshWorkoutAccept(_ generated: GeneratedWorkout) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        let dto = GeneratedWorkoutDTO(
            title: generated.title,
            aiMessage: "",
            exercises: generated.exercises.map { ex in
                GeneratedExerciseDTO(
                    name: ex.name, muscleGroup: ex.muscleGroup, type: ex.type.rawValue,
                    sets: ex.setsCount, reps: ex.firstSetReps, recommendedWeightKg: ex.firstSetWeight > 0 ? ex.firstSetWeight : nil, restSeconds: nil
                )
            }
        )
        
        Task {
            await workoutService.startGeneratedWorkout(dto)
            if let newWorkout = await workoutService.fetchLatestWorkout() {
                await MainActor.run {
                    router.dismissSheet()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        router.push(.workoutDetail(newWorkout))
                    }
                }
            }
        }
    }
}

// MARK: - Fresh Workout Preview Models & Views (Без изменений)
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
                            Text(ex.muscleGroup).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(ex.setsCount) sets").foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("Ready to Train"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(LocalizedStringKey("Cancel")) { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                Button { onStart() } label: {
                    Text(LocalizedStringKey("Start Workout")).font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding().background(Color.blue).cornerRadius(12).shadow(radius: 5)
                }.padding().background(Color(UIColor.systemBackground).shadow(color: .black.opacity(0.1), radius: 5, y: -5))
            }
        }
    }
}
