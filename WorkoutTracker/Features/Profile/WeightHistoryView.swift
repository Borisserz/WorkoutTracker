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
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedPeriod: PeriodFilter = .month
    @State private var showingAddWeightSheet = false
    @State private var showingComparisonView = false
    
    // Для просмотра фото из списка
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
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                    
                    Picker(LocalizedStringKey("Period"), selection: $selectedPeriod) { ForEach(PeriodFilter.allCases, id: \.self) { p in Text(LocalizedStringKey(p.rawValue)).tag(p) } }
                        .pickerStyle(.segmented).padding(.horizontal)
                    
                    if !filteredHistory.isEmpty {
                        chartSection
                        listSection
                    } else {
                        emptyChartSection
                    }
                }
                .padding(.vertical)
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
        
        HStack(spacing: 20) {
            WeightStatCard(title: LocalizedStringKey("Start"), value: !weightHistory.isEmpty ? LocalizationHelper.shared.formatDecimal(fW) : "-", unit: unitsManager.weightUnitString(), color: .blue)
            WeightStatCard(title: LocalizedStringKey("Current"), value: !weightHistory.isEmpty ? LocalizationHelper.shared.formatDecimal(cW) : "-", unit: unitsManager.weightUnitString(), color: .green)
            WeightStatCard(title: LocalizedStringKey("Change"), value: !weightHistory.isEmpty ? (ch >= 0 ? "+" : "") + LocalizationHelper.shared.formatDecimal(ch) : "-", unit: unitsManager.weightUnitString(), color: ch >= 0 ? .green : .red)
        }.padding(.horizontal)
    }
    
    @ViewBuilder
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey("Weight Progress")).font(.headline).padding(.horizontal)
            Chart {
                ForEach(Array(filteredHistory.enumerated()), id: \.offset) { index, entry in
                    let weight = unitsManager.convertFromKilograms(entry.weight)
                    if filteredHistory.count > 1 { LineMark(x: .value("Date", entry.date), y: .value("Weight", weight)).foregroundStyle(.blue).interpolationMethod(.linear).lineStyle(StrokeStyle(lineWidth: 3)) }
                    PointMark(x: .value("Date", entry.date), y: .value("Weight", weight)).foregroundStyle(.blue).symbolSize(filteredHistory.count == 1 ? 50 : 30)
                        .annotation(position: .top) { if selectedPeriod != .threeMonths { Text(LocalizationHelper.shared.formatDecimal(weight)).font(.caption2).foregroundColor(.secondary) } }
                }
            }
            .frame(height: 200)
            .chartXAxis { AxisMarks(values: .automatic) { _ in AxisGridLine(); AxisTick(); AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true) } }
            .chartYAxis { AxisMarks(position: .leading) { _ in AxisGridLine(); AxisTick(); AxisValueLabel() } }
            .padding().background(Color(UIColor.secondarySystemBackground)).cornerRadius(12).padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var emptyChartSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 50)).foregroundColor(.gray)
            Text(LocalizedStringKey("No weight data yet")).font(.headline).foregroundColor(.secondary)
        }.frame(maxWidth: .infinity).padding(.vertical, 40)
    }

    @ViewBuilder
    private var listSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey("History")).font(.headline).padding(.horizontal)
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
                    
                    if entry.id != filteredHistory.last?.id { Divider().padding(.leading, 50) }
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

// MARK: - Subcomponents

struct WeightStatCard: View {
    let title: LocalizedStringKey; let value: String; let unit: String; let color: Color
    var body: some View {
        VStack(spacing: 5) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(value).font(.title2).bold().foregroundColor(color)
            Text(unit).font(.caption2).foregroundColor(.secondary)
        }.frame(maxWidth: .infinity).padding().background(Color(UIColor.secondarySystemBackground)).cornerRadius(12)
    }
}

struct WeightEntryRow: View {
    let entry: WeightEntry
    let unitsManager: UnitsManager
    
    @State private var loadedImage: UIImage? = nil
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.date, style: .date).font(.body)
                Text(entry.date, style: .time).font(.caption).foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.trailing, 8)
                
                if entry.imageFileNames.count > 1 {
                    Text("+\(entry.imageFileNames.count - 1)")
                        .font(.caption2)
                        .bold()
                        .foregroundColor(.secondary)
                        .padding(.trailing, 8)
                }
            }
            
            Text("\(LocalizationHelper.shared.formatDecimal(unitsManager.convertFromKilograms(entry.weight))) \(unitsManager.weightUnitString())")
                .font(.headline)
                .foregroundColor(.blue)
        }
        .padding()
        .contentShape(Rectangle())
        .task {
            // Грузим только первую картинку для превью
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
    @Environment(UnitsManager.self) private var unitsManager
    
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
        .preferredColorScheme(.dark)
    }
}
