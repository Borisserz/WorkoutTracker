internal import SwiftUI

struct EditMetricsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    @Environment(UnitsManager.self) private var unitsManager

    @AppStorage("userAge") private var age: Int = 25
    @AppStorage("userHeight") private var height: Int = 0
    @AppStorage(Constants.UserDefaultsKeys.userBodyWeight.rawValue) private var weight: Double = 0

    // Local state for editing before saving. Wheels show the active unit. Storage stays cm and kg.
    @State private var draftAge: Int = 25
    @State private var draftHeight: Int = 175
    @State private var draftWeight: Int = 75

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("Your Metrics")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.current.primaryText)
                    Text("Update your basic body parameters")
                        .font(.system(size: 15))
                        .foregroundColor(themeManager.current.secondaryText)
                }
                .padding(.top, 24)

                HStack(spacing: 0) {
                    MetricsWheelColumn(title: "Age", range: 14...100, suffix: "yrs", selection: $draftAge)
                    MetricsWheelColumn(title: "Height", range: heightRange, suffix: unitsManager.sizeUnitString(), selection: $draftHeight)
                    MetricsWheelColumn(title: "Weight", range: weightRange, suffix: unitsManager.weightUnitString(), selection: $draftWeight)
                }
                .frame(height: 220)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(PastelTheme.cardSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(PastelTheme.cardBorder, lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PastelTheme.canvas.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                Button(action: saveAndDismiss) {
                    Text("Save Changes")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(PastelTheme.textOnOat)
                        .frame(maxWidth: .infinity)
                        .frame(height: PastelTheme.ButtonMetrics.heroHeight)
                        .background(PastelTheme.pastelOat)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background(PastelTheme.canvas)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        ChromeDismissMark()
                    }
                    .buttonStyle(.plain)
                }
            }
            .onAppear {
                draftAge = age > 0 ? age : 25
                if height > 0 {
                    draftHeight = Int(unitsManager.convertFromCentimeters(Double(height)).rounded())
                } else {
                    draftHeight = unitsManager.sizeUnit == .centimeters ? 175 : Int((175.0 / 2.54).rounded())
                }
                if weight > 10 {
                    draftWeight = Int(unitsManager.convertFromKilograms(weight).rounded())
                } else {
                    draftWeight = unitsManager.weightUnit == .kilograms ? 75 : Int((75.0 * 2.20462).rounded())
                }
                draftHeight = min(max(draftHeight, heightRange.lowerBound), heightRange.upperBound)
                draftWeight = min(max(draftWeight, weightRange.lowerBound), weightRange.upperBound)
            }
        }
    }

    private var heightRange: ClosedRange<Int> {
        unitsManager.sizeUnit == .centimeters ? 140...230 : 55...90
    }

    private var weightRange: ClosedRange<Int> {
        unitsManager.weightUnit == .kilograms ? 40...200 : 90...440
    }
    
    private func saveAndDismiss() {
        HapticManager.shared.notification(.success)
        
        age = draftAge
        height = Int(unitsManager.convertToCentimeters(Double(draftHeight)).rounded())
        weight = unitsManager.convertToKilograms(Double(draftWeight))
        
        dismiss()
    }
}

struct MetricsWheelColumn: View {
    let title: String
    let range: ClosedRange<Int>
    let suffix: String
    @Binding var selection: Int
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        VStack(spacing: -10) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(themeManager.current.secondaryText)
                .padding(.bottom, 10)
            
            Picker(title, selection: $selection) {
                ForEach(range, id: \.self) { value in
                    Text("\(value) \(suffix)")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(themeManager.current.primaryText)
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
        }
        .frame(maxWidth: .infinity)
    }
}
