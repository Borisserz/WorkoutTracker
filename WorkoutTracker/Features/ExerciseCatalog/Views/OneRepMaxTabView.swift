//
//  OneRepMaxTabView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 7.04.26.
//

//
//  OneRepMaxTabView.swift
//  WorkoutTracker
//

internal import SwiftUI

struct OneRepMaxTabView: View {
    @Bindable var vm: ExerciseHistoryViewModel
    @Environment(UnitsManager.self) var unitsManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager
    @State private var showSettingsSheet = false
    
    var body: some View {
        VStack(spacing: 20) {
            
            // Header Banner
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("1RM Tables"))
                        .font(.title2)
                        .fontWeight(.heavy)
                        .foregroundColor(themeManager.current.primaryText)
                    Text(LocalizedStringKey("Estimate your max weight for any rep level"))
                        .font(.subheadline)
                        .foregroundColor(themeManager.current.secondaryText)
                }
                Spacer()
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    showSettingsSheet = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title2)
                        .foregroundColor(themeManager.current.primaryText)
                        .padding(12)
                        .background(Color(UIColor.tertiarySystemFill))
                        .clipShape(Circle())
                }
            }
            .padding(.bottom, 8)
            
            // Main Table
            VStack(spacing: 0) {
                // Table Header
                HStack {
                    Text(LocalizedStringKey("Reps"))
                        .font(.caption)
                        .foregroundColor(themeManager.current.secondaryText)
                        .frame(width: 60, alignment: .leading)
                    
                    Text(LocalizedStringKey("Max Estimate"))
                        .font(.caption)
                        .foregroundColor(themeManager.current.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Text(LocalizedStringKey("% of 1RM"))
                        .font(.caption)
                        .foregroundColor(themeManager.current.secondaryText)
                        .frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                
                Divider()
                
                // Table Rows (1 to 12 reps)
                let current1RM = vm.effective1RM
                
                if current1RM > 0 {
                    ForEach(1...12, id: \.self) { reps in
                        let weightKg = OneRepMaxCalculator.calculateWeightForReps(oneRepMax: current1RM, targetReps: reps, formula: vm.selectedFormula)
                        let percentage = (weightKg / current1RM) * 100.0
                        
                        let displayWeight = unitsManager.convertFromKilograms(weightKg)
                        
                        HStack {
                            Text("\(reps)")
                                .font(.headline)
                                .foregroundColor(themeManager.current.primaryText)
                                .frame(width: 60, alignment: .leading)
                            
                            Text("\(LocalizationHelper.shared.formatFlexible(displayWeight)) \(unitsManager.weightUnitString())")
                                .font(.headline)
                                .foregroundColor(vm.chartColor)
                                .frame(maxWidth: .infinity, alignment: .center)
                            
                            Text("\(Int(percentage))%")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(themeManager.current.secondaryText)
                                .frame(width: 80, alignment: .trailing)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(reps % 2 == 0 ? Color.clear : Color.primary.opacity(0.03))
                    }
                } else {
                    EmptyStateView(
                        icon: "dumbbell.fill",
                        title: "No Data",
                        message: "Log a workout or enter data manually in settings to calculate your 1RM."
                    )
                    .padding(.vertical, 40)
                }
            }
            .background(themeManager.current.surfaceVariant)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 5)
        }
        .sheet(isPresented: $showSettingsSheet) {
            OneRepMaxSettingsSheet(vm: vm)
        }
    }
}

// MARK: - Settings & Calculator Sheet
struct OneRepMaxSettingsSheet: View {
    @Bindable var vm: ExerciseHistoryViewModel
    @Environment(UnitsManager.self) var unitsManager
    @Environment(\.dismiss) var dismiss
    @Environment(ThemeManager.self) private var themeManager
    // Local State for TextFields to handle smooth typing
    @State private var weightString: String = ""
    @State private var repsString: String = ""
    @State private var manual1RMString: String = ""
    @State private var isManualEnabled: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(LocalizedStringKey("Formula"))) {
                    Picker(LocalizedStringKey("Calculation Method"), selection: $vm.selectedFormula) {
                        ForEach(RMFormula.allCases) { formula in
                            Text(LocalizedStringKey(formula.rawValue)).tag(formula)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(vm.chartColor)
                }
                
                Section(
                    header: Text(LocalizedStringKey("Estimate 1RM from Set")),
                    footer: Text(LocalizedStringKey("Plug in a maximum effort set to get an estimated 1RM. Sets with low reps (1-5) and high weight yield the most accurate estimates."))
                ) {
                    HStack {
                        Text(LocalizedStringKey("Weight (\(unitsManager.weightUnitString()))"))
                        Spacer()
                        TextField("0.0", text: $weightString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(themeManager.current.deepPremiumAccent) // <--- ИЗМЕНЕНО:
                            .fontWeight(.bold)
                            .onChange(of: weightString) { _, newValue in
                                if let val = Double(newValue.replacingOccurrences(of: ",", with: ".")) {
                                    vm.calcInputWeight = unitsManager.convertToKilograms(val)
                                    if isManualEnabled { isManualEnabled = false; vm.manual1RMOverride = nil }
                                } else if newValue.isEmpty {
                                    vm.calcInputWeight = nil
                                }
                            }
                    }
                    
                    HStack {
                        Text(LocalizedStringKey("Repetitions"))
                        Spacer()
                        TextField("0", text: $repsString)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(vm.chartColor)
                            .fontWeight(.bold)
                            .onChange(of: repsString) { _, newValue in
                                if let val = Int(newValue) {
                                    vm.calcInputReps = val
                                    if isManualEnabled { isManualEnabled = false; vm.manual1RMOverride = nil }
                                } else if newValue.isEmpty {
                                    vm.calcInputReps = nil
                                }
                            }
                    }
                }
                
                Section(header: Text(LocalizedStringKey("Manual Override"))) {
                    Toggle(isOn: $isManualEnabled) {
                        Text(LocalizedStringKey("Set Manual 1RM"))
                    }
                    .tint(vm.chartColor)
                    .onChange(of: isManualEnabled) { _, enabled in
                        if !enabled {
                            vm.manual1RMOverride = nil
                            manual1RMString = ""
                        } else {
                            // Очищаем авто-инпут
                            vm.calcInputWeight = nil
                            vm.calcInputReps = nil
                            weightString = ""
                            repsString = ""
                        }
                    }
                    
                    if isManualEnabled {
                        HStack {
                            Text(LocalizedStringKey("Absolute 1RM (\(unitsManager.weightUnitString()))"))
                            Spacer()
                            TextField("0.0", text: $manual1RMString)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(.purple)
                                .fontWeight(.bold)
                                .onChange(of: manual1RMString) { _, newValue in
                                    if let val = Double(newValue.replacingOccurrences(of: ",", with: ".")) {
                                        vm.manual1RMOverride = unitsManager.convertToKilograms(val)
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("1RM Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Done")) { dismiss() }
                }
            }
            .onAppear {
                // Populate initial state
                if let w = vm.calcInputWeight {
                    weightString = LocalizationHelper.shared.formatDecimal(unitsManager.convertFromKilograms(w))
                }
                if let r = vm.calcInputReps {
                    repsString = "\(r)"
                }
                if let m = vm.manual1RMOverride {
                    isManualEnabled = true
                    manual1RMString = LocalizationHelper.shared.formatDecimal(unitsManager.convertFromKilograms(m))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
