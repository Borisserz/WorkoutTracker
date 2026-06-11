internal import SwiftUI

struct ConfigureExerciseView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(DashboardViewModel.self) var dashboardViewModel
    @Environment(UnitsManager.self) var unitsManager
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme 

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

    private var weightValueBinding: Binding<Double> {
        Binding(
            get: {
                let w = viewModel.form.weight ?? 0.0
                return unitsManager.convertFromKilograms(w)
            },
            set: { viewModel.form.weight = unitsManager.convertToKilograms($0) }
        )
    }

    private var distanceValueBinding: Binding<Double> {
        Binding(
            get: {
                let d = viewModel.form.distance ?? 0.0
                return unitsManager.convertFromMeters(d)
            },
            set: { viewModel.form.distance = unitsManager.convertToMeters($0) }
        )
    }

    private var repsBinding: Binding<Double> {
        Binding(
            get: { Double(viewModel.form.reps) },
            set: { viewModel.form.reps = Int($0) }
        )
    }

    private var setsBinding: Binding<Double> {
        Binding(
            get: { Double(viewModel.form.sets) },
            set: { viewModel.form.sets = Int($0) }
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
                themeManager.current.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // Header Title + Muscle Badge
                        HStack(alignment: .center, spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(LocalizationHelper.shared.translateName(viewModel.exerciseName))
                                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                                    .minimumScaleFactor(0.8)
                                
                                if let prevText = viewModel.previousPerformanceText {
                                    Text(prevText)
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundColor(themeManager.current.secondaryText)
                                }
                            }
                            
                            Spacer()
                            
                            MuscleSilhouetteBadge(muscleGroup: viewModel.muscleGroup)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                        if viewModel.showOverloadBanner {
                            overloadBannerCard
                                .padding(.horizontal, 20)
                        }

                        VStack(spacing: 20) {
                            switch viewModel.exerciseType {
                            case .strength: strengthConfig
                            case .cardio: cardioConfig
                            case .duration: durationConfig
                            }
                        }
                        .padding(.horizontal, 20)

                        Spacer(minLength: 120)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
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

    private var floatingAddButton: some View {
        Button {
            handleSave()
        } label: {
            Text(LocalizedStringKey("Add Exercise"))
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white) 
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(themeManager.current.primaryAccent) 
                .cornerRadius(14)
                .shadow(color: themeManager.current.primaryAccent.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
        .background(
            LinearGradient(
                colors: [themeManager.current.background, themeManager.current.background.opacity(0)],
                startPoint: .bottom,
                endPoint: .top
            )
            .ignoresSafeArea()
        )
    }

    private var overloadBannerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(themeManager.current.successColor)
                    .font(.headline)
                Text(LocalizedStringKey("Progressive Overload"))
                    .font(.headline)
                    .foregroundColor(themeManager.current.successColor)
            }

            let convertedWeight = unitsManager.convertFromKilograms(viewModel.recommendedWeight)
            let weightStr = LocalizationHelper.shared.formatFlexible((convertedWeight * 10).rounded() / 10)

            Text(LocalizedStringKey("Recommended weight increase to **\(weightStr) \(unitsManager.weightUnitString())** for this workout."))
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))

            HStack(spacing: 12) {
                Button {
                    let gen = UIImpactFeedbackGenerator(style: .light)
                    gen.impactOccurred()
                    withAnimation(.spring()) { viewModel.showOverloadBanner = false }
                } label: {
                    Text(LocalizedStringKey("Dismiss"))
                        .font(.subheadline).bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                Button {
                    let gen = UINotificationFeedbackGenerator()
                    gen.notificationOccurred(.success)
                    withAnimation(.spring()) { viewModel.applyOverload() }
                } label: {
                    Text(LocalizedStringKey("Apply"))
                        .font(.subheadline).bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(themeManager.current.successColor)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                }
            }
        }
        .padding(16)
        .background(themeManager.current.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(themeManager.current.successColor.opacity(0.3), lineWidth: 1)
        )
    }

    @ViewBuilder private var strengthConfig: some View {
        // Focus Mode Selector
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey("Focus Mode"))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.current.secondaryText)
                .padding(.horizontal, 4)
            
            Picker("Focus Mode", selection: Binding(
                get: { viewModel.selectedFocusMode },
                set: { viewModel.selectFocusMode($0) }
            )) {
                ForEach(ConfigureExerciseViewModel.FocusMode.allCases) { mode in
                    Text(mode.localizedName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.bottom, 8)

        // Sets Card
        VStack(spacing: 8) {
            Text(LocalizedStringKey("Sets"))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.current.secondaryText)
            
            Text("\(viewModel.form.sets)")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundColor(.white)
            
            PremiumSliderPicker(
                value: setsBinding,
                range: 1...20,
                step: 1.0
            )
        }
        .padding(.vertical, 14)
        .background(themeManager.current.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )

        // Reps Card
        VStack(spacing: 8) {
            Text(LocalizedStringKey("Reps"))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.current.secondaryText)
            
            Text("\(viewModel.form.reps)")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundColor(.white)
            
            PremiumSliderPicker(
                value: repsBinding,
                range: 1...100,
                step: 1.0
            )
        }
        .padding(.vertical, 14)
        .background(themeManager.current.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )

        // Weight Card
        VStack(spacing: 8) {
            Text(LocalizedStringKey("Weight (\(unitsManager.weightUnitString()))"))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.current.secondaryText)
            
            let wVal = unitsManager.convertFromKilograms(viewModel.form.weight ?? 0.0)
            Text(String(format: "%.1f", wVal))
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundColor(.white)
            
            PremiumSliderPicker(
                value: weightValueBinding,
                range: 0...300,
                step: 0.5
            )
            
            // Quick Plate Increments
            HStack(spacing: 12) {
                ForEach([1.25, 2.5, 5.0], id: \.self) { val in
                    Button {
                        let cur = unitsManager.convertFromKilograms(viewModel.form.weight ?? 0.0)
                        viewModel.form.weight = unitsManager.convertToKilograms(cur + val)
                        
                        let gen = UIImpactFeedbackGenerator(style: .medium)
                        gen.impactOccurred()
                    } label: {
                        Text("+\(LocalizationHelper.shared.formatFlexible(val))")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(themeManager.current.primaryAccent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(themeManager.current.primaryAccent.opacity(0.12))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(themeManager.current.primaryAccent.opacity(0.25), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 14)
        .background(themeManager.current.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    @ViewBuilder private var cardioConfig: some View {
        VStack(spacing: 8) {
            Text(LocalizedStringKey("Distance (\(unitsManager.distanceUnitString()))"))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.current.secondaryText)
            
            let dVal = unitsManager.convertFromMeters(viewModel.form.distance ?? 0.0)
            Text(String(format: "%.2f", dVal))
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundColor(.white)
            
            PremiumSliderPicker(
                value: distanceValueBinding,
                range: 0...50,
                step: 0.1
            )
        }
        .padding(.vertical, 14)
        .background(themeManager.current.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )

        CustomTimeCard(title: "Duration", minBinding: minutesBinding, secBinding: secondsBinding)
    }

    @ViewBuilder private var durationConfig: some View {
        VStack(spacing: 8) {
            Text(LocalizedStringKey("Sets"))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.current.secondaryText)
            
            Text("\(viewModel.form.sets)")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundColor(.white)
            
            PremiumSliderPicker(
                value: setsBinding,
                range: 1...20,
                step: 1.0
            )
        }
        .padding(.vertical, 14)
        .background(themeManager.current.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )

        CustomTimeCard(title: "Set Time", minBinding: minutesBinding, secBinding: secondsBinding)
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

// MARK: - Muscle Silhouette Badge
struct MuscleSilhouetteBadge: View {
    let muscleGroup: String
    @Environment(ThemeManager.self) private var themeManager
    
    private var systemImageName: String {
        let group = muscleGroup.lowercased()
        if group.contains("core") || group.contains("abs") {
            return "figure.core.training"
        } else if group.contains("cardio") || group.contains("run") || group.contains("cycle") {
            return "figure.run"
        } else if group.contains("legs") || group.contains("quad") || group.contains("calves") {
            return "figure.strengthtraining.traditional"
        } else {
            return "figure.strengthtraining.traditional"
        }
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.current.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            
            Image(systemName: systemImageName)
                .font(.system(size: 24))
                .foregroundColor(.white)
        }
        .frame(width: 50, height: 50)
    }
}

// MARK: - Premium Slider Picker
struct PremiumSliderPicker: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        HStack(spacing: 16) {
            Button {
                decrement()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(value > range.lowerBound ? themeManager.current.primaryAccent : .white.opacity(0.15))
            }
            .buttonStyle(.plain)
            .disabled(value <= range.lowerBound)
            
            Slider(value: $value, in: range, step: step)
                .tint(themeManager.current.primaryAccent)
            
            Button {
                increment()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(value < range.upperBound ? themeManager.current.primaryAccent : .white.opacity(0.15))
            }
            .buttonStyle(.plain)
            .disabled(value >= range.upperBound)
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
    }
    
    private func decrement() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        value = max((value - step).roundedToStep(step: step), range.lowerBound)
    }
    
    private func increment() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        value = min((value + step).roundedToStep(step: step), range.upperBound)
    }
}

extension Double {
    fileprivate func roundedToStep(step: Double) -> Double {
        return (self / step).rounded() * step
    }
}

// MARK: - Custom Time Card
struct CustomTimeCard: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    let title: LocalizedStringKey
    let minBinding: Binding<Double?>
    let secBinding: Binding<Double?>

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            HStack(spacing: 8) {
                ClearableTextField(placeholder: "0", value: minBinding)
                    .frame(width: 50)
                Text(LocalizedStringKey("min"))
                    .font(.subheadline)
                    .foregroundColor(themeManager.current.secondaryText)

                ClearableTextField(placeholder: "0", value: secBinding)
                    .frame(width: 50)
                    .onChange(of: secBinding.wrappedValue) { _, newValue in
                        if let s = newValue, s > 59 { secBinding.wrappedValue = 59 }
                    }
                Text(LocalizedStringKey("sec"))
                    .font(.subheadline)
                    .foregroundColor(themeManager.current.secondaryText)
            }
        }
        .padding(16)
        .background(themeManager.current.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}
