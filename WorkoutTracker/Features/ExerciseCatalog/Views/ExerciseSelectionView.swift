internal import SwiftUI

struct ExerciseSelectionView: View {
    
    // MARK: - Environment & Bindings
    @Environment(TutorialManager.self) var tutorialManager
    @Environment(\.dismiss) private var dismiss
    @Environment(CatalogViewModel.self) private var catalogViewModel
    
    /// Замыкание для добавления нового упражнения
    var onAdd: (Exercise) -> Void
    
    // MARK: - State
    @State private var searchText: String = ""
    @State private var selectedGroups: Set<String> = []
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Премиальный фон
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Строка поиска
                    searchBar
                    
                    // Фильтр по группам мышц
                    muscleGroupFilter
                    
                    Divider().opacity(0.5)
                    
                    if hasAnyFilteredExercises {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 24) {
                                ForEach(filteredGroups, id: \.self) { group in
                                    let exercisesInGroup = getFilteredExercises(for: group)
                                    
                                    if !exercisesInGroup.isEmpty {
                                        VStack(alignment: .leading, spacing: 12) {
                                            Text(LocalizedStringKey(group))
                                                .font(.title3)
                                                .fontWeight(.bold)
                                                .foregroundColor(.primary)
                                                .padding(.horizontal, 20)
                                                .padding(.top, 8)
                                            
                                            VStack(spacing: 12) {
                                                ForEach(exercisesInGroup, id: \.self) { exerciseName in
                                                    let detectedType = detectType(name: exerciseName, group: group)
                                                    
                                                    NavigationLink {
                                                        ConfigureExerciseView(
                                                            exerciseName: exerciseName,
                                                            muscleGroup: group,
                                                            exerciseType: detectedType
                                                        ) { newExercise in
                                                            onAdd(newExercise)
                                                            dismiss()
                                                            if tutorialManager.currentStep == .addExercise {
                                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                                    tutorialManager.setStep(.finishExercise)
                                                                }
                                                            }
                                                        }
                                                    } label: {
                                                        exerciseCardView(name: exerciseName, type: detectedType, group: group)
                                                    }
                                                    .buttonStyle(.plain) // Чтобы вся карточка нажималась без синего текста
                                                }
                                            }
                                            .padding(.horizontal, 20)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 16)
                            .padding(.bottom, 40)
                        }
                    } else {
                        emptyStateView
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("Select Exercise"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Close")) { dismiss() }
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(LocalizedStringKey("Search exercises"), text: $searchText)
                .textFieldStyle(.plain)
                .font(.body)
            
            if !searchText.isEmpty {
                Button {
                    let gen = UIImpactFeedbackGenerator(style: .light)
                    gen.impactOccurred()
                    withAnimation { searchText = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.02), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    private var muscleGroupFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Spacer().frame(width: 8) // Отступ слева
                
                filterButton(
                    title: LocalizedStringKey("All"),
                    isSelected: selectedGroups.isEmpty,
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedGroups.removeAll()
                        }
                    }
                )
                
                ForEach(sortedCategories, id: \.self) { group in
                    filterButton(
                        title: LocalizedStringKey(group),
                        isSelected: selectedGroups.contains(group),
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if selectedGroups.contains(group) {
                                    selectedGroups.remove(group)
                                } else {
                                    selectedGroups.insert(group)
                                }
                            }
                        }
                    )
                }
                
                Spacer().frame(width: 8) // Отступ справа
            }
            .padding(.vertical, 12)
        }
    }
    
    private func filterButton(title: LocalizedStringKey, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            let gen = UISelectionFeedbackGenerator()
            gen.selectionChanged()
            action()
        } label: {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .bold : .medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(isSelected ? Color.blue : Color(UIColor.secondarySystemBackground))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.blue : Color.gray.opacity(0.2), lineWidth: 1)
                )
        }
    }
    
    private func exerciseCardView(name: String, type: ExerciseType, group: String) -> some View {
        HStack(spacing: 16) {
            // Иконка
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(getColor(for: type).opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: getIcon(for: type))
                    .font(.title3)
                    .foregroundColor(getColor(for: type))
            }
            
            // Тексты
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(LocalizedStringKey(name))
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if isCustom(name: name) {
                        Image(systemName: "person.crop.circle")
                            .foregroundColor(.gray.opacity(0.5))
                            .font(.caption)
                    }
                }
                
                let targetMuscles = MuscleDisplayHelper.getTargetMuscleNames(for: name, muscleGroup: group)
                if !targetMuscles.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.caption2)
                        Text(targetMuscles.joined(separator: ", "))
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.4))
            
            Text(LocalizedStringKey("No exercises found"))
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(searchText.isEmpty ? LocalizedStringKey("No exercises match the selected filters. Try selecting different muscle groups.") : LocalizedStringKey("No exercises match your search \"\(searchText)\". Try a different search term or clear the filters."))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }
    
    // MARK: - Logic (Untouched)
    
    private var sortedCategories: [String] {
        catalogViewModel.combinedCatalog.keys.sorted()
    }
    
    private func isCustom(name: String) -> Bool {
        return catalogViewModel.isCustomExercise(name: name)
    }
    
    private var filteredGroups: [String] {
        if selectedGroups.isEmpty { return sortedCategories }
        return sortedCategories.filter { selectedGroups.contains($0) }
    }
    
    private func getSortedExercises(for group: String) -> [String] {
        catalogViewModel.combinedCatalog[group]?.sorted() ?? []
    }
    
    private func getFilteredExercises(for group: String) -> [String] {
        let exercises = getSortedExercises(for: group)
        if searchText.isEmpty { return exercises }
        return exercises.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var hasAnyFilteredExercises: Bool {
        for group in filteredGroups {
            if !getFilteredExercises(for: group).isEmpty { return true }
        }
        return false
    }
    
    private func detectType(name: String, group: String) -> ExerciseType {
        if let custom = catalogViewModel.customExercises.first(where: { $0.name == name }) { return custom.type }
        if ["Running", "Cycling", "Rowing", "Jump Rope"].contains(name) { return .cardio }
        if ["Plank", "Stretching"].contains(name) { return .duration }
        if group == "Cardio" { return .cardio }
        return .strength
    }
    
    private func getIcon(for type: ExerciseType) -> String {
        switch type {
        case .strength: return "dumbbell.fill"
        case .cardio: return "figure.run"
        case .duration: return "stopwatch.fill"
        }
    }
    
    private func getColor(for type: ExerciseType) -> Color {
        switch type {
        case .strength: return .blue
        case .cardio: return .orange
        case .duration: return .purple
        }
    }
}
