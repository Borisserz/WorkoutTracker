// ============================================================
// FILE: WorkoutTracker/Features/Profile/ProgressComparisonView.swift
// ============================================================

internal import SwiftUI

struct ProgressComparisonView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UnitsManager.self) private var unitsManager
    @Environment(\.colorScheme) private var colorScheme
    
    let entriesWithPhotos: [WeightEntry]
    
    @State private var leftEntry: WeightEntry?
    @State private var rightEntry: WeightEntry?
    
    @State private var leftImage: UIImage?
    @State private var rightImage: UIImage?
    
    @State private var showLeftPicker = false
    @State private var showRightPicker = false
    
        @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Интерактивный слайдер До/После
                    BeforeAfterSliderView(beforeImage: leftImage, afterImage: rightImage)
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                    
                    Spacer()
                    
                    // Плашка статистики (Glassmorphism)
                    infoPanel
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                }
            }
            .navigationTitle(LocalizedStringKey("Progress Pictures"))
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
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        // TODO: Добавить логику Share Sheet
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .fontWeight(.semibold)
                    }
                }
            }
            .onAppear { setupInitialEntries() }
            .onChange(of: leftEntry) { _, newEntry in loadLeftImage(for: newEntry) }
            .onChange(of: rightEntry) { _, newEntry in loadRightImage(for: newEntry) }
            .sheet(isPresented: $showLeftPicker) { photoPickerSheet(isLeft: true) }
            .sheet(isPresented: $showRightPicker) { photoPickerSheet(isLeft: false) }
        }
    }
    
    // MARK: - Subviews
    
    private var infoPanel: some View {
        ZStack {
            // Glass background
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
            
            HStack(alignment: .center) {
                // LEFT SIDE (Before)
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    showLeftPicker = true
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey("Before"))
                            .font(.caption)
                            .fontWeight(.bold)
                            .textCase(.uppercase)
                            .foregroundColor(themeManager.current.secondaryText)
                        
                        if let entry = leftEntry {
                            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundColor(themeManager.current.secondaryText)
                            let weight = unitsManager.convertFromKilograms(entry.weight)
                            Text("\(LocalizationHelper.shared.formatDecimal(weight)) \(unitsManager.weightUnitString())")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(themeManager.current.primaryText)
                        } else {
                            Text("-").font(.caption).foregroundColor(themeManager.current.secondaryText)
                            Text("-").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(themeManager.current.primaryText)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // RIGHT SIDE (After)
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    showRightPicker = true
                } label: {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(LocalizedStringKey("After"))
                            .font(.caption)
                            .fontWeight(.bold)
                            .textCase(.uppercase)
                            .foregroundColor(themeManager.current.secondaryText)
                        
                        if let entry = rightEntry {
                            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundColor(themeManager.current.secondaryText)
                            let weight = unitsManager.convertFromKilograms(entry.weight)
                            Text("\(LocalizationHelper.shared.formatDecimal(weight)) \(unitsManager.weightUnitString())")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(themeManager.current.primaryText)
                        } else {
                            Text("-").font(.caption).foregroundColor(themeManager.current.secondaryText)
                            Text("-").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(themeManager.current.primaryText)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            
            // CENTER BADGE
            if let l = leftEntry, let r = rightEntry {
                differenceBadge(left: l, right: r)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.1 : 0.4), lineWidth: 1)
        )
    }
    
    private func differenceBadge(left: WeightEntry, right: WeightEntry) -> some View {
        let diffKg = right.weight - left.weight
        let convertedDiff = unitsManager.convertFromKilograms(diffKg)
        let isLoss = diffKg < 0
        let color: Color = diffKg == 0 ? .gray : (isLoss ? .green : .red)
        
        let prefix = diffKg > 0 ? "+" : ""
        let diffStr = prefix + LocalizationHelper.shared.formatDecimal(convertedDiff) + " " + unitsManager.weightUnitString()
        
        return VStack {
            Text(diffStr)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(color.opacity(0.15))
                .foregroundColor(color)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 1))
                .shadow(color: color.opacity(0.2), radius: 5, x: 0, y: 2)
        }
    }
    
    private func photoPickerSheet(isLeft: Bool) -> some View {
        NavigationStack {
            List {
                ForEach(entriesWithPhotos.sorted(by: { $0.date > $1.date })) { entry in
                    Button {
                        let generator = UISelectionFeedbackGenerator()
                        generator.selectionChanged()
                        
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            if isLeft { leftEntry = entry } else { rightEntry = entry }
                        }
                        if isLeft { showLeftPicker = false } else { showRightPicker = false }
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.headline)
                                    .foregroundColor(themeManager.current.primaryText)
                                let weight = unitsManager.convertFromKilograms(entry.weight)
                                Text("\(LocalizationHelper.shared.formatDecimal(weight)) \(unitsManager.weightUnitString())")
                                    .font(.subheadline)
                                    .foregroundColor(themeManager.current.secondaryText)
                            }
                            Spacer()
                            if (isLeft && leftEntry?.id == entry.id) || (!isLeft && rightEntry?.id == entry.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(themeManager.current.primaryAccent)
                            }
                        }
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("Select Photo"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Cancel")) {
                        if isLeft { showLeftPicker = false } else { showRightPicker = false }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Logic
    
    private func setupInitialEntries() {
        let sorted = entriesWithPhotos.sorted { $0.date < $1.date }
        if sorted.count >= 2 {
            leftEntry = sorted.first
            rightEntry = sorted.last
        } else if sorted.count == 1 {
            leftEntry = sorted.first
        }
    }
    
    private func loadLeftImage(for entry: WeightEntry?) {
        guard let fileName = entry?.imageFileNames.first else { leftImage = nil; return }
        Task { leftImage = await LocalImageStore.shared.loadImage(named: fileName) }
    }
    
    private func loadRightImage(for entry: WeightEntry?) {
        guard let fileName = entry?.imageFileNames.first else { rightImage = nil; return }
        Task { rightImage = await LocalImageStore.shared.loadImage(named: fileName) }
    }
}

// MARK: - Interactive Before/After Slider
// MARK: - Interactive Before/After Slider
struct BeforeAfterSliderView: View {
    let beforeImage: UIImage?
    let afterImage: UIImage?
    
    @State private var sliderPercentage: CGFloat = 0.5
    @State private var isDragging: Bool = false
    
        @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background Image (After)
                if let after = afterImage {
                    Image(uiImage: after)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    placeholderView(title: "After")
                        .frame(width: geo.size.width, height: geo.size.height)
                }
                
                // Overlay Image (Before)
                if let before = beforeImage {
                    Image(uiImage: before)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        // ✅ ИСПРАВЛЕНИЕ: Новый синтаксис .mask
                        .mask(alignment: .leading) {
                            Rectangle()
                                .frame(width: geo.size.width * sliderPercentage, height: geo.size.height)
                        }
                } else {
                    placeholderView(title: "Before")
                        .frame(width: geo.size.width, height: geo.size.height)
                        // ✅ ИСПРАВЛЕНИЕ: Новый синтаксис .mask
                        .mask(alignment: .leading) {
                            Rectangle()
                                .frame(width: geo.size.width * sliderPercentage, height: geo.size.height)
                        }
                }
                
                // Slider Line & Thumb
                ZStack {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 4, height: geo.size.height)
                        .shadow(color: .black.opacity(0.4), radius: 5, x: 0, y: 0)
                    
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .overlay(
                            Image(systemName: "chevron.left.and.right")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(themeManager.current.background)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        .scaleEffect(isDragging ? 1.1 : 1.0)
                }
                .position(x: geo.size.width * sliderPercentage, y: geo.size.height / 2)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            withAnimation(.interactiveSpring()) {
                                isDragging = true
                                // Limit slider bounds
                                sliderPercentage = min(max(0.02, value.location.x / geo.size.width), 0.98)
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isDragging = false
                            }
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    private func placeholderView(title: String) -> some View {
        ZStack {
            Color.gray.opacity(0.2)
            VStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 50))
                Text("Select \(title) Photo")
                    .font(.headline)
            }
            .foregroundColor(themeManager.current.secondaryAccent.opacity(0.6))
        }
    }
}
