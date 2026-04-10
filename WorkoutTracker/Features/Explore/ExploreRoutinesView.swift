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
    
    // ✅ ДОБАВЛЕНО: Состояние для вызова ИИ
    @State private var showAIBuilder = false
    
    // ✅ ДОБАВЛЕНО: Доступ к DIContainer для передачи aiLogicService
    @Environment(DIContainer.self) private var di
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Fixed Header Area
                VStack(spacing: 12) {
                    // Type Picker
                    Picker(LocalizedStringKey("Workout Type"), selection: $viewModel.selectedTab) {
                        Text(LocalizedStringKey("Programs")).tag(ExploreTabType.programs)
                        Text(LocalizedStringKey("Single Routines")).tag(ExploreTabType.singles)
                    }
                    .pickerStyle(.segmented) // ✅ Модификаторы теперь применяются прямо к Picker
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
                        
                        // ✅ ИСПРАВЛЕНО: Теперь кнопка меняет State
                        Button {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            showAIBuilder = true // Открываем шторку
                        } label: {
                            PremiumAIBannerView()
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .buttonStyle(.plain) // Убирает синюю подсветку при нажатии
                                
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
        // ✅ ДОБАВЛЕНО: Вызов самой шторки AI Program Builder
        .sheet(isPresented: $showAIBuilder) {
            AIProgramBuilderSheet(aiLogicService: di.aiLogicService)
        }
    }
}
// MARK: - Premium AI Banner
struct PremiumAIBannerView: View {
    var body: some View {
        HStack(spacing: 16) {
            // Иконка
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "wand.and.stars")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            // Тексты
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Program Architect")
                    .font(.headline)
                    .fontWeight(.heavy)
                    .foregroundColor(.white)
                
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
        // Жестко заданный насыщенный градиент (выглядит премиально в любой теме)
        .background(
            LinearGradient(
                colors: [Color(hex: "4A00E0"), Color(hex: "8E2DE2")], // Яркий фиолетовый к синему
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color(hex: "8E2DE2").opacity(0.4), radius: 15, x: 0, y: 8)
    }
}
