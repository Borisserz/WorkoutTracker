//
//  HistoryView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 5.04.26.
//

//
//  HistoryView.swift
//  WorkoutTracker
//

internal import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(DIContainer.self) private var di
    @Environment(\.modelContext) private var context
    @Environment(WorkoutService.self) var workoutService
    @Environment(UnitsManager.self) var unitsManager
    @Environment(DashboardViewModel.self) var dashboardViewModel
    
    @State private var searchDebouncer = SearchDebouncer()
    @State private var selectedFilter: FilterPeriod = .all
    @State private var sortOption: SortOption = .dateDescending
    @State private var showFavoritesOnly = false
    @State private var listViewModel = WorkoutListViewModel()
    
    enum FilterPeriod: String, CaseIterable {
        case all = "All Time", week = "Last Week", month = "Last Month", threeMonths = "Last 3 Months", year = "Last Year"
    }
    
    enum SortOption: String, CaseIterable {
        case dateDescending = "Newest First", dateAscending = "Oldest First", durationDescending = "Longest First"
        case durationAscending = "Shortest First", effortDescending = "Highest Effort", effortAscending = "Lowest Effort"
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section { statsSection }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                
                Section { searchAndFiltersSection }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                
                Section {
                    DynamicWorkoutListView(
                        searchText: searchDebouncer.debouncedText,
                        filter: WorkoutView.FilterPeriod(rawValue: selectedFilter.rawValue) ?? .all,
                        sort: WorkoutView.SortOption(rawValue: sortOption.rawValue) ?? .dateDescending,
                        favoritesOnly: showFavoritesOnly,
                        listViewModel: listViewModel,
                        onFirstWorkoutLoaded: nil
                    )
                }
                .listRowInsets(EdgeInsets())
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .navigationTitle(LocalizedStringKey("History"))
        }
    }
    
    private var statsSection: some View {
        HStack(spacing: 12) {
            StatCard(title: LocalizedStringKey("Avg Duration"), value: "\(listViewModel.calculatedAvgDuration)", subtitle: LocalizedStringKey("min"), icon: "stopwatch")
            StatCard(title: LocalizedStringKey("Avg Volume"), value: "\(Int(unitsManager.convertFromKilograms(Double(listViewModel.calculatedAvgVolume))))", subtitle: LocalizedStringKey(unitsManager.weightUnitString()), icon: "scalemass")
        }
        .padding(.horizontal).padding(.top, 8).padding(.bottom, 8)
    }
    
    private var searchAndFiltersSection: some View {
        VStack(spacing: 12) {
            Picker(LocalizedStringKey("View Mode"), selection: $showFavoritesOnly) {
                Text(LocalizedStringKey("All Workouts")).tag(false)
                Text(LocalizedStringKey("Favorites")).tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            DebouncedSearchBar(debouncer: searchDebouncer)
                .padding().background(Color(UIColor.secondarySystemBackground)).cornerRadius(12).padding(.horizontal)
            
            HStack(spacing: 12) {
                Menu { ForEach(FilterPeriod.allCases, id: \.self) { period in Button(LocalizedStringKey(period.rawValue)) { selectedFilter = period } } } label: {
                    HStack { Image(systemName: "calendar"); Text(LocalizedStringKey(selectedFilter.rawValue)) }
                        .font(.subheadline).padding(.horizontal, 12).padding(.vertical, 8).background(Color(UIColor.secondarySystemBackground)).cornerRadius(8)
                }
                Menu { ForEach(SortOption.allCases, id: \.self) { option in Button(LocalizedStringKey(option.rawValue)) { sortOption = option } } } label: {
                    HStack { Image(systemName: "arrow.up.arrow.down"); Text(LocalizedStringKey(sortOption.rawValue)) }
                        .font(.subheadline).padding(.horizontal, 12).padding(.vertical, 8).background(Color(UIColor.secondarySystemBackground)).cornerRadius(8)
                }
            }
            .padding(.horizontal).padding(.bottom, 8)
        }
    }
}
