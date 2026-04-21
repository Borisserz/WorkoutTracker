// ============================================================
// FILE: WorkoutTracker/Features/ExerciseCatalog/Views/AddNewExerciseView.swift
// ============================================================

internal import SwiftUI
import SwiftData

struct AddNewExerciseView: View {
    
    // MARK: - Environment & State
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(CatalogViewModel.self) private var catalogViewModel
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme // 👈 ДОБАВЛЕНО
    
    @State private var categories: [String] = []
    
    @State private var name: String = ""
    @State private var selectedCategory: String = "Chest"
    @State private var selectedType: ExerciseType = .strength
    @State private var selectedMuscles: Set<String> = []
    
    private let availableMuscles: [(name: String, slug: String)] = [
        ("Chest", "chest"),
        ("Upper Back", "upper-back"), ("Lats", "lats"), ("Traps", "trapezius"), ("Lower Back", "lower-back"),
        ("Shoulders (Delts)", "deltoids"),
        ("Biceps", "biceps"), ("Triceps", "triceps"), ("Forearms", "forearm"),
        ("Abs", "abs"), ("Obliques", "obliques"),
        ("Quads", "quadriceps"), ("Hamstrings", "hamstring"), ("Glutes", "gluteal"), ("Calves", "calves")
    ]
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Адаптивный фон
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 32) {
                        
                        Text(LocalizedStringKey("New Exercise"))
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            // 👈 АДАПТИВНЫЙ ТЕКСТ
                            .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .black)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        
                        basicInfoSection
                            .padding(.horizontal, 20)
                        
                        muscleSelectionSection
                            .padding(.horizontal, 20)
                        
                        Spacer(minLength: 120)
                    }
                }
                
                saveButton
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.gray.opacity(0.5))
                    }
                }
            }
            .task {
                let catalog = await ExerciseDatabaseService.shared.getCatalog()
                self.categories = catalog.keys.sorted()
                if !categories.isEmpty && !categories.contains(selectedCategory) {
                    selectedCategory = categories.first ?? "Chest"
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedStringKey("Basic Information"))
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .secondary)
            
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "dumbbell.fill")
                        .foregroundColor(themeManager.current.primaryAccent)
                    
                    TextField(LocalizedStringKey("Exercise Name"), text: $name)
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .black)
                        .submitLabel(.done)
                }
                .padding()
                
                Divider().padding(.leading, 45)
                
                HStack(spacing: 12) {
                    Image(systemName: "folder.fill")
                        .foregroundColor(themeManager.current.primaryAccent)
                    
                    Text(LocalizedStringKey("Category"))
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .black)
                    
                    Spacer()
                    
                    Picker("", selection: $selectedCategory) {
                        if categories.isEmpty {
                            Text("Loading...").tag("Chest")
                        } else {
                            ForEach(categories, id: \.self) { cat in
                                Text(LocalizedStringKey(cat)).tag(cat)
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                }
                .padding()
            }
            // 👈 АДАПТИВНЫЙ ФОН И ТЕНЬ КАРТОЧКИ
            .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.clear, lineWidth: 1))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.05 : 0.08), radius: 10, x: 0, y: 5)
        }
    }
    
    private var muscleSelectionSection: some View {
         VStack(alignment: .leading, spacing: 16) {
             HStack {
                 Text(LocalizedStringKey("Targeted Muscles"))
                     .font(.headline)
                     .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .secondary)
                 Spacer()
                 Text("\(selectedMuscles.count)")
                     .font(.caption.bold())
                     .foregroundColor(.white)
                     .frame(width: 24, height: 24)
                     .background(themeManager.current.primaryAccent)
                     .clipShape(Circle())
                     .opacity(selectedMuscles.isEmpty ? 0 : 1)
             }
             
             LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
                 ForEach(availableMuscles, id: \.slug) { muscle in
                     let isSelected = selectedMuscles.contains(muscle.slug)
                     
                     Button {
                         let gen = UISelectionFeedbackGenerator()
                         gen.selectionChanged()
                         withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                             toggleMuscle(muscle.slug)
                         }
                     } label: {
                         Text(LocalizedStringKey(muscle.name))
                             .font(.subheadline)
                             .fontWeight(isSelected ? .bold : .medium)
                             .lineLimit(1)
                             .minimumScaleFactor(0.7)
                             .frame(maxWidth: .infinity)
                             .padding(.vertical, 12)
                             .padding(.horizontal, 4)
                             // ✅ ИСПРАВЛЕНИЕ ОШИБКИ КОМПИЛЯТОРА: Разбили сложную логику на функции
                             .background(chipBackgroundColor(isSelected: isSelected))
                             .foregroundColor(chipForegroundColor(isSelected: isSelected))
                             .cornerRadius(12)
                             .overlay(
                                 RoundedRectangle(cornerRadius: 12)
                                     .stroke(chipBorderColor(isSelected: isSelected), lineWidth: 1)
                             )
                             .shadow(color: chipShadowColor(isSelected: isSelected), radius: 5, x: 0, y: 2)
                     }
                     .buttonStyle(.plain)
                 }
             }
         }
     }
    
    private var saveButton: some View {
        let isFormValid = !name.trimmingCharacters(in: .whitespaces).isEmpty && !selectedMuscles.isEmpty && !categories.isEmpty
        
        return Button {
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.success)
            saveExercise()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                Text(LocalizedStringKey("Save Exercise"))
                    .font(.headline)
                    .fontWeight(.bold)
            }
            .foregroundColor(isFormValid ? themeManager.current.background : .white.opacity(0.5))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(isFormValid ? AnyShapeStyle(themeManager.current.primaryGradient) : AnyShapeStyle(Color.gray.opacity(0.3)))
            .cornerRadius(20)
            .shadow(color: isFormValid ? themeManager.current.primaryAccent.opacity(0.4) : .clear, radius: 15, x: 0, y: 8)
        }
        .disabled(!isFormValid)
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
        .background(
            LinearGradient(colors: [Color(UIColor.systemGroupedBackground), Color(UIColor.systemGroupedBackground).opacity(0)], startPoint: .bottom, endPoint: .top)
                .ignoresSafeArea()
        )
    }
    
    // MARK: - Actions
    
    private func toggleMuscle(_ slug: String) {
        if selectedMuscles.contains(slug) {
            selectedMuscles.remove(slug)
        } else {
            selectedMuscles.insert(slug)
        }
    }
    
    private func saveExercise() {
        Task {
            await catalogViewModel.addCustomExercise(
                name: name,
                category: selectedCategory,
                muscles: Array(selectedMuscles),
                type: selectedType
            )
            dismiss()
        }
    }
    
    
    private func chipBackgroundColor(isSelected: Bool) -> Color {
            if isSelected {
                return themeManager.current.primaryAccent.opacity(0.15)
            } else {
                return colorScheme == .dark ? themeManager.current.surface : Color.white
            }
        }
        
        private func chipForegroundColor(isSelected: Bool) -> Color {
            if isSelected {
                return themeManager.current.primaryAccent
            } else {
                return colorScheme == .dark ? themeManager.current.primaryText.opacity(0.8) : Color.black.opacity(0.8)
            }
        }
        
        private func chipBorderColor(isSelected: Bool) -> Color {
            if isSelected {
                return themeManager.current.primaryAccent
            } else {
                return colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05)
            }
        }
        
        private func chipShadowColor(isSelected: Bool) -> Color {
            return isSelected ? themeManager.current.primaryAccent.opacity(0.3) : .clear
        }
}
