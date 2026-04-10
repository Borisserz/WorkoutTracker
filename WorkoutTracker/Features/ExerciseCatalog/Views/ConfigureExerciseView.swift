internal import SwiftUI

struct ConfigureExerciseView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(DashboardViewModel.self) var dashboardViewModel
    @Environment(UnitsManager.self) var unitsManager
    
    var onAdd: (Exercise) -> Void
    
    @State private var viewModel: ConfigureExerciseViewModel
    
    init(exerciseName: String, muscleGroup: String, exerciseType: ExerciseType = .strength, onAdd: @escaping (Exercise) -> Void) {
        self.onAdd = onAdd
        _viewModel = State(initialValue: ConfigureExerciseViewModel(
            exerciseName: exerciseName,
            muscleGroup: muscleGroup,
            exerciseType: exerciseType
        ))
    }
    
    // Биндинги: Добавлено округление (round) в get-блоках для фикса бага с длинными дробями при конвертации
    private var weightBinding: Binding<Double?> {
        Binding(
            get: {
                guard let w = viewModel.form.weight else { return nil }
                let converted = unitsManager.convertFromKilograms(w)
                return (converted * 10).rounded() / 10 // Фикс дробей в UI
            },
            set: { viewModel.form.weight = $0.map { unitsManager.convertToKilograms($0) } }
        )
    }
    
    private var distanceBinding: Binding<Double?> {
        Binding(
            get: {
                guard let d = viewModel.form.distance else { return nil }
                let converted = unitsManager.convertFromMeters(d)
                return (converted * 100).rounded() / 100 // Фикс дробей в UI
            },
            set: { viewModel.form.distance = $0.map { unitsManager.convertToMeters($0) } }
        )
    }
    
    private var minutesBinding: Binding<Double?> {
        Binding(get: { viewModel.form.minutes.map { Double($0) } }, set: { viewModel.form.minutes = $0.map { Int($0) } })
    }
    
    private var secondsBinding: Binding<Double?> {
        Binding(get: { viewModel.form.seconds.map { Double($0) } }, set: { viewModel.form.seconds = $0.map { Int($0) } })
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Премиальный фон
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // Главный заголовок
                        Text(LocalizationHelper.shared.translateName(viewModel.exerciseName))
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                        
                        if viewModel.showOverloadBanner {
                            overloadBannerCard
                                .padding(.horizontal, 20)
                        }
                        
                        VStack(spacing: 16) {
                            switch viewModel.exerciseType {
                            case .strength: strengthConfig
                            case .cardio: cardioConfig
                            case .duration: durationConfig
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 100) // Место под плавающую кнопку
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("Configure"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Cancel")) { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                floatingAddButton
            }
            .alert(LocalizedStringKey("Invalid Input"), isPresented: $viewModel.showValidationAlert) {
                Button(LocalizedStringKey("OK"), role: .cancel) { }
            } message: {
                Text(LocalizedStringKey(viewModel.form.validationErrorMessage ?? "Unknown error"))
            }
            .onAppear {
                viewModel.loadLastPerformance(from: dashboardViewModel.lastPerformancesCache)
            }
        }
    }
    
    // MARK: - View Components
    
    private var floatingAddButton: some View {
        Button {
            handleSave()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                Text(LocalizedStringKey("Add Exercise"))
                    .font(.headline)
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .cornerRadius(20)
            .shadow(color: .blue.opacity(0.4), radius: 15, x: 0, y: 8)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
        .background(
            LinearGradient(colors: [Color(UIColor.systemGroupedBackground), Color(UIColor.systemGroupedBackground).opacity(0)], startPoint: .bottom, endPoint: .top)
                .ignoresSafeArea()
        )
    }
    
    private var overloadBannerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.green)
                        .font(.headline)
                }
                Text(LocalizedStringKey("Progressive Overload"))
                    .font(.headline)
                    .foregroundColor(.green)
            }
            
            let convertedWeight = unitsManager.convertFromKilograms(viewModel.recommendedWeight)
            let weightStr = LocalizationHelper.shared.formatFlexible((convertedWeight * 10).rounded() / 10)
            
            Text(LocalizedStringKey("Your forecast allows it! Try **\(weightStr) \(unitsManager.weightUnitString())** today for better results."))
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineSpacing(4)
            
            HStack(spacing: 12) {
                Button {
                    let gen = UIImpactFeedbackGenerator(style: .light)
                    gen.impactOccurred()
                    withAnimation(.spring()) { viewModel.showOverloadBanner = false }
                } label: {
                    Text(LocalizedStringKey("Discard"))
                        .font(.subheadline).bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.15))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
                
                Button {
                    let gen = UINotificationFeedbackGenerator()
                    gen.notificationOccurred(.success)
                    withAnimation(.spring()) { viewModel.applyOverload() }
                } label: {
                    Text(LocalizedStringKey("Apply"))
                        .font(.subheadline).bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: .green.opacity(0.3), radius: 5, x: 0, y: 3)
                }
            }
        }
        .padding(20)
        .background(Color.green.opacity(0.05))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    @ViewBuilder private var strengthConfig: some View {
        CustomStepperCard(title: "Sets", value: $viewModel.form.sets, range: 1...20)
        CustomStepperCard(title: "Reps", value: $viewModel.form.reps, range: 1...100)
        CustomInputCard(title: "Weight (\(unitsManager.weightUnitString()))", placeholder: "0.0", binding: weightBinding)
    }
    
    @ViewBuilder private var cardioConfig: some View {
        CustomInputCard(title: "Distance (\(unitsManager.distanceUnitString()))", placeholder: "0.0", binding: distanceBinding)
        CustomTimeCard(title: "Duration", minBinding: minutesBinding, secBinding: secondsBinding)
    }
    
    @ViewBuilder private var durationConfig: some View {
        CustomStepperCard(title: "Sets", value: $viewModel.form.sets, range: 1...10)
        CustomTimeCard(title: "Time per set", minBinding: minutesBinding, secBinding: secondsBinding)
    }
    
    private func handleSave() {
        if let newExercise = viewModel.generateExercise(unitsManager: unitsManager) {
            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.impactOccurred()
            onAdd(newExercise)
            dismiss()
        }
    }
}

// MARK: - Custom UI Components

struct CustomStepperCard: View {
    let title: LocalizedStringKey
    @Binding var value: Int
    let range: ClosedRange<Int>
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: 16) {
                Button {
                    let gen = UIImpactFeedbackGenerator(style: .light)
                    gen.impactOccurred()
                    if value > range.lowerBound { value -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(value > range.lowerBound ? .blue : .gray.opacity(0.3))
                }
                
                Text("\(value)")
                    .font(.title3)
                    .bold()
                    .frame(minWidth: 35, alignment: .center)
                
                Button {
                    let gen = UIImpactFeedbackGenerator(style: .light)
                    gen.impactOccurred()
                    if value < range.upperBound { value += 1 }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(value < range.upperBound ? .blue : .gray.opacity(0.3))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 3)
    }
}

struct CustomInputCard: View {
    let title: LocalizedStringKey
    let placeholder: String
    let binding: Binding<Double?>
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            ClearableTextField(placeholder: placeholder, value: binding)
                .frame(width: 90)
                .font(.headline)
                .padding(.vertical, 4)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 3)
    }
}

struct CustomTimeCard: View {
    let title: LocalizedStringKey
    let minBinding: Binding<Double?>
    let secBinding: Binding<Double?>
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: 8) {
                ClearableTextField(placeholder: "0", value: minBinding)
                    .frame(width: 50)
                Text(LocalizedStringKey("min"))
                    .font(.subheadline).foregroundColor(.secondary)
                
                ClearableTextField(placeholder: "0", value: secBinding)
                    .frame(width: 50)
                    .onChange(of: secBinding.wrappedValue) { _, newValue in
                        if let s = newValue, s > 59 { secBinding.wrappedValue = 59 }
                    }
                Text(LocalizedStringKey("sec"))
                    .font(.subheadline).foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 3)
    }
}
