// ============================================================
// FILE: WorkoutTracker/Features/Profile/BodyMeasurementsView.swift
// ============================================================

internal import SwiftUI
import SwiftData
import Charts

struct BodyMeasurementsView: View {
    @Environment(UserStatsViewModel.self) var userStatsViewModel
    @Environment(\.modelContext) private var context
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]
    @Environment(UnitsManager.self) var unitsManager
    @Environment(\.dismiss) var dismiss

    @State private var selectedMetric: MeasurementType = .bodyFat
    @State private var selectedPeriod: PeriodFilter = .sixMonths
    @State private var showingAddMeasurement = false
    
    enum PeriodFilter: String, CaseIterable {
        case month = "1M", threeMonths = "3M", sixMonths = "6M", year = "1Y", all = "All"
        var days: Int {
            switch self {
            case .month: return 30
            case .threeMonths: return 90
            case .sixMonths: return 180
            case .year: return 365
            case .all: return Int.max
            }
        }
    }
    
    enum MeasurementType: String, CaseIterable, Identifiable {
        case bodyFat = "Body Fat"
        case neck = "Neck", shoulders = "Shoulders", chest = "Chest"
        case waist = "Waist", abdomen = "Abdomen", hips = "Hips"
        case leftBicep = "Left Bicep", rightBicep = "Right Bicep"
        case leftForearm = "Left Forearm", rightForearm = "Right Forearm"
        case leftThigh = "Left Thigh", rightThigh = "Right Thigh"
        case leftCalf = "Left Calf", rightCalf = "Right Calf"
        
        var id: String { self.rawValue }
        var isPercentage: Bool { self == .bodyFat }
        
        func getValue(from m: BodyMeasurement) -> Double? {
            switch self {
            case .bodyFat: return m.bodyFat
            case .neck: return m.neck
            case .shoulders: return m.shoulders
            case .chest: return m.chest
            case .waist: return m.waist
            case .abdomen: return m.abdomen ?? m.pelvis // Legacy fallback
            case .hips: return m.hips
            case .leftBicep: return m.leftBicep ?? m.biceps
            case .rightBicep: return m.rightBicep ?? m.biceps
            case .leftForearm: return m.leftForearm
            case .rightForearm: return m.rightForearm
            case .leftThigh: return m.leftThigh ?? m.thigh
            case .rightThigh: return m.rightThigh ?? m.thigh
            case .leftCalf: return m.leftCalf ?? m.calves
            case .rightCalf: return m.rightCalf ?? m.calves
            }
        }
    }
    
    private var filteredMeasurements: [BodyMeasurement] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -selectedPeriod.days, to: Date())!
        return selectedPeriod == .all ? measurements : measurements.filter { $0.date >= cutoff }
    }
    
    private var chartData: [(date: Date, value: Double)] {
        let mapped = filteredMeasurements.compactMap { m -> (date: Date, value: Double)? in
            guard let val = selectedMetric.getValue(from: m) else { return nil }
            let finalVal = selectedMetric.isPercentage ? val : unitsManager.convertFromCentimeters(val)
            return (date: m.date, value: finalVal)
        }
        return mapped.reversed() // For chronological order
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Metric Selector
                    Menu {
                        ForEach(MeasurementType.allCases) { metric in
                            Button(LocalizedStringKey(metric.rawValue)) {
                                withAnimation { selectedMetric = metric }
                            }
                        }
                    } label: {
                        HStack {
                            Text(LocalizedStringKey(selectedMetric.rawValue))
                                .font(.headline)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Period Filter
                    Picker(LocalizedStringKey("Period"), selection: $selectedPeriod) {
                        ForEach(PeriodFilter.allCases, id: \.self) { p in
                            Text(LocalizedStringKey(p.rawValue)).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    if !chartData.isEmpty {
                        statsHeaderSection
                        chartSection
                    } else {
                        emptyStateSection
                    }
                    
                    if !measurements.isEmpty {
                        historyListSection
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(LocalizedStringKey("Body Measurements"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Close")) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAddMeasurement = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAddMeasurement) {
                AddMeasurementSheet(latestMeasurement: measurements.first)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var unitString: String {
        selectedMetric.isPercentage ? "%" : unitsManager.sizeUnitString()
    }
    
    private var statsHeaderSection: some View {
        let firstVal = chartData.first?.value ?? 0
        let currentVal = chartData.last?.value ?? 0
        let change = currentVal - firstVal
        
        return HStack(spacing: 16) {
            WeightStatCard(title: LocalizedStringKey("Start"), value: LocalizationHelper.shared.formatDecimal(firstVal), unit: unitString, color: .blue)
            WeightStatCard(title: LocalizedStringKey("Current"), value: LocalizationHelper.shared.formatDecimal(currentVal), unit: unitString, color: .green)
            WeightStatCard(title: LocalizedStringKey("Change"), value: (change >= 0 ? "+" : "") + LocalizationHelper.shared.formatDecimal(change), unit: unitString, color: change >= 0 ? (selectedMetric == .bodyFat || selectedMetric == .waist ? .red : .green) : (selectedMetric == .bodyFat || selectedMetric == .waist ? .green : .red))
        }
        .padding(.horizontal)
    }
    
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Chart {
                ForEach(Array(chartData.enumerated()), id: \.offset) { index, data in
                    if chartData.count > 1 {
                        LineMark(x: .value("Date", data.date), y: .value("Value", data.value))
                            .foregroundStyle(.purple)
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                        
                        AreaMark(x: .value("Date", data.date), y: .value("Value", data.value))
                            .foregroundStyle(LinearGradient(colors: [.purple.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.catmullRom)
                    }
                    
                    PointMark(x: .value("Date", data.date), y: .value("Value", data.value))
                        .foregroundStyle(.purple)
                        .symbolSize(chartData.count == 1 ? 50 : 30)
                        .annotation(position: .top) {
                            if chartData.count < 15 {
                                Text(LocalizationHelper.shared.formatDecimal(data.value))
                                    .font(.caption2).foregroundColor(.secondary)
                            }
                        }
                }
            }
            .frame(height: 220)
            .chartXAxis { AxisMarks(values: .automatic) { _ in AxisGridLine(); AxisTick(); AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true) } }
            .chartYScale(domain: .automatic(includesZero: false))
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            .padding(.horizontal)
        }
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "ruler.fill")
                .font(.system(size: 50))
                .foregroundColor(.purple.opacity(0.5))
            Text(LocalizedStringKey("No data for this period"))
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var historyListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey("History"))
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                ForEach(filteredMeasurements) { entry in
                    if selectedMetric.getValue(from: entry) != nil {
                        MeasurementEntryRow(entry: entry, selectedMetric: selectedMetric, unitsManager: unitsManager)
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task { await userStatsViewModel.deleteBodyMeasurement(entry.persistentModelID) }
                                } label: { Label(LocalizedStringKey("Delete"), systemImage: "trash") }
                            }
                        
                        if entry.id != filteredMeasurements.last?.id {
                            Divider().padding(.leading, 50)
                        }
                    }
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

// MARK: - Row Component
struct MeasurementEntryRow: View {
    let entry: BodyMeasurement
    let selectedMetric: BodyMeasurementsView.MeasurementType
    let unitsManager: UnitsManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.date, style: .date).font(.body)
                Text(entry.date, style: .time).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if let val = selectedMetric.getValue(from: entry) {
                let displayVal = selectedMetric.isPercentage ? val : unitsManager.convertFromCentimeters(val)
                let unit = selectedMetric.isPercentage ? "%" : unitsManager.sizeUnitString()
                Text("\(LocalizationHelper.shared.formatDecimal(displayVal)) \(unit)")
                    .font(.headline)
                    .foregroundColor(.purple)
            } else {
                Text("-").foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - Input Sheet
struct AddMeasurementSheet: View {
    @Environment(UserStatsViewModel.self) var userStatsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(UnitsManager.self) var unitsManager

    @State private var date = Date()
    
    // Use State for all fields
    @State private var bodyFat: Double? = nil
    @State private var neck: Double? = nil
    @State private var shoulders: Double? = nil
    @State private var chest: Double? = nil
    @State private var waist: Double? = nil
    @State private var abdomen: Double? = nil
    @State private var hips: Double? = nil
    @State private var leftBicep: Double? = nil
    @State private var rightBicep: Double? = nil
    @State private var leftForearm: Double? = nil
    @State private var rightForearm: Double? = nil
    @State private var leftThigh: Double? = nil
    @State private var rightThigh: Double? = nil
    @State private var leftCalf: Double? = nil
    @State private var rightCalf: Double? = nil
    
    let latestMeasurement: BodyMeasurement?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(LocalizedStringKey("Date"), selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section(header: Text(LocalizedStringKey("Body Composition"))) {
                    measurementField("Body Fat (%)", value: $bodyFat, isPercentage: true)
                }
                
                Section(header: Text("Upper Body (\(unitsManager.sizeUnitString()))")) {
                    measurementField("Neck", value: $neck)
                    measurementField("Shoulders", value: $shoulders)
                    measurementField("Chest", value: $chest)
                }
                
                Section(header: Text("Arms (\(unitsManager.sizeUnitString()))")) {
                    measurementField("Left Bicep", value: $leftBicep)
                    measurementField("Right Bicep", value: $rightBicep)
                    measurementField("Left Forearm", value: $leftForearm)
                    measurementField("Right Forearm", value: $rightForearm)
                }
                
                Section(header: Text("Core (\(unitsManager.sizeUnitString()))")) {
                    measurementField("Waist", value: $waist)
                    measurementField("Abdomen", value: $abdomen)
                    measurementField("Hips", value: $hips)
                }
                
                Section(header: Text("Legs (\(unitsManager.sizeUnitString()))")) {
                    measurementField("Left Thigh", value: $leftThigh)
                    measurementField("Right Thigh", value: $rightThigh)
                    measurementField("Left Calf", value: $leftCalf)
                    measurementField("Right Calf", value: $rightCalf)
                }
            }
            .navigationTitle(LocalizedStringKey("Log Measurements"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(LocalizedStringKey("Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(LocalizedStringKey("Save")) { save() }.bold() }
            }
            .onAppear(perform: prefillData)
        }
    }
    
    private func measurementField(_ title: String, value: Binding<Double?>, isPercentage: Bool = false) -> some View {
        HStack {
            Text(LocalizedStringKey(title))
            Spacer()
            // We use standard TextField with format for ease, but we need our custom conversion logic
            let proxyBinding = Binding<Double?>(
                get: {
                    guard let v = value.wrappedValue else { return nil }
                    return isPercentage ? v : unitsManager.convertFromCentimeters(v)
                },
                set: { newVal in
                    guard let v = newVal else { value.wrappedValue = nil; return }
                    value.wrappedValue = isPercentage ? v : unitsManager.convertToCentimeters(v)
                }
            )
            
            ClearableTextField(placeholder: "-", value: proxyBinding)
                .frame(width: 80)
        }
    }
    
    private func prefillData() {
        guard let latest = latestMeasurement else { return }
        bodyFat = latest.bodyFat
        neck = latest.neck
        shoulders = latest.shoulders
        chest = latest.chest
        waist = latest.waist
        abdomen = latest.abdomen ?? latest.pelvis
        hips = latest.hips
        leftBicep = latest.leftBicep ?? latest.biceps
        rightBicep = latest.rightBicep ?? latest.biceps
        leftForearm = latest.leftForearm
        rightForearm = latest.rightForearm
        leftThigh = latest.leftThigh ?? latest.thigh
        rightThigh = latest.rightThigh ?? latest.thigh
        leftCalf = latest.leftCalf ?? latest.calves
        rightCalf = latest.rightCalf ?? latest.calves
    }
    
    private func save() {
        let newMeasurement = BodyMeasurement(
            date: date, bodyFat: bodyFat,
            neck: neck, shoulders: shoulders, chest: chest,
            waist: waist, abdomen: abdomen, hips: hips,
            leftBicep: leftBicep, rightBicep: rightBicep,
            leftForearm: leftForearm, rightForearm: rightForearm,
            leftThigh: leftThigh, rightThigh: rightThigh,
            leftCalf: leftCalf, rightCalf: rightCalf
        )
        
        Task {
            await userStatsViewModel.saveBodyMeasurement(newMeasurement)
            dismiss()
        }
    }
}
