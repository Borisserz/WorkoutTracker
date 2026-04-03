// ============================================================
// FILE: WorkoutTracker/Views/Settings/PresetListView.swift
// ============================================================

internal import SwiftUI
import SwiftData

struct PresetListView: View {
    @Environment(\.modelContext) private var context
    @Environment(PresetService.self) var presetService // ✅ ИСПРАВЛЕНИЕ: Используем новый сервис
    
    @Query(sort: \WorkoutPreset.name) private var presets: [WorkoutPreset]
    
    @State private var showCreatePreset = false
    @State private var presetToEdit: WorkoutPreset?
    @State private var fileToShare: SharedFileWrapper?
    @State private var showDeleteAlert = false
    @State private var presetsToDelete: IndexSet?
    
    var body: some View {
        List {
            ForEach(presets) { preset in
                Button {
                    presetToEdit = preset
                } label: {
                    HStack {
                        Image(preset.icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .cornerRadius(6)
                        
                        VStack(alignment: .leading) {
                            Text(preset.name).font(.headline).foregroundColor(.primary)
                            Text("\(preset.exercises.count) exercises").font(.caption).foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Menu {
                            Menu {
                                Button {
                                    Task {
                                        if let fileURL = try? await presetService.exportPresetToFile(preset) {
                                            await MainActor.run { fileToShare = SharedFileWrapper(url: fileURL) }
                                        }
                                    }
                                } label: { Label(LocalizedStringKey("Export as JSON"), systemImage: "doc.text") }
                                
                                Button {
                                    Task {
                                        if let fileURL = try? await presetService.exportPresetToCSV(preset) {
                                            await MainActor.run { fileToShare = SharedFileWrapper(url: fileURL) }
                                        }
                                    }
                                } label: { Label(LocalizedStringKey("Export as CSV"), systemImage: "tablecells") }
                            } label: { Label(LocalizedStringKey("Export as File"), systemImage: "square.and.arrow.down") }
                            
                            if let shareURL = try? presetService.generateShareLink(for: preset) {
                                ShareLink(item: shareURL) { Label(LocalizedStringKey("Share Link"), systemImage: "link") }
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up").foregroundColor(.blue).font(.body).padding(8)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        
                        Image(systemName: "pencil").foregroundColor(.secondary).font(.body)
                    }
                }
            }
            .onDelete { indexSet in
                presetsToDelete = indexSet
                showDeleteAlert = true
            }
        }
        .navigationTitle(LocalizedStringKey("Templates"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showCreatePreset = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(item: $fileToShare) { wrapper in
            ActivityViewController(activityItems: [wrapper.url]).presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showCreatePreset) { PresetEditorView(preset: nil) }
        .sheet(item: $presetToEdit) { preset in PresetEditorView(preset: preset) }
        .alert(LocalizedStringKey("Delete Template?"), isPresented: $showDeleteAlert) {
            Button(LocalizedStringKey("Delete"), role: .destructive) {
                if let indexSet = presetsToDelete {
                    for index in indexSet {
                        let presetToDelete = presets[index]
                        Task { await presetService.deletePreset(presetToDelete) }
                    }
                    presetsToDelete = nil
                }
            }
            Button(LocalizedStringKey("Cancel"), role: .cancel) { presetsToDelete = nil }
        } message: {
            Text(LocalizedStringKey("Are you sure you want to delete this template? This action cannot be undone."))
        }
    }
}
