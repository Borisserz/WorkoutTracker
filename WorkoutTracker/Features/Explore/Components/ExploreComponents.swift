// ============================================================
// FILE: WorkoutTracker/Features/Explore/Components/ExploreComponents.swift
// ============================================================

internal import SwiftUI

// MARK: - Premium Program Card
struct PremiumProgramCardView: View {
    let program: WorkoutProgramDefinition
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Vibrant Gradient Background
            LinearGradient(
                colors: program.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Top Right Badges
            VStack(alignment: .trailing, spacing: 8) {
                HStack {
                    Spacer()
                    ProgramTag(text: program.level.rawValue, icon: "chart.bar.fill", color: .white)
                        .environment(\.colorScheme, .dark)
                }
                HStack {
                    Spacer()
                    // Adaptive Tag (Singles vs Programs)
                    if program.isSingleRoutine {
                        let exerciseCount = program.routines.first?.exercises.count ?? 0
                        ProgramTag(text: "\(exerciseCount) Exercises", icon: "list.bullet", color: .white)
                            .environment(\.colorScheme, .dark)
                    } else {
                        ProgramTag(text: "\(program.routines.count) Routines", icon: "square.stack.3d.up.fill", color: .white)
                            .environment(\.colorScheme, .dark)
                    }
                }
            }
            .padding(16)
            .frame(maxHeight: .infinity, alignment: .topTrailing)
            
            // Content Overlay (No Creator Text)
            VStack(alignment: .leading, spacing: 6) {
                Text(LocalizedStringKey(program.title))
                    .font(.title2)
                    .fontWeight(.heavy)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(LocalizedStringKey(program.description))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [.black.opacity(0.8), .clear], startPoint: .bottom, endPoint: .top)
            )
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: program.gradientColors.first!.opacity(0.4), radius: 15, x: 0, y: 8)
    }
}

// MARK: - Explore Filters Sheet
struct ExploreFiltersSheet: View {
    @Bindable var viewModel: ExploreViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        FilterSection(title: "Level", items: ProgramLevel.allCases, selection: $viewModel.selectedLevel)
                        FilterSection(title: "Goal", items: ProgramGoal.allCases, selection: $viewModel.selectedGoal)
                        FilterSection(title: "Equipment", items: ProgramEquipment.allCases, selection: $viewModel.selectedEquipment)
                    }
                    .padding(20)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") {
                        withAnimation { viewModel.clearFilters() }
                    }
                    .disabled(viewModel.activeFilterCount == 0)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    dismiss()
                } label: {
                    Text("Show \(viewModel.filteredPrograms.count) Results")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(themeManager.current.primaryAccent)
                        .cornerRadius(16)
                        .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                .background(
                    Color(UIColor.systemGroupedBackground)
                        .shadow(color: .black.opacity(0.05), radius: 10, y: -5)
                )
            }
        }
        .presentationDetents([.fraction(0.85), .large])
        .presentationDragIndicator(.visible)
    }
}

struct FilterSection<T: RawRepresentable & Identifiable & Equatable>: View where T.RawValue == String {
    let title: String
    let items: [T]
    @Binding var selection: T?
    @Environment(ThemeManager.self) private var themeManager
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey(title))
                .font(.headline)
                .foregroundColor(themeManager.current.primaryText)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    FilterChip(title: "Any", isSelected: selection == nil) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selection = nil }
                    }
                    ForEach(items) { item in
                        FilterChip(title: item.rawValue, isSelected: selection == item) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selection = item }
                        }
                    }
                }
            }
        }
    }
}
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme // 👈 ДОБАВЛЕНО

    var body: some View {
        Button(action: {
            let gen = UISelectionFeedbackGenerator()
            gen.selectionChanged()
            action()
        }) {
            Text(LocalizedStringKey(title))
                .font(.subheadline)
                .fontWeight(isSelected ? .bold : .medium)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                // 👈 АДАПТАЦИЯ: В светлой теме фон серый, в темной — темно-серый. При выборе — синий.
                .background(isSelected ? themeManager.current.primaryAccent : (colorScheme == .dark ? themeManager.current.surface : Color(UIColor.systemGray6)))
                .foregroundColor(isSelected ? .white : (colorScheme == .dark ? .white : .black))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? themeManager.current.primaryAccent : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
// MARK: - Reusable Tag Component
struct ProgramTag: View {
    let text: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(LocalizedStringKey(text))
                .font(.caption)
                .fontWeight(.bold)
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}
