//
//  ExerciseView.swift
//  WorkoutTracker
//

internal import SwiftUI
import SwiftData

struct ExerciseView: View {
    @Environment(\.modelContext) private var context
    @Environment(CatalogViewModel.self) var catalogViewModel
    @State private var showAddSheet = false
    @State private var selectedGroups: Set<String>
    @State private var searchText: String
    @State private var showDeleteAlert = false
    @State private var exercisesToDelete: [(name: String, category: String)] = []
    
    init(preselectedCategory: String? = nil) {
        if let category = preselectedCategory { _selectedGroups = State(initialValue: [category]) } else { _selectedGroups = State(initialValue: []) }
        _searchText = State(initialValue: "")
    }
    
    var body: some View {
       
            VStack(spacing: 0) {
                searchBar
                muscleGroupFilter
                
                if hasAnyFilteredExercises {
                    List {
                        ForEach(filteredCategories, id: \.self) { group in
                            let exercises = filteredExercises(for: group)
                            if !exercises.isEmpty {
                                Section(header: Text(LocalizedStringKey(group))) {
                                    ForEach(exercises, id: \.self) { exerciseName in
                                        NavigationLink(destination: ExerciseHistoryView(exerciseName: exerciseName)) {
                                            exerciseRow(name: exerciseName)
                                        }
                                    }
                                    .onDelete { indexSet in
                                        let toDelete = indexSet.map { (name: exercises[$0], category: group) }
                                        exercisesToDelete = toDelete
                                        showDeleteAlert = true
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass").font(.system(size: 60)).foregroundColor(.gray.opacity(0.5))
                        Text(LocalizedStringKey("No exercises found")).font(.headline).foregroundColor(.primary)
                        Text(LocalizedStringKey("Try adjusting search or filters")).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity).padding(.vertical, 40)
                }
            }
            .navigationTitle(LocalizedStringKey("Exercise Catalog"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button { showAddSheet = true } label: { Image(systemName: "plus").font(.system(size: 18, weight: .semibold)) } }
                ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
            }
            .sheet(isPresented: $showAddSheet) { AddNewExerciseView() }
            .alert(LocalizedStringKey("Delete Exercise?"), isPresented: $showDeleteAlert) {
                Button(LocalizedStringKey("Delete"), role: .destructive) { deleteExercises() }
                Button(LocalizedStringKey("Cancel"), role: .cancel) { exercisesToDelete = [] }
            } message: {
                Text(LocalizedStringKey("This action cannot be undone."))
            }
        
    }
    
    private func exerciseRow(name: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(LocalizedStringKey(name)).foregroundColor(.primary).font(.body)
                Spacer()
                if catalogViewModel.isCustomExercise(name: name) { Image(systemName: "person.crop.circle").foregroundColor(.blue).font(.caption) }
            }
            if let category = getCategory(for: name) {
                let targetMuscles = MuscleDisplayHelper.getTargetMuscleNames(for: name, muscleGroup: category)
                if !targetMuscles.isEmpty {
                    HStack(spacing: 4) { Image(systemName: "figure.strengthtraining.traditional").font(.caption2).foregroundColor(.secondary); Text(targetMuscles.joined(separator: ", ")).font(.caption).foregroundColor(.secondary).lineLimit(1) }
                }
            }
        }
    }
    
    private func getCategory(for exerciseName: String) -> String? {
        for (category, exercises) in catalogViewModel.combinedCatalog { if exercises.contains(exerciseName) { return category } }
        return nil
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField(LocalizedStringKey("Search exercises"), text: $searchText).textFieldStyle(PlainTextFieldStyle())
            if !searchText.isEmpty { Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.secondary) } }
        }
        .padding(.horizontal, 16).padding(.vertical, 10).background(Color(.systemGray6)).cornerRadius(10).padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 8)
    }
    
    private var muscleGroupFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                filterButton(title: "All", isSelected: selectedGroups.isEmpty, action: { selectedGroups.removeAll() })
                ForEach(sortedCategories, id: \.self) { group in filterButton(title: group, isSelected: selectedGroups.contains(group), action: { if selectedGroups.contains(group) { selectedGroups.remove(group) } else { selectedGroups.insert(group) } }) }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }.background(Color(.systemGroupedBackground))
    }
    
    private func filterButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(LocalizedStringKey(title)).font(.system(size: 14, weight: isSelected ? .semibold : .regular)).foregroundColor(isSelected ? .white : .primary).padding(.horizontal, 16).padding(.vertical, 8).background(isSelected ? Color.accentColor : Color(.systemGray5)).cornerRadius(20) }
    }
    
    private var sortedCategories: [String] { catalogViewModel.combinedCatalog.keys.sorted() }
    private var filteredCategories: [String] { selectedGroups.isEmpty ? sortedCategories : sortedCategories.filter { selectedGroups.contains($0) } }
    private func sortedExercises(for group: String) -> [String] { catalogViewModel.combinedCatalog[group]?.sorted() ?? [] }
    private func filteredExercises(for group: String) -> [String] {
        let exercises = sortedExercises(for: group)
        return searchText.isEmpty ? exercises : exercises.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    private var hasAnyFilteredExercises: Bool {
        for group in filteredCategories { if !filteredExercises(for: group).isEmpty { return true } }
        return false
    }
    
    private func deleteExercises() {
        let items = exercisesToDelete
        exercisesToDelete = []
        // ✅ ИСПРАВЛЕНИЕ: Вызов асинхронного метода вынесен в Task внутри функции
        Task {
            for item in items {
                await catalogViewModel.deleteExercise(name: item.name, category: item.category)
            }
        }
    }
}
