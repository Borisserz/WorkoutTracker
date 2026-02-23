//
//  BackupManager.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 07.01.26.
//
//  Менеджер автоматического резервного копирования.
//  Отвечает за:
//  1. Создание резервных копий данных приложения.
//  2. Автоматическое резервное копирование по расписанию.
//  3. Управление историей резервных копий (ротация).
//  4. Восстановление данных из резервных копий.
//

import Foundation
import Combine

class BackupManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = BackupManager()
    
    // MARK: - Published Properties
    
    /// Список доступных резервных копий
    @Published private(set) var backups: [BackupInfo] = []
    
    /// Дата последнего резервного копирования
    @Published private(set) var lastBackupDate: Date?
    
    // MARK: - Settings Keys
    
    private let autoBackupEnabledKey = "autoBackupEnabled"
    private let backupFrequencyKey = "backupFrequency"
    private let maxBackupsKey = "maxBackupsCount"
    private let lastBackupDateKey = "lastBackupDate"
    
    // MARK: - Constants
    
    private let backupFolderName = "Backups"
    private let backupFileExtension = "workoutbackup"
    
    // MARK: - Computed Properties
    
    /// Включено ли автоматическое резервное копирование (зависит от частоты)
    var isAutoBackupEnabled: Bool {
        return backupFrequencyHours != BackupFrequency.never.rawValue
    }
    
    /// Частота резервного копирования (в часах, -1 = никогда)
    var backupFrequencyHours: Int {
        get {
            let saved = UserDefaults.standard.integer(forKey: backupFrequencyKey)
            // Если значение не установлено (0), возвращаем daily (24)
            // Если установлено -1 (never), возвращаем -1
            if saved == 0 && !UserDefaults.standard.bool(forKey: "hasSetupBackup") {
                return BackupFrequency.daily.rawValue
            }
            return saved
        }
        set {
            UserDefaults.standard.set(newValue, forKey: backupFrequencyKey)
            objectWillChange.send()
        }
    }
    
    /// Максимальное количество хранимых резервных копий
    var maxBackupsCount: Int {
        get {
            let saved = UserDefaults.standard.integer(forKey: maxBackupsKey)
            return saved > 0 ? saved : 7 // По умолчанию 7 копий
        }
        set {
            UserDefaults.standard.set(newValue, forKey: maxBackupsKey)
            cleanupOldBackups()
            objectWillChange.send()
        }
    }
    
    // MARK: - Backup Frequency Options
    
    enum BackupFrequency: Int, CaseIterable, Identifiable {
        case never = -1       // Никогда (отключено)
        case everyWorkout = 0 // После каждой тренировки
        case daily = 24
        case twiceWeekly = 84 // ~3.5 дня
        case weekly = 168
        
        var id: Int { rawValue }
        
        var displayName: String {
            switch self {
            case .never: return NSLocalizedString("Never", comment: "Backup frequency option - disabled")
            case .everyWorkout: return NSLocalizedString("After Each Workout", comment: "Backup frequency option")
            case .daily: return NSLocalizedString("Daily", comment: "Backup frequency option")
            case .twiceWeekly: return NSLocalizedString("Twice Weekly", comment: "Backup frequency option")
            case .weekly: return NSLocalizedString("Weekly", comment: "Backup frequency option")
            }
        }
    }
    
    // MARK: - Backup Info Model
    
    struct BackupInfo: Identifiable, Comparable {
        let id: UUID
        let date: Date
        let fileURL: URL
        let fileSize: Int64
        let workoutCount: Int
        
        static func < (lhs: BackupInfo, rhs: BackupInfo) -> Bool {
            lhs.date > rhs.date // Новые сверху
        }
        
        var formattedDate: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        
        var formattedSize: String {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: fileSize)
        }
    }
    
    // MARK: - Backup Data Model
    
    struct BackupData: Codable {
        let version: String
        let backupDate: Date
        let workouts: [Workout]
        let weightHistory: [WeightEntry]
        let customExercises: [CustomExerciseDefinition]
        let presets: [WorkoutPreset]
        let progress: ProgressData
        let exerciseNotes: [String: String]
        let deletedDefaultExercises: [String]
        
        struct ProgressData: Codable {
            let level: Int
            let totalXP: Int
        }
    }
    
    // MARK: - Init
    
    private init() {
        loadLastBackupDate()
        loadBackupsList()
        
        // Устанавливаем частоту по умолчанию при первом запуске
        if !UserDefaults.standard.bool(forKey: "hasSetupBackup") {
            backupFrequencyHours = BackupFrequency.daily.rawValue
            UserDefaults.standard.set(true, forKey: "hasSetupBackup")
        }
    }
    
    // MARK: - Path Helpers
    
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    private var backupDirectory: URL {
        let dir = getDocumentsDirectory().appendingPathComponent(backupFolderName)
        
        // Создаем папку, если не существует
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        
        return dir
    }
    
    // MARK: - Public Methods
    
    /// Проверяет, нужно ли создать резервную копию
    func shouldCreateBackup() -> Bool {
        // Если бэкап отключен (never = -1)
        guard isAutoBackupEnabled else { return false }
        
        // Если это первый бэкап
        guard let lastBackup = lastBackupDate else { return true }
        
        // Если частота = 0 (после каждой тренировки), всегда возвращаем true
        if backupFrequencyHours == BackupFrequency.everyWorkout.rawValue { return true }
        
        // Проверяем, прошло ли достаточно времени
        let hoursSinceLastBackup = Date().timeIntervalSince(lastBackup) / 3600
        return hoursSinceLastBackup >= Double(backupFrequencyHours)
    }
    
    /// Создает резервную копию всех данных приложения
    @discardableResult
    func createBackup(workouts: [Workout], viewModel: WorkoutViewModel) -> Bool {
        // Собираем все данные
        let weightHistory = WeightTrackingManager.shared.weightHistory
        let customExercises = viewModel.customExercises
        let presets = viewModel.presets
        let progress = BackupData.ProgressData(
            level: viewModel.progressManager.level,
            totalXP: viewModel.progressManager.totalXP
        )
        let exerciseNotes = ExerciseNotesManager.shared.notes
        let deletedDefaultExercises = Array(viewModel.deletedDefaultExercises)
        
        // Версия приложения
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        
        // Создаем структуру бэкапа
        let backupData = BackupData(
            version: appVersion,
            backupDate: Date(),
            workouts: workouts,
            weightHistory: weightHistory,
            customExercises: customExercises,
            presets: presets,
            progress: progress,
            exerciseNotes: exerciseNotes,
            deletedDefaultExercises: deletedDefaultExercises
        )
        
        // Кодируем в JSON
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(backupData)
            
            // Создаем имя файла с датой
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let fileName = "Backup_\(dateFormatter.string(from: Date())).\(backupFileExtension)"
            let fileURL = backupDirectory.appendingPathComponent(fileName)
            
            // Сохраняем файл
            try jsonData.write(to: fileURL)
            
            // Обновляем дату последнего бэкапа
            lastBackupDate = Date()
            saveLastBackupDate()
            
            // Обновляем список бэкапов
            loadBackupsList()
            
            // Удаляем старые бэкапы
            cleanupOldBackups()
            
            print("Backup created successfully: \(fileName)")
            return true
            
        } catch {
            print("Failed to create backup: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Восстанавливает данные из резервной копии
    func restoreBackup(_ backup: BackupInfo) -> BackupData? {
        do {
            let data = try Data(contentsOf: backup.fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let backupData = try decoder.decode(BackupData.self, from: data)
            return backupData
        } catch {
            print("Failed to restore backup: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Применяет восстановленные данные к приложению
    func applyRestoredData(_ backupData: BackupData, to viewModel: WorkoutViewModel) {
        // Восстанавливаем тренировки
        viewModel.workouts = backupData.workouts
        
        // Восстанавливаем историю веса
        WeightTrackingManager.shared.restoreWeightHistory(backupData.weightHistory)
        
        // Восстанавливаем пользовательские упражнения
        for exercise in backupData.customExercises {
            if !viewModel.customExercises.contains(where: { $0.name == exercise.name }) {
                viewModel.customExercises.append(exercise)
            }
        }
        
        // Восстанавливаем шаблоны
        for preset in backupData.presets {
            if !viewModel.presets.contains(where: { $0.id == preset.id }) {
                viewModel.presets.append(preset)
            }
        }
        
        // Восстанавливаем прогресс (если текущий меньше)
        if backupData.progress.totalXP > viewModel.progressManager.totalXP {
            viewModel.progressManager.restoreProgress(
                newLevel: backupData.progress.level,
                newTotalXP: backupData.progress.totalXP
            )
        }
        
        // Восстанавливаем заметки
        for (exerciseName, note) in backupData.exerciseNotes {
            ExerciseNotesManager.shared.setNote(note, for: exerciseName)
        }
        
        // Восстанавливаем удаленные упражнения
        for exerciseName in backupData.deletedDefaultExercises {
            viewModel.deletedDefaultExercises.insert(exerciseName)
        }
    }
    
    /// Удаляет резервную копию
    func deleteBackup(_ backup: BackupInfo) {
        do {
            try FileManager.default.removeItem(at: backup.fileURL)
            loadBackupsList()
            print("Backup deleted: \(backup.fileURL.lastPathComponent)")
        } catch {
            print("Failed to delete backup: \(error.localizedDescription)")
        }
    }
    
    /// Экспортирует резервную копию для шаринга
    func exportBackup(_ backup: BackupInfo) -> URL? {
        // Копируем в временную директорию с более понятным именем
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let exportName = "WorkoutTracker_Backup_\(dateFormatter.string(from: backup.date)).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(exportName)
        
        do {
            // Удаляем старый файл, если существует
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            try FileManager.default.copyItem(at: backup.fileURL, to: tempURL)
            return tempURL
        } catch {
            print("Failed to export backup: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Импортирует резервную копию из внешнего файла
    func importBackup(from url: URL) -> BackupData? {
        do {
            let data: Data
            
            // Проверяем, нужен ли security-scoped доступ
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                data = try Data(contentsOf: url)
            } else {
                data = try Data(contentsOf: url)
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let backupData = try decoder.decode(BackupData.self, from: data)
            return backupData
        } catch {
            print("Failed to import backup: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    private func loadLastBackupDate() {
        if let date = UserDefaults.standard.object(forKey: lastBackupDateKey) as? Date {
            lastBackupDate = date
        }
    }
    
    private func saveLastBackupDate() {
        UserDefaults.standard.set(lastBackupDate, forKey: lastBackupDateKey)
    }
    
    private func loadBackupsList() {
        var loadedBackups: [BackupInfo] = []
        
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: backupDirectory,
                includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            for fileURL in files where fileURL.pathExtension == backupFileExtension {
                // Получаем информацию о файле
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
                let fileSize = Int64(resourceValues.fileSize ?? 0)
                let creationDate = resourceValues.creationDate ?? Date()
                
                // Читаем количество тренировок из файла
                var workoutCount = 0
                if let data = try? Data(contentsOf: fileURL),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let workouts = json["workouts"] as? [[String: Any]] {
                    workoutCount = workouts.count
                }
                
                let backupInfo = BackupInfo(
                    id: UUID(),
                    date: creationDate,
                    fileURL: fileURL,
                    fileSize: fileSize,
                    workoutCount: workoutCount
                )
                loadedBackups.append(backupInfo)
            }
        } catch {
            print("Failed to load backups list: \(error.localizedDescription)")
        }
        
        DispatchQueue.main.async {
            self.backups = loadedBackups.sorted()
        }
    }
    
    private func cleanupOldBackups() {
        // Удаляем старые бэкапы, если их больше maxBackupsCount
        let sortedBackups = backups.sorted()
        
        if sortedBackups.count > maxBackupsCount {
            let backupsToDelete = sortedBackups.suffix(from: maxBackupsCount)
            for backup in backupsToDelete {
                deleteBackup(backup)
            }
        }
    }
}

// MARK: - WeightTrackingManager Extension

extension WeightTrackingManager {
    /// Восстанавливает историю веса из бэкапа
    func restoreWeightHistory(_ entries: [WeightEntry]) {
        let calendar = Calendar.current
        for entry in entries {
            // Проверяем, нет ли уже записи за этот день
            let existsForDay = weightHistory.contains { existingEntry in
                calendar.isDate(existingEntry.date, inSameDayAs: entry.date)
            }
            if !existsForDay {
                addWeightEntry(weight: entry.weight, date: entry.date)
            }
        }
    }
}

// MARK: - ProgressManager Extension

extension ProgressManager {
    /// Восстанавливает прогресс из бэкапа
    func restoreProgress(newLevel: Int, newTotalXP: Int) {
        // Используем UserDefaults напрямую, так как свойства private(set)
        UserDefaults.standard.set(newLevel, forKey: "userLevel")
        UserDefaults.standard.set(newTotalXP, forKey: "userTotalXP")
        // Перезагружаем данные
        objectWillChange.send()
    }
}

