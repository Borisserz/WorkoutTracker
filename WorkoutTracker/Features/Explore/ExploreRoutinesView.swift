// ============================================================
// FILE: WorkoutTracker/Features/Explore/ExploreRoutinesView.swift
// ============================================================

internal import SwiftUI

enum ExploreTabType: Int {
    case programs = 0
    case singles = 1
}

@Observable
@MainActor
final class ExploreViewModel {
    var allPrograms: [WorkoutProgramDefinition] = MockProgramCatalog.shared.programs
    var searchDebouncer = SearchDebouncer()
    
    // Filters & Tabs
    var selectedTab: ExploreTabType = .programs
    var selectedLevel: ProgramLevel? = nil
    var selectedGoal: ProgramGoal? = nil
    var selectedEquipment: ProgramEquipment? = nil
    
    var filteredPrograms: [WorkoutProgramDefinition] {
        allPrograms.filter { program in
            // Filter by Tab Type
            let matchesTab = (selectedTab == .singles) ? program.isSingleRoutine : !program.isSingleRoutine
            
            // Text Search
            let matchesSearch = searchDebouncer.debouncedText.isEmpty || program.title.localizedCaseInsensitiveContains(searchDebouncer.debouncedText)
            
            // Sheet Filters
            let matchesLevel = selectedLevel == nil || program.level == selectedLevel
            let matchesGoal = selectedGoal == nil || program.goal == selectedGoal
            let matchesEquip = selectedEquipment == nil || program.equipment == selectedEquipment
            
            return matchesTab && matchesSearch && matchesLevel && matchesGoal && matchesEquip
        }
    }
    
    var activeFilterCount: Int {
        var count = 0
        if selectedLevel != nil { count += 1 }
        if selectedGoal != nil { count += 1 }
        if selectedEquipment != nil { count += 1 }
        return count
    }
    
    func clearFilters() {
        selectedLevel = nil
        selectedGoal = nil
        selectedEquipment = nil
    }
}

struct ExploreRoutinesView: View {
    @State private var viewModel = ExploreViewModel()
    @State private var showFilters = false
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Fixed Header Area
                VStack(spacing: 12) {
                    // Type Picker
                    Picker("Workout Type", selection: $viewModel.selectedTab) {
                        Text("Programs").tag(ExploreTabType.programs)
                        Text("Single Routines").tag(ExploreTabType.singles)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Search & Filter
                    HStack(spacing: 12) {
                        DebouncedSearchBar(debouncer: viewModel.searchDebouncer)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        
                        Button {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            showFilters = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.blue)
                                
                                if viewModel.activeFilterCount > 0 {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 14, height: 14)
                                        .overlay(Text("\(viewModel.activeFilterCount)").font(.system(size: 9, weight: .bold)).foregroundColor(.white))
                                        .offset(x: 2, y: -2)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .background(Color(UIColor.systemGroupedBackground))
                .zIndex(1)
                
                // Scrollable Storefront
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        if viewModel.filteredPrograms.isEmpty {
                            EmptyStateView(
                                icon: "magnifyingglass",
                                title: "No routines found",
                                message: "Try adjusting your search or clearing your filters."
                            )
                            .padding(.top, 40)
                        } else {
                            LazyVStack(spacing: 20) {
                                ForEach(viewModel.filteredPrograms) { program in
                                    NavigationLink(destination: ProgramDetailView(program: program)) {
                                        PremiumProgramCardView(program: program)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 16)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("Explore")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFilters) {
            ExploreFiltersSheet(viewModel: viewModel)
        }
    }
}
