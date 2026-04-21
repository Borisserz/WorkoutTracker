// ============================================================
// FILE: WorkoutTracker/Features/Profile/WeightHistoryView.swift
// ============================================================

internal import SwiftUI
import SwiftData
import Charts

struct WeightHistoryView: View {
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightHistory: [WeightEntry]
    @Environment(UserStatsViewModel.self) var userStatsViewModel
    @Environment(UnitsManager.self) var unitsManager
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme // 👈 АДАПТАЦИЯ ТЕМЫ
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedPeriod: PeriodFilter = .month
    @State private var showingAddWeightSheet = false
    @State private var showingComparisonView = false
    
    @State private var selectedEntryForGallery: WeightEntry? = nil
    
    enum PeriodFilter: String, CaseIterable {
        case week = "Week", month = "Month", threeMonths = "3 Months"
        var days: Int { self == .week ? 7 : (self == .month ? 30 : 90) }
    }
    
    var filteredHistory: [WeightEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -selectedPeriod.days, to: Date())!
        return weightHistory.filter { $0.date >= cutoff }
    }
    
    var photosAvailable: Bool {
        weightHistory.filter { !$0.imageFileNames.isEmpty }.count >= 2
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 👈 Адаптивный фон всего экрана
                (colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color(UIColor.secondarySystemBackground))
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        if !weightHistory.isEmpty { statsHeaderSection }
                        
                        if photosAvailable {
                            Button {
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                showingComparisonView = true
                            } label: {
                                HStack {
                                    Image(systemName: "photo.on.rectangle.angled")
                                    Text(LocalizedStringKey("Compare Progress Photos"))
                                        .bold()
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(themeManager.current.primaryAccent.opacity(0.1))
                                .foregroundColor(themeManager.current.primaryAccent)
                                .cornerRadius(16)
                                .padding(.horizontal)
                            }
                        }
                        
                        Picker(LocalizedStringKey("Period"), selection: $selectedPeriod) {
                            ForEach(PeriodFilter.allCases, id: \.self) { p in Text(LocalizedStringKey(p.rawValue)).tag(p) }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        
                        if !filteredHistory.isEmpty {
                            chartSection
                            listSection
                        } else {
                            emptyChartSection
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle(LocalizedStringKey("Weight Tracking"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(LocalizedStringKey("Close")) { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAddWeightSheet = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAddWeightSheet) {
                AddWeightSheet(latestWeight: weightHistory.first?.weight)
            }
            .fullScreenCover(isPresented: $showingComparisonView) {
                ProgressComparisonView(entriesWithPhotos: weightHistory.filter { !$0.imageFileNames.isEmpty })
            }
            .sheet(item: $selectedEntryForGallery) { entry in
                WeightPhotoGalleryView(entry: entry)
            }
        }
    }
    
    // MARK: - Sections
    
    @ViewBuilder
    private var statsHeaderSection: some View {
        let fW = unitsManager.convertFromKilograms(weightHistory.last?.weight ?? 0)
        let cW = unitsManager.convertFromKilograms(weightHistory.first?.weight ?? 0)
        let ch = cW - fW
        
        HStack(spacing: 16) {
            WeightStatCard(title: LocalizedStringKey("Start"), value: !weightHistory.isEmpty ? LocalizationHelper.shared.formatDecimal(fW) : "-", unit: unitsManager.weightUnitString(), color: themeManager.current.primaryAccent)
            WeightStatCard(title: LocalizedStringKey("Current"), value: !weightHistory.isEmpty ? LocalizationHelper.shared.formatDecimal(cW) : "-", unit: unitsManager.weightUnitString(), color: .green)
            WeightStatCard(title: LocalizedStringKey("Change"), value: !weightHistory.isEmpty ? (ch >= 0 ? "+" : "") + LocalizationHelper.shared.formatDecimal(ch) : "-", unit: unitsManager.weightUnitString(), color: ch >= 0 ? .green : .red)
        }.padding(.horizontal)
    }
    
    @ViewBuilder
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey("Weight Progress"))
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .padding(.horizontal)
            
            Chart {
                ForEach(Array(filteredHistory.enumerated()), id: \.offset) { index, entry in
                    let weight = unitsManager.convertFromKilograms(entry.weight)
                    if filteredHistory.count > 1 {
                        LineMark(x: .value("Date", entry.date), y: .value("Weight", weight))
                            .foregroundStyle(themeManager.current.primaryAccent)
                            .interpolationMethod(.linear)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                        
                        AreaMark(x: .value("Date", entry.date), y: .value("Weight", weight))
                            .foregroundStyle(LinearGradient(colors: [themeManager.current.primaryAccent.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                    }
                    PointMark(x: .value("Date", entry.date), y: .value("Weight", weight))
                        .foregroundStyle(themeManager.current.primaryAccent)
                        .symbolSize(filteredHistory.count == 1 ? 50 : 30)
                        .annotation(position: .top) {
                            if selectedPeriod != .threeMonths {
                                Text(LocalizationHelper.shared.formatDecimal(weight)).font(.caption2).foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                            }
                        }
                }
            }
            .frame(height: 200)
            .chartXAxis { AxisMarks(values: .automatic) { _ in AxisGridLine(); AxisTick(); AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true) } }
            .chartYAxis { AxisMarks(position: .leading) { _ in AxisGridLine(); AxisTick(); AxisValueLabel() } }
            .padding()
            // 👈 АДАПТАЦИЯ
            .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05), lineWidth: 1))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 5, y: 2)
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var emptyChartSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 50))
                .foregroundColor(themeManager.current.secondaryAccent.opacity(0.5))
            Text(LocalizedStringKey("No weight data yet"))
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .black)
        }.frame(maxWidth: .infinity).padding(.vertical, 60)
    }

    @ViewBuilder
    private var listSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey("History"))
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                ForEach(filteredHistory) { entry in
                    Button {
                        if !entry.imageFileNames.isEmpty {
                            selectedEntryForGallery = entry
                        }
                    } label: {
                        WeightEntryRow(entry: entry, unitsManager: unitsManager)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            Task { await userStatsViewModel.deleteWeightEntry(entry.persistentModelID) }
                        } label: { Label(LocalizedStringKey("Delete"), systemImage: "trash") }
                    }
                    
                    if entry.id != filteredHistory.last?.id {
                        Divider()
                            .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                            .padding(.leading, 50)
                    }
                }
            }
            // 👈 АДАПТАЦИЯ
            .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05), lineWidth: 1))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 5, y: 2)
            .padding(.horizontal)
        }
    }
}

// MARK: - Subcomponents

struct WeightStatCard: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme // 👈
    let title: LocalizedStringKey; let value: String; let unit: String; let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.caption).foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray).textCase(.uppercase)
            Text(value).font(.title2).bold().foregroundColor(colorScheme == .dark ? color : .black) // В светлой теме цветные цифры плохо читаются, делаем черными
            Text(unit).font(.caption2).fontWeight(.bold).foregroundColor(color) // Цвет переносим на единицу измерения
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        // 👈 АДАПТАЦИЯ
        .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05), lineWidth: 1))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 5, y: 2)
    }
}

struct WeightEntryRow: View {
    let entry: WeightEntry
    let unitsManager: UnitsManager
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme // 👈
    @State private var loadedImage: UIImage? = nil
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.date, style: .date)
                    .font(.body).bold()
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                Text(entry.date, style: .time)
                    .font(.caption)
                    .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
            }
            
            Spacer()
            
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.1), radius: 3)
                    .padding(.trailing, 8)
                
                if entry.imageFileNames.count > 1 {
                    Text("+\(entry.imageFileNames.count - 1)")
                        .font(.caption2).bold()
                        .foregroundColor(themeManager.current.secondaryText)
                        .padding(.trailing, 8)
                }
            }
            
            let w = unitsManager.convertFromKilograms(entry.weight)
            Text("\(LocalizationHelper.shared.formatDecimal(w)) \(unitsManager.weightUnitString())")
                .font(.headline)
                .foregroundColor(themeManager.current.primaryAccent)
        }
        .padding(16)
        .contentShape(Rectangle())
        .task {
            if let firstFileName = entry.imageFileNames.first {
                self.loadedImage = await LocalImageStore.shared.loadImage(named: firstFileName)
            }
        }
    }
}
// MARK: - Photo Gallery Sheet
struct WeightPhotoGalleryView: View {
    let entry: WeightEntry
    @Environment(\.dismiss) private var dismiss
    
    @State private var images: [UIImage] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if images.isEmpty {
                    ProgressView().tint(.white)
                } else {
                    TabView {
                        ForEach(images, id: \.self) { image in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                }
            }
            .navigationTitle(entry.date.formatted(date: .abbreviated, time: .omitted))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Close")) { dismiss() }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                var loaded: [UIImage] = []
                for fileName in entry.imageFileNames {
                    if let img = await LocalImageStore.shared.loadImage(named: fileName) {
                        loaded.append(img)
                    }
                }
                await MainActor.run { self.images = loaded }
            }
        }
        .preferredColorScheme(.dark) // Галерея фото всегда в темной теме (как в iOS Photos)
    }
}
