internal import SwiftUI
import SwiftData

struct SmartWorkoutRoutinesListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    @Query(filter: #Predicate<WorkoutPreset> { $0.isSystem == false }, sort: \WorkoutPreset.name)
    private var userPresets: [WorkoutPreset]

    var onPresetTap: (WorkoutPreset) -> Void
    var onNewProgramTap: () -> Void
    var onExploreTap: () -> Void

    private var myRoutines: [WorkoutPreset] {
        userPresets.filter { $0.name != "Today's Plan" }
    }

    var body: some View {
        ZStack {
            (colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if myRoutines.isEmpty {
                    emptyStateSection
                } else {
                    routinesListSection
                }
            }
        }
        .navigationTitle(LocalizedStringKey("My Routines"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyStateSection: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "list.bullet.clipboard.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
            }
            .shadow(color: .green.opacity(0.2), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 8) {
                Text(LocalizedStringKey("No Routines Yet"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                Text(LocalizedStringKey("Create your own routine template or explore pre-made programs."))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            actionButtons
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }

    private var gridColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    }

    private var routinesListSection: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(myRoutines) { preset in
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        dismiss()
                        onPresetTap(preset)
                    } label: {
                        CompactPresetCardView(preset: preset)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            Spacer(minLength: 24)
            
            actionButtons
                .padding(.horizontal, 20)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                dismiss()
                onNewProgramTap()
            } label: {
                Text(LocalizedStringKey("Create Custom Routine"))
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(themeManager.current.primaryAccent)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            
            Button {
                dismiss()
                onExploreTap()
            } label: {
                Text(LocalizedStringKey("Browse Database"))
                    .font(.headline)
                    .foregroundColor(themeManager.current.primaryAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(themeManager.current.primaryAccent.opacity(0.1))
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }
}

struct CompactPresetCardView: View {
    let preset: WorkoutPreset
    @Environment(\.colorScheme) private var colorScheme
    
    private var cardGradients: [Color] {
        var hash = 0
        for char in preset.name.utf8 {
            hash = (hash &<< 5) &+ hash &+ Int(char)
        }
        let hashAbs = abs(hash)
        
        let hue1 = Double(hashAbs % 360) / 360.0
        let hue2 = Double((hashAbs + 45) % 360) / 360.0
        
        let c1 = Color(hue: hue1, saturation: 0.8, brightness: colorScheme == .dark ? 0.7 : 0.9)
        let c2 = Color(hue: hue2, saturation: 0.9, brightness: colorScheme == .dark ? 0.4 : 0.8)
        return [c1, c2]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(colors: cardGradients, startPoint: .topLeading, endPoint: .bottomTrailing).opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    if preset.isSystem {
                        Image(systemName: preset.icon.isEmpty ? "dumbbell.fill" : preset.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(LinearGradient(colors: cardGradients, startPoint: .topLeading, endPoint: .bottomTrailing))
                    } else if UIImage(named: preset.icon) != nil {
                        Image(preset.icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                    } else {
                        Image(systemName: preset.icon.isEmpty ? "dumbbell.fill" : preset.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(LinearGradient(colors: cardGradients, startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                }
                Spacer()
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.leading)
                
                Text(LocalizedStringKey("\(preset.exercises.count) exercises"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .aspectRatio(1, contentMode: .fill)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: cardGradients, startPoint: .topLeading, endPoint: .bottomTrailing).opacity(0.15))
                
                GeometryReader { geo in
                    Circle()
                        .fill(cardGradients[0])
                        .blur(radius: 30)
                        .frame(width: geo.size.width)
                        .offset(x: -geo.size.width * 0.2, y: -geo.size.height * 0.2)
                        .opacity(0.3)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(colors: cardGradients, startPoint: .topLeading, endPoint: .bottomTrailing).opacity(colorScheme == .dark ? 0.4 : 0.2),
                    lineWidth: 1
                )
        )
        .shadow(color: cardGradients[0].opacity(0.1), radius: 10, x: 0, y: 5)
    }
}
