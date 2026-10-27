internal import SwiftUI

struct FunFactView: View {
    let totalStrengthVolume: Double
    @Environment(UnitsManager.self) var unitsManager

    private var funFact: (title: LocalizedStringKey, value: String, emoji: String) {
        let kg = totalStrengthVolume
        let converted = unitsManager.convertFromKilograms(kg)
        let unit = unitsManager.weightUnitString()

        if kg >= 14000 {
            let count = String(format: "%.1f", kg / 6000.0)
            return ("Equivalent to \(count) African Elephants", "Heavyweight Beast", "🐘")
        } else if kg >= 8000 {
            let count = String(format: "%.1f", kg / 1850.0)
            return ("Equivalent to \(count) Tesla Model 3s", "Electric Power", "⚡️")
        } else if kg >= 3000 {
            return ("Equivalent to a Ford F-150 Truck", "Industrial Strength", "🛻")
        } else if kg >= 1500 {
            return ("Equivalent to a Wild Hippopotamus", "Unstoppable Force", "🦛")
        } else if kg >= 600 {
            return ("Equivalent to a Concert Grand Piano", "Solid Tonnage", "🎹")
        } else if kg >= 250 {
            return ("Equivalent to a Silverback Gorilla", "Primal Power", "🦍")
        } else if kg > 0 {
            return ("\(LocalizationHelper.shared.formatInteger(converted)) \(unit) Lifted", "Every Rep Counts", "🔥")
        } else {
            return ("Ready to Move Mountains", "Start Your First Set", "💪")
        }
    }

    var body: some View {
        ZStack {
            PastelTheme.cardSurface

            HStack {
                Spacer()
                Text(funFact.emoji)
                    .font(.system(size: 84))
                    .opacity(0.12)
                    .offset(x: 10, y: 10)
                    .rotationEffect(.degrees(12))
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(funFact.emoji)
                        .font(.system(size: 16))
                    Text(funFact.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(PastelTheme.pastelAmber)
                        .lineLimit(1)
                }

                Text(funFact.value)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(PastelTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
        .padding(.vertical, 6)
    }
}
