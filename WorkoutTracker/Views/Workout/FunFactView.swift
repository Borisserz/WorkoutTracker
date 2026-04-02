//
//  FunFactView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 2.04.26.
//

internal import SwiftUI

// This view shows a fun comparison for the total weight lifted
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
        VStack(spacing: 15) {
            Text(funFact.title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(funFact.value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            
            Text(funFact.emoji)
                .font(.largeTitle)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
}
