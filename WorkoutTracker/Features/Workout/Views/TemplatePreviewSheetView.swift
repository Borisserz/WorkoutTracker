

internal import SwiftUI
import SwiftData

enum PreviewItem: Identifiable, Hashable {
    case preset(WorkoutPreset)
    case favorite(Workout)

    var id: String {
        switch self {
        case .preset(let p): return "preset_\(p.persistentModelID.hashValue)"
        case .favorite(let w): return "fav_\(w.persistentModelID.hashValue)"
        }
    }

    var title: String {
        switch self {
        case .preset(let p): return p.name
        case .favorite(let w): return w.title
        }
    }

    var icon: String {
        switch self {
        case .preset(let p): return p.icon
        case .favorite(let w): return w.icon
        }
    }

    var exercises: [Exercise] {
        switch self {
        case .preset(let p): return p.exercises
        case .favorite(let w): return w.exercises
        }
    }

    var isSystemIcon: Bool {
        switch self {
        case .preset(let p): return p.isSystem
        case .favorite: return true
        }
    }
}

struct TemplatePreviewSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UnitsManager.self) private var unitsManager
    @Environment(\.colorScheme) private var colorScheme 
    @Environment(ThemeManager.self) private var themeManager
    @State private var isSharing = false
        @State private var shareItem: SharedFileWrapper?
    @State private var selectedHistoryExercise: String? = nil
    @AppStorage(UGCConsent.storageKey) private var hasAcceptedUGCTerms = false
    @State private var showTermsGate = false
    let item: PreviewItem
    let onStart: () -> Void

    private var targetMuscles: [String] {
        let allMuscles = item.exercises.map { $0.muscleGroup }
        return Array(Set(allMuscles)).sorted()
    }
    
    private var gradientColors: [Color] {
        var hash = 5381
        for char in item.title.utf8 {
            hash = (hash &<< 5) &+ hash &+ Int(char)
        }
        let hashAbs = abs(hash)
        let hue1 = Double(hashAbs % 360) / 360.0
        let hue2 = Double((hashAbs + 45) % 360) / 360.0
        let c1 = Color(hue: hue1, saturation: 0.8, brightness: colorScheme == .dark ? 0.7 : 0.9)
        let c2 = Color(hue: hue2, saturation: 0.9, brightness: colorScheme == .dark ? 0.4 : 0.8)
        return [c1, c2]
    }
    
    private var totalSets: Int {
        item.exercises.reduce(0) { $0 + $1.setsCount }
    }
    
    private var estimatedMinutes: Int {
        // Assume roughly 2 minutes per set (including rest)
        let sets = totalSets
        return sets > 0 ? sets * 2 : 5
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {

                (colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color(UIColor.secondarySystemBackground)).ignoresSafeArea()

                // Dynamic Ambient Background
                GeometryReader { geo in
                    Circle()
                        .fill(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .opacity(colorScheme == .dark ? 0.15 : 0.08)
                        .blur(radius: 60)
                        .frame(width: geo.size.width * 1.5, height: geo.size.width * 1.5)
                        .offset(x: -geo.size.width * 0.25, y: -geo.size.width * 0.5)
                }
                .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        headerSection
                        
                        statsRowSection
                        
                        tagsSection

                        Divider()
                            .padding(.horizontal)
                            .opacity(0.5)

                        exercisesListSection
                    }
                    .padding(.bottom, 120)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                              ToolbarItem(placement: .topBarLeading) {
                                  Button {
                                      attemptShare()
                                  } label: {
                                      if isSharing {
                                          ProgressView().tint(themeManager.current.primaryAccent)
                                      } else {
                                          Image(systemName: "square.and.arrow.up")
                                              .font(.title3)
                                              .foregroundColor(themeManager.current.primaryAccent)
                                      }
                                  }
                                  .disabled(isSharing)
                              }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(colorScheme == .dark ? Color(UIColor.tertiarySystemFill) : .gray.opacity(0.5)) 
                    }
                }
            }
            .sheet(item: $shareItem) { wrapper in
                           ActivityViewController(activityItems: [wrapper.url])
                               .presentationDetents([.medium])
                       }
            .sheet(isPresented: $showTermsGate) {
                CommunityGuidelinesSheet {
                    shareWorkout()
                }
            }
            .safeAreaInset(edge: .bottom) {
                startWorkoutButton
            }
            .navigationDestination(item: $selectedHistoryExercise) { exName in
                ExerciseHistoryView(exerciseName: exName)
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 80, height: 80)
                    .blur(radius: 20)
                    .opacity(0.6)

                ZStack {
                    Circle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.white)
                        .frame(width: 88, height: 88)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            Circle()
                                .stroke(LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                        )
                        .shadow(color: gradientColors[0].opacity(0.3), radius: 15, x: 0, y: 8)

                    if item.isSystemIcon {
                        Image(systemName: item.icon)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    } else if UIImage(named: item.icon) != nil {
                        Image(item.icon)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 44, height: 44)
                            .foregroundStyle(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    } else {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                }
            }
            .padding(.top, 24)

            VStack(spacing: 6) {
                Text(LocalizedStringKey(item.title))
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
    
    private var statsRowSection: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "stopwatch.fill")
                Text(LocalizedStringKey("~\(estimatedMinutes) min"))
            }
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.2))
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            
            HStack(spacing: 6) {
                Image(systemName: "list.number")
                Text(LocalizedStringKey("\(item.exercises.count) exercises"))
            }
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.2))
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            
            if totalSets > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "repeat")
                    Text(LocalizedStringKey("\(totalSets) sets"))
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.2))
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var tagsSection: some View {
        if !targetMuscles.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Spacer().frame(width: 10)

                    ForEach(targetMuscles, id: \.self) { muscle in
                        Text(LocalizedStringKey(muscle))
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .textCase(.uppercase)
                            .foregroundColor(gradientColors[0])
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(gradientColors[0].opacity(0.15))
                            .overlay(Capsule().stroke(gradientColors[0].opacity(0.3), lineWidth: 1))
                            .clipShape(Capsule())
                    }

                    Spacer().frame(width: 10)
                }
            }
        }
    }

    private var exercisesListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedStringKey("Workout Structure"))
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                .padding(.horizontal)

            VStack(spacing: 12) {
                ForEach(item.exercises) { exercise in
                    Button {
                        selectedHistoryExercise = exercise.name
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing).opacity(0.15))
                                    .frame(width: 54, height: 54)

                                Image(systemName: exercise.type == .cardio ? "figure.run" : "dumbbell.fill")
                                    .font(.title2)
                                    .foregroundStyle(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                            }

                            VStack(alignment: .leading, spacing: 6) {

                                Text(LocalizationHelper.shared.translateName(exercise.name))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                    .lineLimit(1)

                                HStack(spacing: 8) {
                                    HStack(spacing: 2) {
                                        Text(LocalizedStringKey("\(exercise.setsCount) sets"))
                                        Text("×")
                                        Text(LocalizedStringKey("\(exercise.firstSetReps) reps"))
                                    }
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)

                                    if exercise.type == .strength && exercise.firstSetWeight > 0 {
                                        Text("•")
                                            .foregroundColor(.gray.opacity(0.5))
                                        let weight = unitsManager.convertFromKilograms(exercise.firstSetWeight)
                                        Text("\(LocalizationHelper.shared.formatFlexible(weight)) \(unitsManager.weightUnitString())")
                                            .font(.system(size: 13, weight: .black, design: .rounded))
                                            .foregroundStyle(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                    }
                                }
                            }

                            Spacer()
                        }
                        .padding(12)
                        .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05), lineWidth: 1)
                        )
                        .shadow(color: gradientColors[0].opacity(colorScheme == .dark ? 0.1 : 0.05), radius: 8, x: 0, y: 4)
                        .padding(.horizontal)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var startWorkoutButton: some View {
        Button {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            dismiss()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onStart()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.title2)
                Text(LocalizedStringKey("Start Workout"))
                    .font(.system(size: 20, weight: .black, design: .rounded))
            }
            .foregroundColor(.white) 
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            ) 
            .cornerRadius(20)
            .shadow(color: gradientColors[0].opacity(0.4), radius: 15, x: 0, y: 8)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .background(

            LinearGradient(colors: [(colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color(UIColor.secondarySystemBackground)), (colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color(UIColor.secondarySystemBackground)).opacity(0.0)], startPoint: .bottom, endPoint: .top)
                .ignoresSafeArea()
        )
    }
    private func attemptShare() {
        if hasAcceptedUGCTerms {
            shareWorkout()
        } else {
            showTermsGate = true
        }
    }
    private func shareWorkout() {
            isSharing = true
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            Task {
                do {
                 
                    let dto: WorkoutPresetDTO
                    switch item {
                    case .preset(let p): dto = p.toDTO()
                    case .favorite(let w):
                        let cleanExercises = w.exercises.map { ex -> ExerciseDTO in
                            var exDto = ex.toDTO()
                            exDto.isCompleted = false
                            exDto.setsList = exDto.setsList?.map { set in
                                WorkoutSetDTO(index: set.index, weight: set.weight, reps: set.reps, distance: set.distance, time: set.time, isCompleted: false, type: set.type)
                            }
                            return exDto
                        }
                        dto = WorkoutPresetDTO(name: w.title, icon: w.icon, folderName: nil, exercises: cleanExercises)
                    }
                    let uploadResult = try await FirestoreProgramService.shared.uploadSharedPreset(dto)

                    let workoutId: String
                    switch uploadResult {
                    case .approved(let id):
                        workoutId = id
                    case .pending(let id):
 
                        workoutId = id
                    }

                    if let shareURL = URL(string: "workouttracker://shared?id=\(workoutId)") {
                        await MainActor.run {
                            self.shareItem = SharedFileWrapper(url: shareURL)
                            self.isSharing = false
                        }
                    }
                } catch {
                    print("❌ The sharing error: \(error)")
                    await MainActor.run { self.isSharing = false }
                }
            }
        }
}
