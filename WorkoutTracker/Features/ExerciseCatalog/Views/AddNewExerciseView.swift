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
    
    @State private var categories: [String] = []
    
    @State private var name: String = ""
    @State private var selectedCategory: String = "Chest"
    @State private var selectedType: ExerciseType = .strength
    @State private var selectedMuscles: Set<String> = []
    
    // Словарь: Отображаемое имя -> Технический слаг (slug)
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
                // 1. Премиальный фон
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 32) {
                        
                        // Заголовок (кастомный)
                        Text(LocalizedStringKey("New Exercise"))
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundColor(themeManager.current.primaryText)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        
                        // 2. Блок базовой информации
                        basicInfoSection
                            .padding(.horizontal, 20)
                        
                        // 3. Блок выбора мышц (Сетка)
                        muscleSelectionSection
                            .padding(.horizontal, 20)
                        
                        Spacer(minLength: 120) // Место под плавающую кнопку
                    }
                }
                
                // 4. Плавающая кнопка сохранения
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
            Text(LocalizedStringKey("Basic Info"))
                .font(.headline)
                .foregroundColor(themeManager.current.secondaryText)
            
            VStack(spacing: 0) {
                // Ввод имени
                HStack(spacing: 12) {
                    Image(systemName: "dumbbell.fill")
                        .foregroundColor(themeManager.current.primaryAccent)
                    
                    TextField(LocalizedStringKey("Exercise Name"), text: $name)
                        .font(.headline)
                        .foregroundColor(themeManager.current.primaryText)
                        .submitLabel(.done)
                }
                .padding()
                
                Divider().padding(.leading, 45)
                
                // Выбор категории
                HStack(spacing: 12) {
                    Image(systemName: "folder.fill")
                        .foregroundColor(themeManager.current.primaryAccent)
                    
                    Text(LocalizedStringKey("Category"))
                        .font(.headline)
                        .foregroundColor(themeManager.current.primaryText)
                    
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
                    .tint(themeManager.current.secondaryText)
                }
                .padding()
            }
            .background(themeManager.current.surface)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.05), lineWidth: 1))
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        }
    }
    
    private var muscleSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(LocalizedStringKey("Affected Muscles (for Heatmap)"))
                    .font(.headline)
                    .foregroundColor(themeManager.current.secondaryText)
                Spacer()
                Text("\(selectedMuscles.count)")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(themeManager.current.primaryAccent)
                    .clipShape(Circle())
                    .opacity(selectedMuscles.isEmpty ? 0 : 1)
            }
            
            // Используем LazyVGrid для красивого расположения "чипсов"
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
                            .background(isSelected ? themeManager.current.primaryAccent.opacity(0.15) : themeManager.current.surface)
                            .foregroundColor(isSelected ? themeManager.current.primaryAccent : themeManager.current.primaryText.opacity(0.8))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isSelected ? themeManager.current.primaryAccent : Color.white.opacity(0.05), lineWidth: 1)
                            )
                            .shadow(color: isSelected ? themeManager.current.primaryAccent.opacity(0.3) : .clear, radius: 5, x: 0, y: 2)
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
}
