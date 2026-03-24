//
//  WeightHistoryView.swift
//  WorkoutTracker
//
//  Вью для отображения истории веса и графика
//

internal import SwiftUI
import SwiftData
import Charts

struct WeightHistoryView: View {
    // ИСПРАВЛЕНИЕ: Удаляем weightManager, используем нативные инструменты SwiftData
    @Environment(\.modelContext) private var context
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightHistory: [WeightEntry]
    
    @StateObject private var unitsManager = UnitsManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedPeriod: PeriodFilter = .month
    @State private var showingAddWeight = false
    @State private var newWeightText = ""
    @State private var newWeightDate = Date()
    
    enum PeriodFilter: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case threeMonths = "3 Months"
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            }
        }
    }
    
    var filteredHistory: [WeightEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -selectedPeriod.days, to: Date())!
        return weightHistory.filter { $0.date >= cutoff }
    }
    
    var chartData: [(date: Date, weight: Double)] {
        filteredHistory.map { entry in
            (date: entry.date, weight: unitsManager.convertFromKilograms(entry.weight))
        }
    }
    
    var stats: (startWeight: Double?, currentWeight: Double?, change: Double?) {
        guard let firstEntryWeight = weightHistory.last?.weight, // Массив отсортирован по убыванию, поэтому oldest это last
              let currentEntryWeight = weightHistory.first?.weight else {
            return (nil, nil, nil)
        }
        
        let start = unitsManager.convertFromKilograms(firstEntryWeight)
        let current = unitsManager.convertFromKilograms(currentEntryWeight)
        
        return (
            startWeight: start,
            currentWeight: current,
            change: current - start
        )
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Статистика
                    if !weightHistory.isEmpty {
                        HStack(spacing: 20) {
                            WeightStatCard(
                                title: LocalizedStringKey("Start"),
                                value: stats.startWeight != nil ? LocalizationHelper.shared.formatDecimal(stats.startWeight!) : "-",
                                unit: unitsManager.weightUnitString(),
                                color: Color.blue
                            )
                            
                            WeightStatCard(
                                title: LocalizedStringKey("Current"),
                                value: stats.currentWeight != nil ? LocalizationHelper.shared.formatDecimal(stats.currentWeight!) : "-",
                                unit: unitsManager.weightUnitString(),
                                color: Color.green
                            )
                            
                            WeightStatCard(
                                title: LocalizedStringKey("Change"),
                                value: stats.change != nil ? (stats.change! >= 0 ? "+" : "") + LocalizationHelper.shared.formatDecimal(stats.change!) : "-",
                                unit: unitsManager.weightUnitString(),
                                color: (stats.change ?? 0) >= 0 ? Color.green : Color.red
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    // Период фильтра
                    Picker(LocalizedStringKey("Period"), selection: $selectedPeriod) {
                        ForEach(PeriodFilter.allCases, id: \.self) { period in
                            Text(LocalizedStringKey(period.rawValue)).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // График
                    if !chartData.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(LocalizedStringKey("Weight Progress"))
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Chart {
                                ForEach(Array(chartData.enumerated()), id: \.offset) { index, data in
                                    if chartData.count > 1 {
                                        LineMark(
                                            x: .value("Date", data.date),
                                            y: .value("Weight", data.weight)
                                        )
                                        .foregroundStyle(.blue)
                                        .interpolationMethod(.linear)
                                        .lineStyle(StrokeStyle(lineWidth: 3))
                                    }
                                    
                                    PointMark(
                                        x: .value("Date", data.date),
                                        y: .value("Weight", data.weight)
                                    )
                                    .foregroundStyle(.blue)
                                    .symbolSize(chartData.count == 1 ? 50 : 30)
                                    .annotation(position: .top) {
                                        if selectedPeriod != .threeMonths {
                                            Text(LocalizationHelper.shared.formatDecimal(data.weight))
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .frame(height: 200)
                            .chartXAxis {
                                AxisMarks(values: .automatic) { _ in
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading) { _ in
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel()
                                }
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text(LocalizedStringKey("No weight data yet"))
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text(LocalizedStringKey("Add your weight to start tracking"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                    
                    // Список записей
                    if !filteredHistory.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(LocalizedStringKey("History"))
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(spacing: 0) {
                                ForEach(filteredHistory) { entry in
                                    WeightEntryRow(entry: entry, unitsManager: unitsManager)
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                context.delete(entry)
                                            } label: {
                                                Label(LocalizedStringKey("Delete"), systemImage: "trash")
                                            }
                                        }
                                    
                                    if entry.id != filteredHistory.last?.id {
                                        Divider().padding(.leading, 50)
                                    }
                                }
                            }
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(LocalizedStringKey("Weight Tracking"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Close")) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newWeightDate = Date()
                        if let latest = weightHistory.first?.weight {
                            newWeightText = LocalizationHelper.shared.formatDecimal(unitsManager.convertFromKilograms(latest))
                        } else {
                            newWeightText = ""
                        }
                        showingAddWeight = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert(LocalizedStringKey("Add Weight"), isPresented: $showingAddWeight) {
                VStack {
                    DatePicker("", selection: $newWeightDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                    TextField(
                        LocalizedStringKey("Weight (\(unitsManager.weightUnitString()))"),
                        text: $newWeightText
                    )
                    .keyboardType(.decimalPad)
                }
                Button(LocalizedStringKey("Save")) {
                    if let weight = Double(newWeightText.replacingOccurrences(of: ",", with: ".")) {
                        let weightInKg = unitsManager.convertToKilograms(weight)
                        let newEntry = WeightEntry(date: newWeightDate, weight: weightInKg)
                        context.insert(newEntry)
                    }
                }
                Button(LocalizedStringKey("Cancel"), role: .cancel) { }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct WeightStatCard: View {
    let title: LocalizedStringKey
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .bold()
                .foregroundColor(color)
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct WeightEntryRow: View {
    let entry: WeightEntry
    let unitsManager: UnitsManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatDate(entry.date))
                    .font(.body)
                Text(formatTime(entry.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(LocalizationHelper.shared.formatDecimal(unitsManager.convertFromKilograms(entry.weight))) \(unitsManager.weightUnitString())")
                .font(.headline)
                .foregroundColor(.blue)
        }
        .padding()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

