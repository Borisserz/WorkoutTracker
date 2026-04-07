// ============================================================
// FILE: WorkoutTracker/Features/Profile/AddWeightSheet.swift
// ============================================================

internal import SwiftUI
import PhotosUI

struct AddWeightSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UserStatsViewModel.self) private var userStatsViewModel
    @Environment(UnitsManager.self) private var unitsManager
    @Environment(\.colorScheme) private var colorScheme
    
    let latestWeight: Double?
    
    @State private var date = Date()
    @State private var weightString = ""
    
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var isProcessingImage = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Premium Background
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        
                        // 1. GIGANTIC WEIGHT INPUT
                        VStack(spacing: 8) {
                            Text(LocalizedStringKey("Current Weight"))
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(1.5)
                            
                            HStack(alignment: .lastTextBaseline, spacing: 8) {
                                Spacer()
                                TextField("0.0", text: $weightString)
                                    .font(.system(size: 80, weight: .heavy, design: .rounded))
                                    .foregroundColor(.primary)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .fixedSize(horizontal: true, vertical: false)
                                
                                Text(unitsManager.weightUnitString())
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.blue)
                                Spacer()
                            }
                        }
                        .padding(.top, 40)
                        
                        // 2. STYLISH DATE PICKER
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "calendar")
                                    .foregroundColor(.blue)
                                    .font(.headline)
                            }
                            
                            DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                                .colorInvert() // Fix for dark mode inside light materials if needed
                                .colorMultiply(colorScheme == .dark ? .white : .black)
                            
                            Spacer()
                        }
                        .padding(16)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal, 24)
                        
                        // 3. PROGRESS PHOTOS GALLERY
                        VStack(alignment: .leading, spacing: 16) {
                            Text(LocalizedStringKey("Progress Photos"))
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 24)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    Spacer().frame(width: 8)
                                    
                                    // ADD PHOTO BUTTON
                                    if selectedImages.count < 4 {
                                        PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 4, matching: .images, photoLibrary: .shared()) {
                                            VStack(spacing: 12) {
                                                if isProcessingImage {
                                                    ProgressView()
                                                        .scaleEffect(1.5)
                                                } else {
                                                    Image(systemName: "camera.fill")
                                                        .font(.system(size: 32))
                                                    Text(LocalizedStringKey("Add"))
                                                        .font(.subheadline)
                                                        .fontWeight(.bold)
                                                }
                                            }
                                            .foregroundColor(.blue)
                                            .frame(width: 130, height: 170)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(20)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [6]))
                                            )
                                        }
                                        .disabled(isProcessingImage)
                                    }
                                    
                                    // SELECTED IMAGES
                                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 130, height: 170)
                                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                                            
                                            Button {
                                                let generator = UIImpactFeedbackGenerator(style: .light)
                                                generator.impactOccurred()
                                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                    selectedImages.remove(at: index)
                                                    selectedPhotoItems.remove(at: index)
                                                }
                                            } label: {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .padding(8)
                                                    .background(Color.black.opacity(0.6))
                                                    .clipShape(Circle())
                                                    .padding(8)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .transition(.scale.combined(with: .opacity))
                                    }
                                    
                                    Spacer().frame(width: 8)
                                }
                            }
                            
                            Text(LocalizedStringKey("Attach up to 4 photos to compare your progress later."))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 24)
                        }
                    }
                    .padding(.bottom, 120) // Space for the floating button
                }
            }
            .navigationTitle(LocalizedStringKey("Add Weight"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary, Color(UIColor.tertiarySystemFill))
                    }
                }
            }
            // FLOATING SAVE BUTTON
            .safeAreaInset(edge: .bottom) {
                Button(action: saveWeight) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                        Text(LocalizedStringKey("Save"))
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(weightString.isEmpty || isProcessingImage ? Color.gray : Color.blue)
                    .cornerRadius(20)
                    .shadow(color: (weightString.isEmpty || isProcessingImage ? Color.clear : Color.blue.opacity(0.4)), radius: 15, x: 0, y: 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 10)
                .disabled(weightString.isEmpty || isProcessingImage)
                .animation(.spring(), value: weightString.isEmpty)
            }
            .onAppear {
                if let lw = latestWeight {
                    weightString = LocalizationHelper.shared.formatFlexible(unitsManager.convertFromKilograms(lw))
                }
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                processSelectedPhotos(newItems)
            }
        }
    }
    
    // MARK: - Logic
    
    private func processSelectedPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        isProcessingImage = true
        
        Task.detached(priority: .userInitiated) {
            var loadedImages: [UIImage] = []
            
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    loadedImages.append(uiImage)
                }
            }
            
            await MainActor.run {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    self.selectedImages = loadedImages
                    self.isProcessingImage = false
                }
            }
        }
    }
    
    private func saveWeight() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        if let weightVal = Double(weightString.replacingOccurrences(of: ",", with: ".")) {
            let weightInKg = unitsManager.convertToKilograms(weightVal)
            let imagesToSave = selectedImages
            let entryDate = date
            
            Task {
                await userStatsViewModel.addWeightEntry(weight: weightInKg, date: entryDate, images: imagesToSave)
                dismiss()
            }
        }
    }
}
