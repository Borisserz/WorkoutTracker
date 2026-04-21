// ============================================================
// FILE: WorkoutTracker/Features/Profile/AddWeightSheet.swift
// ============================================================

internal import SwiftUI
import SwiftData
import PhotosUI

struct AddWeightSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UserStatsViewModel.self) private var userStatsViewModel
    @Environment(UnitsManager.self) private var unitsManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager
    
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightHistory: [WeightEntry]
    let latestWeight: Double?
    
    @State private var date = Date()
    @State private var weightString = ""
    @State private var showSmartCamera = false
    @State private var previousPhotoRef: UIImage? = nil
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var isProcessingImage = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                // 👈 АДАПТИВНЫЙ ФОН
                (colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color(UIColor.secondarySystemBackground))
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        weightInputSection
                        datePickerSection
                        photoGallerySection
                    }
                    .padding(.bottom, 120)
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
            .fullScreenCover(isPresented: $showSmartCamera) {
                SmartCaptureView(referenceImage: previousPhotoRef) { capturedImage in
                    withAnimation(.spring()) {
                        self.selectedImages.append(capturedImage)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                floatingSaveButton
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
    
    // MARK: - View Components
    
    private var weightInputSection: some View {
        VStack(spacing: 8) {
            Text(LocalizedStringKey("Current Weight"))
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                .textCase(.uppercase)
                .tracking(1.5)
            
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Spacer()
                TextField("0.0", text: $weightString)
                    .font(.system(size: 80, weight: .heavy, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .black)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: true, vertical: false)
                
                Text(unitsManager.weightUnitString())
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.current.primaryAccent)
                Spacer()
            }
        }
        .padding(.top, 40)
    }
    
    private var datePickerSection: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(themeManager.current.primaryAccent.opacity(0.15))
                Image(systemName: "calendar")
                    .foregroundColor(themeManager.current.primaryAccent)
                    .font(.headline)
            }
            .frame(width: 40, height: 40)
            
            Spacer()
            
            // 👈 ИСПРАВЛЕНИЕ: Убрали .colorInvert() и .colorMultiply(), из-за которых ломалась светлая тема
            DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .environment(\.colorScheme, colorScheme) // Явно передаем текущую схему
        }
        .padding(16)
        // 👈 АДАПТИВНЫЙ ФОН КАРТОЧКИ
        .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05), lineWidth: 1))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal, 24)
    }
    
    private var photoGallerySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedStringKey("Progress Photos"))
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .padding(.horizontal, 24)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    Spacer().frame(width: 8)
                    
                    if selectedImages.count < 4 {
                        Menu {
                            Button {
                                loadReferenceAndOpenSmartCamera()
                            } label: {
                                Label(LocalizedStringKey("Smart Camera (Ghost)"), systemImage: "camera.viewfinder")
                            }
                            
                            PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 4 - selectedImages.count, matching: .images, photoLibrary: .shared()) {
                                Label(LocalizedStringKey("Choose from Library"), systemImage: "photo.on.rectangle")
                            }
                        } label: {
                            VStack(spacing: 12) {
                                if isProcessingImage {
                                    ProgressView().scaleEffect(1.5)
                                } else {
                                    Image(systemName: "camera.fill").font(.system(size: 32))
                                    Text(LocalizedStringKey("Add")).font(.subheadline).fontWeight(.bold)
                                }
                            }
                            .foregroundColor(themeManager.current.primaryAccent)
                            .frame(width: 130, height: 170)
                            .background(themeManager.current.primaryAccent.opacity(0.1))
                            .cornerRadius(20)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(themeManager.current.primaryAccent.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [6])))
                        }
                        .disabled(isProcessingImage)
                    }
                    
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
                                    if index < selectedPhotoItems.count {
                                        selectedPhotoItems.remove(at: index)
                                    }
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
                .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                .padding(.horizontal, 24)
        }
    }
    
    private var floatingSaveButton: some View {
        Button(action: saveWeight) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill").font(.title3)
                Text(LocalizedStringKey("Save")).font(.title3).fontWeight(.bold)
            }
            .foregroundColor(.white) // Кнопка всегда белая
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(weightString.isEmpty || isProcessingImage ? Color.gray : themeManager.current.primaryAccent)
            .cornerRadius(20)
            .shadow(color: (weightString.isEmpty || isProcessingImage ? Color.clear : themeManager.current.primaryAccent.opacity(0.4)), radius: 15, x: 0, y: 8)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
        .disabled(weightString.isEmpty || isProcessingImage)
        .animation(.spring(), value: weightString.isEmpty)
        .background(
            LinearGradient(colors: [colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color(UIColor.secondarySystemBackground), .clear], startPoint: .bottom, endPoint: .top)
                .ignoresSafeArea()
        )
    }
    
    // MARK: - Logic
    
    private func loadReferenceAndOpenSmartCamera() {
        Task {
            if let lastEntry = weightHistory.first(where: { !$0.imageFileNames.isEmpty }),
               let fileName = lastEntry.imageFileNames.first {
                self.previousPhotoRef = await LocalImageStore.shared.loadImage(named: fileName)
            } else {
                self.previousPhotoRef = nil
            }
            await MainActor.run { showSmartCamera = true }
        }
    }
    
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
                    self.selectedImages.append(contentsOf: loadedImages)
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
            Task {
                await userStatsViewModel.addWeightEntry(weight: weightInKg, date: date, images: selectedImages)
                dismiss()
            }
        }
    }
}
