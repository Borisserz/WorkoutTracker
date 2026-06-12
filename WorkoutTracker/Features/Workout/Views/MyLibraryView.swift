internal import SwiftUI
import SwiftData

struct MyLibraryView: View {
    @Environment(\.modelContext) private var context
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    
    @Query(filter: #Predicate<WorkoutPreset> { $0.isSystem == false }, sort: \WorkoutPreset.name)
    private var userPresets: [WorkoutPreset]
    
    @Query(filter: #Predicate<Workout> { $0.isFavorite == true }, sort: \Workout.date, order: .reverse)
    private var favoriteWorkouts: [Workout]
    
    var onItemTapped: (CarouselItemType) -> Void
    var onEdit: ((WorkoutPreset) -> Void)?
    var onDuplicate: ((WorkoutPreset) -> Void)?
    var onDelete: ((CarouselItemType) -> Void)?
    
    private var myRoutines: [WorkoutPreset] {
        userPresets.filter { ($0.folderName ?? "").isEmpty && $0.name != "Today's Plan" }
    }
    
    private var savedSingleRoutines: [WorkoutPreset] {
        userPresets.filter { $0.folderName == PresetService.savedRoutinesFolderName }
    }
    
    private var programFolders: [String: [WorkoutPreset]] {
        var dict = [String: [WorkoutPreset]]()
        let favStr = String(localized: "Favorites")
        for p in userPresets where !(p.folderName ?? "").isEmpty && p.folderName != PresetService.savedRoutinesFolderName && p.folderName != "HiddenFolder" && p.folderName != "Favorites" && p.folderName != favStr { 
            dict[p.folderName!, default: []].append(p)
        }
        return dict
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            if myRoutines.isEmpty && savedSingleRoutines.isEmpty && programFolders.isEmpty && favoriteWorkouts.isEmpty {
                VStack(spacing: 24) {
                    Spacer().frame(height: 60)
                    
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.purple.opacity(0.15), .blue.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    
                    VStack(spacing: 8) {
                        Text(LocalizedStringKey("Your Library is Empty"))
                            .font(.title2).bold()
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                        
                        Text(LocalizedStringKey("Add your first program to start your fitness journey."))
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    NavigationLink(destination: ProgramDiscoveryView()) {
                        HStack {
                            Text(LocalizedStringKey("Browse Catalog"))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 32)
                        .background(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
                        .clipShape(Capsule())
                        .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .padding(.top, 16)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(alignment: .leading, spacing: 32) {
                    if !myRoutines.isEmpty {
                        CarouselSectionView(
                            title: "My Programs", folderName: nil, items: myRoutines.map { .preset($0) },
                            onItemTapped: onItemTapped, onEdit: onEdit,
                            onDuplicate: onDuplicate, onDelete: onDelete
                        )
                    }
                    
                    if !savedSingleRoutines.isEmpty {
                        CarouselSectionView(
                            title: "Saved Workouts", folderName: PresetService.savedRoutinesFolderName, items: savedSingleRoutines.map { .preset($0) },
                            onItemTapped: onItemTapped, onEdit: onEdit,
                            onDuplicate: onDuplicate, onDelete: onDelete
                        )
                    }
                    
                    ForEach(programFolders.keys.sorted(), id: \.self) { folderName in
                        if let programRoutines = programFolders[folderName] {
                            CarouselSectionView(
                                title: LocalizedStringKey(folderName), folderName: folderName, items: programRoutines.map { .preset($0) },
                                onItemTapped: onItemTapped, onEdit: onEdit,
                                onDuplicate: onDuplicate, onDelete: onDelete
                            )
                        }
                    }
                    
                    if !favoriteWorkouts.isEmpty {
                        CarouselSectionView(
                            title: "Favorites", folderName: nil, items: favoriteWorkouts.map { .favorite($0) },
                            onItemTapped: onItemTapped, onEdit: nil, onDuplicate: nil, onDelete: onDelete
                        )
                    }
                    
                    Spacer(minLength: 80)
                }
                .padding(.top, 24)
            }
        }
        .navigationTitle(LocalizedStringKey("My Library"))
        .navigationBarTitleDisplayMode(.large)
        .background(colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground))
    }
}
