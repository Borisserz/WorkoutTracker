//
//  ThemeSettingsView.swift
//  WorkoutTracker
//
//  Theme selection settings screen with live preview.
//

internal import SwiftUI

// ============================================================
// THEME SETTINGS VIEW
// ============================================================

struct ThemeSettingsView: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        ZStack {
            themeManager.current.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Appearance")
                        .font(.title.weight(.bold))
                        .foregroundColor(themeManager.current.background)
                    
                    Text("Choose your favorite theme")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(themeManager.current.premiumGradient)
                
                // Theme Options
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(AppThemeType.allCases, id: \.self) { themeType in
                            ThemeOptionCard(
                                themeType: themeType,
                                isSelected: themeManager.activeThemeType == themeType,
                                onSelect: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        themeManager.setTheme(themeType)
                                    }
                                }
                            )
                        }
                    }
                    .padding(16)
                }
                
                // Live Preview Section
                VStack(spacing: 12) {
                    Text("Preview")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(themeManager.current.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ThemePreviewCard()
                }
                .padding(16)
                .background(themeManager.current.surface)
                .cornerRadius(12)
                .padding(16)
                
                Spacer()
            }
        }
        .withThemeTransition()
    }
}

// ============================================================
// THEME OPTION CARD
// ============================================================

private struct ThemeOptionCard: View {
    let themeType: AppThemeType
    let isSelected: Bool
    let onSelect: () -> Void
    
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Color preview circles
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: colorHex1))
                        .frame(width: 28, height: 28)
                    
                    Circle()
                        .fill(Color(hex: colorHex2))
                        .frame(width: 28, height: 28)
                    
                    Circle()
                        .fill(Color(hex: colorHex3))
                        .frame(width: 28, height: 28)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(themeType.rawValue)
                        .font(.body.weight(.semibold))
                        .foregroundColor(themeManager.current.primaryText)
                    
                    Text(themeSubtitle)
                        .font(.caption)
                        .foregroundColor(themeManager.current.secondaryText)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(themeManager.current.primaryAccent)
                } else {
                    Image(systemName: "circle")
                        .font(.title3)
                        .foregroundColor(themeManager.current.secondaryAccent)
                }
            }
            .padding(16)
            .background(isSelected ? themeManager.current.surfaceVariant : themeManager.current.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? themeManager.current.primaryAccent : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .withThemeTransition()
    }
    
    private var themeSubtitle: String {
        switch themeType {
        case .classic:
            return "Apple system colors • Dark/Light mode"
        case .amethyst:
            return "Purple palette • Modern & elegant"
        case .coralTeal:
            return "Vibrant coral + teal • Bold & energetic"
        }
    }
    
    private var colorHex1: String {
        switch themeType {
        case .classic:
            return "007AFF"  // System Blue
        case .amethyst:
            return "9C93E5"  // Soft Periwinkle
        case .coralTeal:
            return "ED717A"  // Coral-Red
        }
    }
    
    private var colorHex2: String {
        switch themeType {
        case .classic:
            return "5AC8FA"  // System Cyan
        case .amethyst:
            return "C7A3D2"  // Light Lilac
        case .coralTeal:
            return "F5AD92"  // Light Coral
        }
    }
    
    private var colorHex3: String {
        switch themeType {
        case .classic:
            return "A2845E"  // System Gray
        case .amethyst:
            return "7F4EA8"  // Deep Violet
        case .coralTeal:
            return "00577F"  // Deep Teal
        }
    }
}

// ============================================================
// THEME PREVIEW CARD
// ============================================================

private struct ThemePreviewCard: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(spacing: 12) {
            // Text samples
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Primary Text")
                        .font(.caption)
                        .foregroundColor(themeManager.current.primaryText)
                    
                    Text("Secondary Text")
                        .font(.caption)
                        .foregroundColor(themeManager.current.secondaryText)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Success")
                        .font(.caption)
                        .foregroundColor(themeManager.current.successColor)
                    
                    Text("Error")
                        .font(.caption)
                        .foregroundColor(themeManager.current.errorColor)
                }
            }
            
            Divider()
                .background(themeManager.current.secondaryAccent.opacity(0.3))
            
            // Button samples
            HStack(spacing: 12) {
                Button(action: {}) {
                    Text("Primary")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(themeManager.current.background)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(themeManager.current.primaryAccent)
                        .cornerRadius(6)
                }
                
                Button(action: {}) {
                    Text("Secondary")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(themeManager.current.primaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(themeManager.current.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(
                                    themeManager.current.secondaryAccent.opacity(0.5),
                                    lineWidth: 1
                                )
                        )
                }
                
                Spacer()
            }
        }
        .padding(12)
        .background(themeManager.current.background)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    themeManager.current.secondaryAccent.opacity(0.2),
                    lineWidth: 1
                )
        )
        .cornerRadius(8)
        .withThemeTransition()
    }
}

// ============================================================
// SIMPLIFIED SETTINGS ROW (For Settings Screen Integration)
// ============================================================

/// Drop this into your main Settings view
struct ThemeSelectionRow: View {
    @State private var showThemeSelector = false
    
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        Button(action: { showThemeSelector = true }) {
            HStack {
                Label("Theme", systemImage: "paintpalette.fill")
                    .foregroundColor(themeManager.current.primaryText)
                
                Spacer()
                
                Text(themeManager.activeThemeType.rawValue)
                    .foregroundColor(themeManager.current.secondaryText)
                
                Image(systemName: "chevron.right")
                    .foregroundColor(themeManager.current.secondaryAccent)
            }
            .padding(12)
            .background(themeManager.current.surface)
            .cornerRadius(8)
        }
        .sheet(isPresented: $showThemeSelector) {
            ThemeSettingsView()
        }
    }
}

// ============================================================
// PREVIEW
// ============================================================

#Preview("Theme Settings") {
    ThemeSettingsView()
}

#Preview("Theme Selection Row") {
    ThemeSelectionRow()
        .padding()
        .background(ThemeManager.shared.current.background)
        .environment(ThemeManager.shared)
}
