internal import SwiftUI
import Foundation

// Расширение для использования URL в sheet(item:)
extension URL: Identifiable {
    public var id: String {
        self.absoluteString
    }
}

struct PresetListView: View {
    @EnvironmentObject var viewModel: WorkoutViewModel
    @State private var showCreatePreset = false
    @State private var presetToEdit: WorkoutPreset?
    @State private var fileToShare: URL?
    
    var body: some View {
        List {
            ForEach(viewModel.presets) { preset in
                Button {
                    presetToEdit = preset
                } label: {
                    HStack {
                        Image(preset.icon) // Если в Assets
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .cornerRadius(6)
                        
                        VStack(alignment: .leading) {
                            Text(preset.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("\(preset.exercises.count) exercises")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        
                        // --- КНОПКА ПОДЕЛИТЬСЯ (меню с выбором) ---
                        Menu {
                            // Экспорт в файл
                            Button {
                                if let fileURL = viewModel.exportPresetToFile(preset) {
                                    fileToShare = fileURL
                                }
                            } label: {
                                Label("Export as File", systemImage: "square.and.arrow.down")
                            }
                            
                            // Поделиться ссылкой
                            if let shareURL = viewModel.generateShareLink(for: preset) {
                                ShareLink(item: shareURL) {
                                    Label("Share Link", systemImage: "link")
                                }
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.blue)
                                .padding(8)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        // -------------------------
                        
                        // Кнопку редактирования можно перенести в swipeActions или оставить
                        Image(systemName: "pencil")
                            .foregroundColor(.gray)
                    }
                }
            }
            .onDelete { indexSet in
                viewModel.deletePreset(at: indexSet)
            }
        }
        .sheet(item: $fileToShare) { url in
            ActivityViewController(activityItems: [url])
                .presentationDetents([.medium, .large])
        }
        .navigationTitle("Templates")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreatePreset = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        // Создание нового
        .sheet(isPresented: $showCreatePreset) {
            PresetEditorView(preset: nil)
        }
        // Редактирование существующего
        .sheet(item: $presetToEdit) { preset in
            PresetEditorView(preset: preset)
        }
    }
}
