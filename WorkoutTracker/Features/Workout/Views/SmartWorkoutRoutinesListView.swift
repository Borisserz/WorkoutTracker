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
        userPresets.filter { ($0.folderName ?? "").isEmpty && $0.name != "Today's Plan" }
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
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }

    private var routinesListSection: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(myRoutines) { preset in
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        dismiss()
                        onPresetTap(preset)
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04))
                                    .frame(width: 44, height: 44)
                                Image(systemName: preset.icon.isEmpty ? "dumbbell.fill" : preset.icon)
                                    .foregroundColor(.green)
                                    .font(.title3)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(preset.name)
                                    .font(.headline)
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                Text(LocalizedStringKey("\(preset.exercises.count) exercises"))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "play.fill")
                                .foregroundColor(.green)
                                .font(.subheadline)
                        }
                        .padding(16)
                        .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
    }
}
