internal import SwiftUI

struct SisterAppTile: View {
    let app: SisterApp
    var showsGetChip: Bool = true
    var onTap: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    private var accentColor: Color {
        switch app.accent {
        case .peach: return PastelTheme.pastelPeach
        case .sage: return PastelTheme.pastelSage
        case .lavender: return PastelTheme.pastelLavender
        }
    }

    private var iconGradient: [Color] {
        switch app.accent {
        case .peach: return [PastelTheme.pastelPeach, PastelTheme.pastelAmber]
        case .sage: return [PastelTheme.pastelSage, PastelTheme.pastelSlate]
        case .lavender: return [PastelTheme.pastelLavender, PastelTheme.pastelPeach]
        }
    }

    var body: some View {
        Button {
            HapticManager.shared.impact(.light)
            if let onTap {
                onTap()
            } else {
                SisterAppStoreOpener.open(app)
            }
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: iconGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 56, height: 56)
                        .shadow(color: accentColor.opacity(0.35), radius: 8, y: 4)

                    Image(systemName: app.symbolName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(app.nameKey))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? .white : .black)

                    Text(LocalizedStringKey(app.taglineKey))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                if showsGetChip {
                    Text("Get")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 14)
                        .frame(height: 32)
                        .background(accentColor.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(colorScheme == .dark ? AnyShapeStyle(Color.white.opacity(0.05)) : AnyShapeStyle(Color.white))
                    .shadow(color: .black.opacity(0.06), radius: 10, y: 4)

                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(accentColor.opacity(0.35), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("wt.sister.\(app.id)")
    }
}
