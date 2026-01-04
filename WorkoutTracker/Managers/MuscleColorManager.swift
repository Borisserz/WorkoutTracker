//
//  MuscleColorManager.swift
//  WorkoutTracker
//
//  Менеджер для хранения пользовательских цветов групп мышц.
//  Отвечает за:
//  1. Хранение пользовательских цветов для групп мышц
//  2. Синхронизацию данных с UserDefaults (персистентность)
//  3. Предоставление дефолтных цветов, если пользователь не настроил свои
//

import Foundation
internal import SwiftUI
import UIKit
import Combine

class MuscleColorManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = MuscleColorManager()
    
    // MARK: - Published State
    
    /// Словарь с цветами: [Название группы мышц : [r, g, b, a]]
    @Published private(set) var colors: [String: [Double]] = [:]
    
    // MARK: - Constants
    
    private let userDefaultsKey = "muscleGroupColors"
    
    // Дефолтные цвета для групп мышц
    static let defaultColors: [String: Color] = [
        "Chest": .red,
        "Back": .blue,
        "Legs": .green,
        "Arms": .orange,
        "Shoulders": .purple,
        "Core": .pink,
        "Cardio": .cyan
    ]
    
    // MARK: - Init
    
    private init() {
        loadColors()
    }
    
    // MARK: - Public Methods
    
    /// Получить цвет для группы мышц
    func getColor(for muscleGroup: String) -> Color {
        if let rgba = colors[muscleGroup], rgba.count == 4 {
            return Color(
                red: rgba[0],
                green: rgba[1],
                blue: rgba[2],
                opacity: rgba[3]
            )
        }
        // Возвращаем дефолтный цвет или серый
        return Self.defaultColors[muscleGroup] ?? .gray
    }
    
    /// Установить цвет для группы мышц
    func setColor(_ color: Color, for muscleGroup: String) {
        let rgba = colorToRGBA(color)
        colors[muscleGroup] = rgba
        saveColors()
    }
    
    /// Сбросить цвет к дефолтному
    func resetColor(for muscleGroup: String) {
        colors.removeValue(forKey: muscleGroup)
        saveColors()
    }
    
    /// Сбросить все цвета к дефолтным
    func resetAllColors() {
        colors.removeAll()
        saveColors()
    }
    
    // MARK: - Persistence (UserDefaults)
    
    private func saveColors() {
        UserDefaults.standard.set(colors, forKey: userDefaultsKey)
        objectWillChange.send()
    }
    
    private func loadColors() {
        if let saved = UserDefaults.standard.dictionary(forKey: userDefaultsKey) as? [String: [Double]] {
            self.colors = saved
        } else {
            self.colors = [:]
        }
    }
    
    // MARK: - Helpers
    
    private func colorToRGBA(_ color: Color) -> [Double] {
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        return [Double(r), Double(g), Double(b), Double(a)]
    }
}
