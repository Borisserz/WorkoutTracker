internal import SwiftUI

struct EditMetricsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("userAge") private var age: Int = 25
    @AppStorage("userHeight") private var height: Int = 175
    @AppStorage("userBodyWeight") private var weight: Double = 75.0

    // Local state for editing before saving
    @State private var draftAge: Int = 25
    @State private var draftHeight: Int = 175
    @State private var draftWeight: Int = 75

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(colorScheme == .dark ? UIColor.systemBackground : UIColor.secondarySystemGroupedBackground).ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        
                        VStack(spacing: 8) {
                            Text("Your Metrics")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(themeManager.current.primaryText)
                            Text("Update your basic body parameters")
                                .font(.system(size: 15))
                                .foregroundColor(themeManager.current.secondaryText)
                        }
                        .padding(.top, 40)
                        
                        HStack(spacing: 0) {
                            MetricsWheelColumn(title: "Age", range: 14...100, suffix: "yrs", selection: $draftAge)
                            MetricsWheelColumn(title: "Height", range: 140...230, suffix: "cm", selection: $draftHeight)
                            MetricsWheelColumn(title: "Weight", range: 40...200, suffix: "kg", selection: $draftWeight)
                        }
                        .frame(height: 220)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 120)
                    }
                }
                
                Button(action: saveAndDismiss) {
                    Text("Save Changes")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(themeManager.current.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(themeManager.current.primaryGradient)
                        .cornerRadius(20)
                        .shadow(color: themeManager.current.primaryAccent.opacity(0.3), radius: 10, y: 5)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .background(
                    LinearGradient(
                        colors: [Color(colorScheme == .dark ? UIColor.systemBackground : UIColor.secondarySystemGroupedBackground), Color(colorScheme == .dark ? UIColor.systemBackground : UIColor.secondarySystemGroupedBackground).opacity(0)],
                        startPoint: .bottom, endPoint: .top
                    )
                )
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }
            }
            .onAppear {
                draftAge = age
                draftHeight = height
                draftWeight = Int(weight)
            }
        }
    }
    
    private func saveAndDismiss() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        age = draftAge
        height = draftHeight
        weight = Double(draftWeight)
        
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
