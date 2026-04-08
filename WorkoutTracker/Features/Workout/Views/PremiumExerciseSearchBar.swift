//
//  PremiumExerciseSearchBar.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 8.04.26.
//

internal import SwiftUI

struct PremiumExerciseSearchBar: View {
    @Bindable var filterState: ExerciseFilterState
    var onFilterTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.body)
                
                TextField(LocalizedStringKey("Search exercises..."), text: $filterState.searchText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .autocorrectionDisabled()
                
                if !filterState.searchText.isEmpty {
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            filterState.searchText = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray.opacity(0.6))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
            )
            
            Button {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                onFilterTap()
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            filterState.activeAdvancedFiltersCount > 0
                            ? AnyShapeStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(Color.gray.opacity(0.3))
                        )
                        .background(Circle().fill(Color(UIColor.systemBackground)))
                    
                    if filterState.activeAdvancedFiltersCount > 0 {
                        Text("\(filterState.activeAdvancedFiltersCount)")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: 16, height: 16)
                            .background(Color.red)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color(UIColor.systemBackground), lineWidth: 2))
                            .offset(x: 4, y: -4)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}
