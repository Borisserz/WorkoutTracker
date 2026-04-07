// ============================================================
// FILE: WorkoutTracker/Features/ExerciseCatalog/Views/ExerciseView.swift
// ============================================================

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
        if let category = preselectedCategory {
            _selectedGroups = State(initialValue: [category])
        } else {
            _selectedGroups = State(initialValue: [])
        }
        _searchText = State(initialValue: "")
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Премиальный фон
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Шапка с поиском и фильтрами
                searchBar
                muscleGroupFilter
                
                Divider().opacity(0.5)
                
                if hasAnyFilteredExercises {
                    List {
                        ForEach(filteredCategories, id: \.self) { group in
                            let exercises = filteredExercises(for: group)
                            if !exercises.isEmpty {
                                Section {
                                    ForEach(exercises, id: \.self) { exerciseName in
                                        ZStack(alignment: .leading) {
                                            // Карточка упражнения
                                            exerciseCard(name: exerciseName, category: group)
                                            
                                            // Невидимый NavigationLink, чтобы скрыть дефолтный шеврон списка
                                            // и сохранить кликабельность на всю карточку
                                            NavigationLink(destination: ExerciseHistoryView(exerciseName: exerciseName)) {
                                                EmptyView()
                                            }
                                            .opacity(0)
                                        }
                                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                    }
                                    .onDelete { indexSet in
                                        let toDelete = indexSet.map { (name: exercises[$0], category: group) }
                                        exercisesToDelete = toDelete
                                        showDeleteAlert = true
                                    }
                                } header: {
                                    Text(LocalizedStringKey(group))
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                        .textCase(nil)
                                        .padding(.horizontal, 0)
                                        .padding(.top, 16)
                                        .padding(.bottom, 4)
                                }
                                .listSectionSeparator(.hidden)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                } else {
                    emptyStateView
                }
            }
        }
        .navigationTitle(LocalizedStringKey("Exercise Catalog"))
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    let gen = UIImpactFeedbackGenerator(style: .medium)
                    gen.impactOccurred()
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus").font(.system(size: 18, weight: .semibold))
                }
            }
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
    
    // MARK: - View Components
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(LocalizedStringKey("Search exercises"), text: $searchText)
                .textFieldStyle(.plain)
                .font(.subheadline)
            
            if !searchText.isEmpty {
                Button {
                    let gen = UIImpactFeedbackGenerator(style: .light)
                    gen.impactOccurred()
                    withAnimation { searchText = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray.opacity(0.6))
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
                Spacer().frame(width: 8) // Левый отступ для совпадения с paddings карточек
                
                filterButton(title: "All", isSelected: selectedGroups.isEmpty) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedGroups.removeAll()
                    }
                }
                
                ForEach(sortedCategories, id: \.self) { group in
                    filterButton(title: group, isSelected: selectedGroups.contains(group)) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if selectedGroups.contains(group) {
                                selectedGroups.remove(group)
                            } else {
                                selectedGroups.insert(group)
                            }
                        }
                    }
                }
                
                Spacer().frame(width: 8)
            }
            .padding(.vertical, 12)
        }
    }
    
    private func filterButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            let gen = UISelectionFeedbackGenerator()
            gen.selectionChanged()
            action()
        } label: {
            Text(LocalizedStringKey(title))
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
                .shadow(color: isSelected ? Color.blue.opacity(0.2) : .clear, radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    private func exerciseCard(name: String, category: String) -> some View {
        let type = detectType(name: name, group: category)
        let color = getColor(for: type)
        let icon = getIcon(for: type)
        let isCustom = catalogViewModel.isCustomExercise(name: name)
        let targetMuscles = MuscleDisplayHelper.getTargetMuscleNames(for: name, muscleGroup: category)
        
        return HStack(spacing: 16) {
            // Иконка с подложкой
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(color)
            }
            
            // Текстовый блок
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Text(LocalizedStringKey(name))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if isCustom {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                }
                
                if !targetMuscles.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            
                            ForEach(targetMuscles, id: \.self) { muscle in
                                Text(LocalizedStringKey(muscle))
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.primary.opacity(0.06)) // Чуть более заметный фон тегов
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            
            Spacer(minLength: 8)
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(UIColor.tertiaryLabel))
        }
        .padding(.all, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(UIColor.systemBackground)) // Используем чистый белый/черный для контраста
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1) // Тонкая грань
        )
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4) // Глубокая мягкая тень
    }
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.4))
            
            Text(LocalizedStringKey("No exercises found"))
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(LocalizedStringKey("Try adjusting search or filters"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }
    
    // MARK: - Logic Helpers
    
    private var sortedCategories: [String] { catalogViewModel.combinedCatalog.keys.sorted() }
    private var filteredCategories: [String] { selectedGroups.isEmpty ? sortedCategories : sortedCategories.filter { selectedGroups.contains($0) } }
    private func sortedExercises(for group: String) -> [String] { catalogViewModel.combinedCatalog[group]?.sorted() ?? [] }
    
    private func filteredExercises(for group: String) -> [String] {
        let exercises = sortedExercises(for: group)
        return searchText.isEmpty ? exercises : exercises.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var hasAnyFilteredExercises: Bool {
        for group in filteredCategories {
            if !filteredExercises(for: group).isEmpty { return true }
        }
        return false
    }
    
    private func deleteExercises() {
        let items = exercisesToDelete
        exercisesToDelete = []
        Task {
            for item in items {
                await catalogViewModel.deleteExercise(name: item.name, category: item.category)
            }
        }
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
