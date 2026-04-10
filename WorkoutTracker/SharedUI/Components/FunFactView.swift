// ============================================================
// FILE: WorkoutTracker/SharedUI/Components/FunFactView.swift
// ============================================================

internal import SwiftUI

// This view shows a fun, beautiful banner for the total weight lifted
struct FunFactView: View {
    let totalStrengthVolume: Double
    @Environment(UnitsManager.self) var unitsManager

    private var funFact: (title: LocalizedStringKey, value: String, emoji: String) {
        let kg = totalStrengthVolume
        let converted = unitsManager.convertFromKilograms(kg)
        let unit = unitsManager.weightUnitString()

        if kg > 1000 {
            return ("That's approximately", "\(String(format: "%.1f", converted / 1000)) tons", "🏋️")
        }
        return ("Way to go, champion! 🥇", "\(Int(converted)) \(unit)", "💪")
    }

    var body: some View {
        ZStack {
            // Премиальный градиентный фон
            LinearGradient(
                colors: [Color(hex: "4A00E0"), Color(hex: "8E2DE2")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Крупный эмодзи на фоне
            HStack {
                Spacer()
                Text(funFact.emoji)
                    .font(.system(size: 100))
                    .opacity(0.2)
                    .offset(x: 20, y: 15)
                    .rotationEffect(.degrees(15))
            }
            
            // Контент поверх
            VStack(alignment: .leading, spacing: 8) {
                Text(funFact.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.9))
                
                Text(funFact.value)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color(hex: "8E2DE2").opacity(0.4), radius: 15, x: 0, y: 8)
        .padding(.vertical, 10)
    }
}
