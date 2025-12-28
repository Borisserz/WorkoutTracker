internal import SwiftUI

struct PresetListView: View {
    @EnvironmentObject var viewModel: WorkoutViewModel
    @State private var showCreatePreset = false
    @State private var presetToEdit: WorkoutPreset?
    
    var body: some View {
        List {
            ForEach(viewModel.presets) { preset in
                Button {
                    presetToEdit = preset
                } label: {
                    HStack {
                        Image(preset.icon) // Если используешь Assets
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .cornerRadius(6)
                            // Если иконки системные (SF Symbols), используй Image(systemName: preset.icon)
                            // Но у тебя в коде были Assets ("img_chest"), поэтому оставляю так.
                        
                        VStack(alignment: .leading) {
                            Text(preset.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("\(preset.exercises.count) exercises")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "pencil")
                            .foregroundColor(.gray)
                    }
                }
            }
            .onDelete { indexSet in
                viewModel.deletePreset(at: indexSet)
            }
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
