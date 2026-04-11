internal import SwiftUI

struct SmartGeneratorEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DashboardViewModel.self) private var dashboard // Получаем историю
    @Environment(ThemeManager.self) private var themeManager
    @State private var vm = SmartGeneratorViewModel()
    
    // Возвращаем DTO!
    var onWorkoutReady: ([ExerciseDTO]) -> Void
    
    var body: some View {
        NavigationStack(path: $vm.path) {
            ZStack {
                themeManager.current.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        headerSection
                        quickPresetsSection
                    }
                    .padding(.bottom, 100)
                }
                
                // Плавающая кнопка (Cyan)
                VStack {
                    Spacer()
                    Button {
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                        vm.path.append("MuscleSelection")
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "wand.and.stars").font(.title3)
                            Text("Custom Builder").font(.title3).bold()
                        }
                        .foregroundColor(themeManager.current.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        // ✅ ИСПОЛЬЗУЕМ СВЕТЛО-СИНИЙ/CYAN
                        .background(themeManager.current.primaryGradient)
                        .clipShape(Capsule())
                        .shadow(color: themeManager.current.lightHighlight.opacity(0.4), radius: 15, x: 0, y: 8)
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 16)
                
                // ✅ ЧИСТЫЙ ЛОАДЕР (БЕЗ ПЛЕНКИ НА ВЕСЬ ЭКРАН)
                if vm.isGenerating {
                    ZStack {
                        Color.black.opacity(0.4).ignoresSafeArea() // Легкое затемнение
                        VStack(spacing: 20) {
                            ProgressView().controlSize(.large).tint(themeManager.current.lightHighlight)
                            Text("Building your perfect workout...")
                                .font(.headline)
                                .foregroundColor(themeManager.current.primaryText)
                        }
                        .padding(30)
                        .background(themeManager.current.background) // Чистый фон карточки
                        .cornerRadius(24)
                        .shadow(color: .black.opacity(0.2), radius: 20)
                    }
                    .zIndex(100)
                    .transition(.opacity)
                }
            }
            .navigationTitle("Smart Builder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.secondary, Color(UIColor.tertiarySystemFill)) }
                }
            }
            .navigationDestination(for: String.self) { route in
                switch route {
                case "MuscleSelection": MuscleSelectionView(vm: vm)
                case "Settings": GeneratorSettingsView(vm: vm)
                case "ResultView": GeneratedWorkoutResultView(vm: vm, onStart: { dtos in
                        dismiss()
                        onWorkoutReady(dtos)
                    })
                default: EmptyView()
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Text(LocalizedStringKey("Don't want to think?"))
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .padding(.top, 24)
            Text(LocalizedStringKey("Select a quick preset or build a custom routine in seconds."))
                .font(.subheadline)
                .foregroundColor(themeManager.current.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
    
    private var quickPresetsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Generation").font(.headline).padding(.horizontal, 24)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                quickCard(title: "At Home Shred", icon: "house.fill", color: themeManager.current.secondaryMidTone, desc: "Bodyweight, 30m") {
                    vm.applyQuickPreset(name: "Home Shred", muscles: ["Chest", "Core", "Legs"], duration: 30, equipment: .bodyweight, historyCache: dashboard.lastPerformancesCache)
                }
                quickCard(title: "Dumbbell Only", icon: "scalemass.fill", color: .purple, desc: "Full Body, 45m") {
                    vm.applyQuickPreset(name: "Dumbbell Full Body", muscles: ["Chest", "Back", "Legs"], duration: 45, equipment: .dumbbellsOnly, historyCache: dashboard.lastPerformancesCache)
                }
                quickCard(title: "Quick Pump", icon: "bolt.fill", color: themeManager.current.primaryAccent, desc: "Arms & Chest, 20m") {
                    vm.applyQuickPreset(name: "Quick Pump", muscles: ["Arms", "Chest"], duration: 20, equipment: .fullGym, historyCache: dashboard.lastPerformancesCache)
                }
                quickCard(title: "Cardio Blast", icon: "heart.fill", color: .red, desc: "Sweat session, 30m") {
                    vm.applyQuickPreset(name: "Cardio Blast", muscles: ["Cardio", "Core"], duration: 30, equipment: .bodyweight, historyCache: dashboard.lastPerformancesCache)
                }
            }
            .padding(.horizontal, 24)
        }
    }
    
    private func quickCard(title: String, icon: String, color: Color, desc: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon).font(.title2).foregroundColor(color)
                    .frame(width: 40, height: 40).background(color.opacity(0.15)).clipShape(Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(title)).font(.headline).foregroundColor(themeManager.current.primaryText)
                    Text(LocalizedStringKey(desc)).font(.caption).foregroundColor(themeManager.current.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(themeManager.current.surface)
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}
