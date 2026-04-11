//
//  RoutineCardView.swift
//  WorkoutTracker
//

internal import SwiftUI

struct PremiumRoutineCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let preset: WorkoutPreset
    let onStart: () -> Void
    var onEdit: (() -> Void)? = nil
    var onDuplicate: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil // ✅ ДОБАВЛЕНО
    
        @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(preset.name))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.current.primaryText)
                        .lineLimit(1)
                    
                    Text(exercisesPreviewText)
                        .font(.subheadline)
                        .foregroundColor(themeManager.current.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 10)
                
                // ✅ ИСПРАВЛЕНИЕ: Расширенное меню действий
                Menu {
                    if let onEdit = onEdit {
                        Button(action: onEdit) {
                            Label(LocalizedStringKey("Edit Template"), systemImage: "pencil")
                        }
                    }
                    
                    if let onDuplicate = onDuplicate {
                        Button(action: onDuplicate) {
                            // Умный нейминг в зависимости от того, системный это пресет или нет
                            Label(
                                preset.isSystem ? LocalizedStringKey("Save to My Routines") : LocalizedStringKey("Duplicate"),
                                systemImage: "plus.square.on.square"
                            )
                        }
                    }
                    
                    // Деструктивное действие всегда идет последним
                    if let onDelete = onDelete {
                        Button(role: .destructive, action: onDelete) {
                            Label(LocalizedStringKey("Delete"), systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3)
                        .foregroundColor(themeManager.current.primaryText)
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .highPriorityGesture(TapGesture().onEnded { })
            }
            
            Spacer(minLength: 8)
            
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                onStart()
            }) {
                Text(LocalizedStringKey("Start Routine"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.current.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(themeManager.current.primaryAccent)
                    .cornerRadius(10)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(colorScheme == .dark ? themeManager.current.surface : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 8, x: 0, y: 4)
        .compositingGroup()
    }
    
    private var exercisesPreviewText: String {
        if preset.exercises.isEmpty { return String(localized: "No exercises") }
        // 👈 Добавили прогон через LocalizationHelper
        return preset.exercises.map { LocalizationHelper.shared.translateName($0.name) }.joined(separator: ", ")
    }
}
