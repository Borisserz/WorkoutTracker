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
    
    // Биндинги (Остаются здесь, так как зависят от UnitsManager из Environment)
    private var weightBinding: Binding<Double?> {
        Binding(
            get: { viewModel.form.weight.map { unitsManager.convertFromKilograms($0) } },
            set: { viewModel.form.weight = $0.map { unitsManager.convertToKilograms($0) } }
        )
    }
    
    private var distanceBinding: Binding<Double?> {
        Binding(
            get: { viewModel.form.distance.map { unitsManager.convertFromMeters($0) } },
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
            Form {
                if viewModel.showOverloadBanner { overloadBannerSection }
                
                Section(header: Text("Configuration")) {
                    HStack {
                        Text("Exercise"); Spacer()
                        Text(viewModel.exerciseName).bold()
                    }
                    
                    switch viewModel.exerciseType {
                    case .strength: strengthConfig
                    case .cardio: cardioConfig
                    case .duration: durationConfig
                    }
                }
                
                Button("Add Exercise") { handleSave() }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Configure")
            .alert("Invalid Input", isPresented: $viewModel.showValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.form.validationErrorMessage ?? "Unknown error")
            }
            .onAppear {
                // Передаем закэшированные данные во ViewModel
                viewModel.loadLastPerformance(from: dashboardViewModel.lastPerformancesCache)
            }
        }
    }
    
    // MARK: - View Components
    
    private var overloadBannerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis").foregroundColor(.green)
                    Text("Progressive Overload").font(.headline).foregroundColor(.green)
                }
                
                let convertedWeight = unitsManager.convertFromKilograms(viewModel.recommendedWeight)
                let weightStr = LocalizationHelper.shared.formatFlexible(convertedWeight)
                
                Text("Your forecast allows it! Try **\(weightStr) \(unitsManager.weightUnitString())** today for better results.")
                    .font(.subheadline).foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    Button("Discard") { withAnimation { viewModel.showOverloadBanner = false } }
                        .buttonStyle(.bordered).tint(.gray).frame(maxWidth: .infinity)
                    
                    Button("Apply") {
                        withAnimation { viewModel.applyOverload() }
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                    .buttonStyle(.borderedProminent).tint(.green).frame(maxWidth: .infinity)
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 4)
        }
    }
    
    @ViewBuilder private var strengthConfig: some View {
        Stepper("Sets: \(viewModel.form.sets)", value: $viewModel.form.sets, in: 1...20)
        Stepper("Reps: \(viewModel.form.reps)", value: $viewModel.form.reps, in: 1...100)
        HStack {
            Text("Weight (\(unitsManager.weightUnitString())):")
            Spacer()
            ClearableTextField(placeholder: unitsManager.weightUnitString(), value: weightBinding)
                .frame(width: 80)
        }
    }
    
    @ViewBuilder private var cardioConfig: some View {
        HStack {
            Text("Distance (\(unitsManager.distanceUnitString())):")
            Spacer()
            ClearableTextField(placeholder: unitsManager.distanceUnitString(), value: distanceBinding)
                .frame(width: 80)
        }
        timePickerRow(label: "Duration")
    }
    
    @ViewBuilder private var durationConfig: some View {
        Stepper("Sets: \(viewModel.form.sets)", value: $viewModel.form.sets, in: 1...10)
        timePickerRow(label: "Time per set")
    }
    
    private func timePickerRow(label: String) -> some View {
        HStack {
            Text(LocalizedStringKey(label))
            Spacer()
            HStack(spacing: 5) {
                ClearableTextField(placeholder: "0", value: minutesBinding).frame(width: 50)
                Text("min")
                ClearableTextField(placeholder: "0", value: secondsBinding).frame(width: 50)
                    .onChange(of: viewModel.form.seconds) { _, newValue in
                        if let s = newValue, s > 59 { viewModel.form.seconds = 59 }
                    }
                Text("sec")
            }
        }
    }
    
    private func handleSave() {
        if let newExercise = viewModel.generateExercise(unitsManager: unitsManager) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onAdd(newExercise)
            dismiss()
        }
    }
}
