// ============================================================
// FILE: WatchApp/Views/WatchExerciseSelectionView.swift
// ============================================================
internal import SwiftUI
import SwiftData

struct WatchExerciseSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    var onSelect: (String) -> Void
    
    @State private var allExercises: [String] = []
    @State private var isLoading: Bool = true // 🛠️ FIX: Явный стейт загрузки
    
    var body: some View {
        NavigationStack {
            ZStack {
                WatchTheme.background.ignoresSafeArea()
                
                if isLoading {
                    VStack {
                        ProgressView()
                            .tint(WatchTheme.cyan)
                        Text("Loading catalog...")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                    }
                } else if allExercises.isEmpty {
                    // 🛠️ FIX: Обработка случая, когда база действительно пуста
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("No exercises found.\nSync from iPhone.")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                    }
                } else {
                    List(allExercises, id: \.self) { name in
                        Button {
                            WKInterfaceDevice.current().play(.click)
                            onSelect(name)
                        } label: {
                            Text(name)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                        }
                        .listRowBackground(WatchTheme.cardBackground)
                    }
                }
            }
            .navigationTitle("Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadFullCatalog()
            }
        }
    }
    
    private func loadFullCatalog() async {
        isLoading = true
        
        // 🛠️ FIX: Защита от бесконечного зависания с помощью Race/Timeout
        let catalogTask = Task { () -> [String] in
            let catalog = await ExerciseDatabaseService.shared.getCatalog()
            var uniqueNames = Set(catalog.values.flatMap { $0 })
            
            let descriptor = FetchDescriptor<ExerciseDictionaryItem>()
            if let dbItems = try? context.fetch(descriptor) {
                for item in dbItems {
                    if item.isHidden && !item.isCustom {
                        uniqueNames.remove(item.name)
                    } else if item.isCustom && !item.isHidden {
                        uniqueNames.insert(item.name)
                    }
                }
            }
            return Array(uniqueNames).sorted()
        }
        
        do {
            // Ждем максимум 5 секунд, иначе отдаем пустой массив
            let result = try await withThrowingTaskGroup(of: [String].self) { group in
                group.addTask { return await catalogTask.value }
                group.addTask {
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                    throw CancellationError()
                }
                let firstResult = try await group.next()!
                group.cancelAll()
                return firstResult
            }
            
            await MainActor.run {
                self.allExercises = result
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.allExercises = []
                self.isLoading = false
            }
        }
    }
}
