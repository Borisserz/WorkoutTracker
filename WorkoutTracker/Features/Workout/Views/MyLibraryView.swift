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
            VStack(alignment: .leading, spacing: 32) {
                CarouselSectionView(
                    title: "My Programs", folderName: nil, items: myRoutines.map { .preset($0) },
                    onItemTapped: onItemTapped, onEdit: onEdit,
                    onDuplicate: onDuplicate, onDelete: onDelete
                )
                
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
        .navigationTitle(LocalizedStringKey("My Library"))
        .navigationBarTitleDisplayMode(.large)
        .background(colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground))
    }
}
