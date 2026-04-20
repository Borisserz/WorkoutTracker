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
    @State private var showAIBuilder = false
    
    @Environment(ThemeManager.self) private var themeManager
    @Environment(DIContainer.self) private var di
    @Environment(\.colorScheme) private var colorScheme: ColorScheme // 👈 ИСПРАВЛЕНИЕ: Явное указание типа
    
    var body: some View {
        ZStack {
            // 👈 ИСПРАВЛЕНИЕ: Белый фон в светлой теме
            (colorScheme == .dark ? themeManager.current.background : Color.white)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - 1. Fixed Header Area
                VStack(spacing: 12) {
                    // Type Picker
                    Picker(LocalizedStringKey("Workout Type"), selection: $viewModel.selectedTab) {
                        Text(LocalizedStringKey("Программы")).tag(ExploreTabType.programs)
                        Text(LocalizedStringKey("Одиночные программы")).tag(ExploreTabType.singles)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Search & Filter Row
                    HStack(spacing: 12) {
                        DebouncedSearchBar(debouncer: viewModel.searchDebouncer)
                            .padding()
                            .background(colorScheme == .dark ? themeManager.current.surface : Color(UIColor.secondarySystemBackground))
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(colorScheme == .dark ? Color.clear : Color.black.opacity(0.05), lineWidth: 1))
                            .shadow(color: .black.opacity(colorScheme == .dark ? 0.05 : 0), radius: 5, x: 0, y: 2)
                        
                        Button {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            showFilters = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(colorScheme == .dark ? themeManager.current.primaryAccent : .blue)
                                
                                if viewModel.activeFilterCount > 0 {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 14, height: 14)
                                        .overlay(
                                            Text("\(viewModel.activeFilterCount)")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.white)
                                        )
                                        .offset(x: 2, y: -2)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .background(colorScheme == .dark ? themeManager.current.background : Color.white)
                .zIndex(1)
                
                // MARK: - 2. Scrollable Content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // NEW: Hall of Fame Entry (Golden Era Vibe)
                        NavigationLink(destination: LegendaryRoutinesView()) {
                            HallOfFameBanner()
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        .padding(.top, 16)
                        
                        // AI Program Builder Banner
                        Button {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            showAIBuilder = true
                        } label: {
                            PremiumAIBannerView()
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        
                        // Section Divider
                        Text(viewModel.selectedTab == .programs ? "All Programs" : "Single Routines")
                            .font(.headline)
                            .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                            .padding(.horizontal)
                            .padding(.top, 10)
                                
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
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("Исследовать")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFilters) {
            ExploreFiltersSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showAIBuilder) {
            AIProgramBuilderSheet(aiLogicService: di.aiLogicService)
        }
    }
}

// MARK: - Hall of Fame Banner (Sub-component)
struct HallOfFameBanner: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.2))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Hall of Fame")
                    .font(.headline)
                    .fontWeight(.heavy)
                    .foregroundColor(.white)
                
                Text("Train with legendary workout protocols.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.body.bold())
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(hex: "0F2027"), Color(hex: "203A43")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
    }
}

// MARK: - Premium AI Banner
struct PremiumAIBannerView: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "wand.and.stars")
                    .font(.title2)
                    .foregroundColor(themeManager.current.background)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Program Architect")
                    .font(.headline)
                    .fontWeight(.heavy)
                    .foregroundColor(themeManager.current.background)
                
                Text("Design your perfect weekly split.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.body.bold())
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(20)
        .background(themeManager.current.premiumGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: themeManager.current.deepPremiumAccent.opacity(0.4), radius: 15, x: 0, y: 8)
    }
}
