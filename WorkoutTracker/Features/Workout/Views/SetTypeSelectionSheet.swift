//
//  SetTypeSelectionSheet.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 6.04.26.
//

//
//  SetTypeSelectionSheet.swift
//  WorkoutTracker
//

internal import SwiftUI

struct SetTypeSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedType: SetType
    let onRemove: () -> Void
    
    @State private var infoToShow: LocalizedStringKey? = nil
    @State private var showInfoAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            Text(LocalizedStringKey("Select Set Type"))
                .font(.headline)
                .padding(.vertical, 20)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 0) {
                    typeRow(for: .warmup)
                    Divider().padding(.leading, 60)
                    typeRow(for: .normal)
                    Divider().padding(.leading, 60)
                    typeRow(for: .failure)
                    
                    Divider().padding(.vertical, 8)
                    
                    // Remove Set Action
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        dismiss()
                        
                        // slight delay to allow sheet to dismiss gracefully
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onRemove()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "xmark")
                                .font(.title3)
                                .foregroundColor(.red)
                                .frame(width: 30)
                            
                            Text(LocalizedStringKey("Remove Set"))
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .presentationDetents([.height(350)])
        .presentationDragIndicator(.visible)
        .alert(LocalizedStringKey("Set Type Info"), isPresented: $showInfoAlert) {
            Button(LocalizedStringKey("OK"), role: .cancel) { }
        } message: {
            if let info = infoToShow { Text(info) }
        }
    }
    
    private func typeRow(for type: SetType) -> some View {
        HStack {
            Button {
                let generator = UISelectionFeedbackGenerator()
                generator.selectionChanged()
                selectedType = type
                dismiss()
            } label: {
                HStack(spacing: 16) {
                    Text(type.shortIndicator(index: 1).prefix(1)) // Use "1" as placeholder for normal
                        .font(.headline)
                        .foregroundColor(type.displayColor)
                        .frame(width: 30)
                    
                    Text(type.title)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if selectedType == type {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                            .font(.headline)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Info Button
            Button {
                infoToShow = type.description
                showInfoAlert = true
            } label: {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.gray.opacity(0.5))
                    .font(.title3)
                    .padding(.leading, 8)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(selectedType == type ? Color.blue.opacity(0.05) : Color.clear)
    }
}
