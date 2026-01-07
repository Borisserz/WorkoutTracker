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
    @State private var showDeleteAlert = false
    @State private var presetsToDelete: IndexSet?
    
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
                            Text(LocalizedStringKey("\(preset.exercises.count) exercises"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        
                        // --- КНОПКА ПОДЕЛИТЬСЯ (меню с выбором) ---
                        Menu {
                            // Экспорт в файл - подменю с выбором формата
                            Menu {
                                Button {
                                    if let fileURL = viewModel.exportPresetToFile(preset) {
                                        fileToShare = fileURL
                                    }
                                } label: {
                                    Label(LocalizedStringKey("Export as JSON"), systemImage: "doc.text")
                                }
                                
                                Button {
                                    if let fileURL = viewModel.exportPresetToCSV(preset) {
                                        fileToShare = fileURL
                                    }
                                } label: {
                                    Label(LocalizedStringKey("Export as CSV"), systemImage: "tablecells")
                                }
                            } label: {
                                Label(LocalizedStringKey("Export as File"), systemImage: "square.and.arrow.down")
                            }
                            
                            // Поделиться ссылкой
                            if let shareURL = viewModel.generateShareLink(for: preset) {
                                ShareLink(item: shareURL) {
                                    Label(LocalizedStringKey("Share Link"), systemImage: "link")
                                }
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.secondary)
                                .font(.body)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        // -------------------------
                        
                        // Кнопку редактирования можно перенести в swipeActions или оставить
                        Image(systemName: "pencil")
                            .foregroundColor(.secondary)
                            .font(.body)
                    }
                }
            }
            .onDelete { indexSet in
                presetsToDelete = indexSet
                showDeleteAlert = true
            }
        }
        .sheet(item: $fileToShare) { url in
            ActivityViewController(activityItems: [url])
                .presentationDetents([.medium, .large])
        }
        .navigationTitle(LocalizedStringKey("Templates"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreatePreset = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(.primary)
                        .font(.body)
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
        .alert(LocalizedStringKey("Delete Template?"), isPresented: $showDeleteAlert) {
            Button(LocalizedStringKey("Delete"), role: .destructive) {
                if let indexSet = presetsToDelete {
                    viewModel.deletePreset(at: indexSet)
                    presetsToDelete = nil
                }
            }
            Button(LocalizedStringKey("Cancel"), role: .cancel) {
                presetsToDelete = nil
            }
        } message: {
            if let indexSet = presetsToDelete {
                let count = indexSet.count
                if count == 1 {
                    if let firstIndex = indexSet.first, firstIndex < viewModel.presets.count {
                        Text(LocalizedStringKey("Are you sure you want to delete '\(viewModel.presets[firstIndex].name)'? This action cannot be undone."))
                    } else {
                        Text(LocalizedStringKey("Are you sure you want to delete this template? This action cannot be undone."))
                    }
                } else {
                    Text(LocalizedStringKey("Are you sure you want to delete \(count) templates? This action cannot be undone."))
                }
            } else {
                Text(LocalizedStringKey("Are you sure you want to delete this template? This action cannot be undone."))
            }
        }
    }
}
