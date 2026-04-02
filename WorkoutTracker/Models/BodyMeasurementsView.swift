//
//  BodyMeasurementsView.swift
//  WorkoutTracker
//

internal import SwiftUI
import SwiftData
import Charts

struct BodyMeasurementsView: View {
    @Environment(UserStatsViewModel.self) var userStatsViewModel
    @Environment(\.modelContext) private var context
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]
    @Environment(UnitsManager.self) var unitsManager
    @Environment(\.dismiss) var dismiss

    @State private var selectedMetric: MeasurementType = .chest
    @State private var showingAddMeasurement = false
    
    enum MeasurementType: String, CaseIterable, Identifiable {
        case neck = "Neck"
        case shoulders = "Shoulders"
        case chest = "Chest"
        case waist = "Waist"
        case pelvis = "Pelvis"
        case biceps = "Biceps"
        case thigh = "Thigh"
        case calves = "Calves"
        
        var id: String { self.rawValue }
        
        func getValue(from measurement: BodyMeasurement) -> Double? {
            switch self {
            case .neck: return measurement.neck
            case .shoulders: return measurement.shoulders
            case .chest: return measurement.chest
            case .waist: return measurement.waist
            case .pelvis: return measurement.pelvis
            case .biceps: return measurement.biceps
            case .thigh: return measurement.thigh
            case .calves: return measurement.calves
            }
        }
    }
    
    // ИСПРАВЛЕНИЕ: Явное указание типа возвращаемого значения для замыкания
    var chartData: [(date: Date, value: Double)] {
        let mapped = measurements.compactMap { m -> (date: Date, value: Double)? in
            guard let val = selectedMetric.getValue(from: m) else { return nil }
            return (date: m.date, value: unitsManager.convertFromCentimeters(val))
        }
        return mapped.reversed() // Для правильного хронологического порядка
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Picker(LocalizedStringKey("Metric"), selection: $selectedMetric) {
                        ForEach(MeasurementType.allCases) { metric in
                            Text(LocalizedStringKey(metric.rawValue)).tag(metric)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    if !chartData.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(LocalizedStringKey("\(selectedMetric.rawValue) Progress"))
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Chart {
                                ForEach(Array(chartData.enumerated()), id: \.offset) { index, data in
                                    if chartData.count > 1 {
                                        LineMark(
                                            x: .value("Date", data.date),
                                            y: .value("Value", data.value)
                                        )
                                        .foregroundStyle(.purple)
                                        .interpolationMethod(.linear)
                                        .lineStyle(StrokeStyle(lineWidth: 3))
                                    }
                                    
                                    PointMark(
                                        x: .value("Date", data.date),
                                        y: .value("Value", data.value)
                                    )
                                    .foregroundStyle(.purple)
                                    .symbolSize(chartData.count == 1 ? 50 : 30)
                                    .annotation(position: .top) {
                                        Text(LocalizationHelper.shared.formatDecimal(data.value))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
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
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "ruler")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text(LocalizedStringKey("No data yet"))
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                    
                    if !measurements.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(LocalizedStringKey("History"))
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(spacing: 0) {
                                ForEach(measurements) { entry in
                                    MeasurementEntryRow(entry: entry, selectedMetric: selectedMetric, unitsManager: unitsManager)
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                userStatsViewModel.deleteBodyMeasurement(entry)
                                            } label: {
                                                Label(LocalizedStringKey("Delete"), systemImage: "trash")
                                            }
                                        }
                                    
                                    if entry.id != measurements.last?.id {
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
            .navigationTitle(LocalizedStringKey("Body Measurements"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Close")) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddMeasurement = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddMeasurement) {
                AddMeasurementSheet(latestMeasurement: measurements.first)
            }
        }
    }
}

struct MeasurementEntryRow: View {
    let entry: BodyMeasurement
    let selectedMetric: BodyMeasurementsView.MeasurementType
    let unitsManager: UnitsManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.date, style: .date)
                    .font(.body)
                Text(entry.date, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let val = selectedMetric.getValue(from: entry) {
                Text("\(LocalizationHelper.shared.formatDecimal(unitsManager.convertFromCentimeters(val))) \(unitsManager.sizeUnitString())")
                    .font(.headline)
                    .foregroundColor(.purple)
            } else {
                Text("-")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct AddMeasurementSheet: View {
    @Environment(UserStatsViewModel.self) var userStatsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(UnitsManager.self) var unitsManager

    @State private var date = Date()
    
    @State private var neckStr = ""
    @State private var shouldersStr = ""
    @State private var chestStr = ""
    @State private var waistStr = ""
    @State private var pelvisStr = ""
    @State private var bicepsStr = ""
    @State private var thighStr = ""
    @State private var calvesStr = ""
    
    let latestMeasurement: BodyMeasurement?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(LocalizedStringKey("Date"), selection: $date, displayedComponents: .date)
                }
                
                // ИСПРАВЛЕНИЕ: Обычная интерполяция без LocalizedStringKey для стабильности компилятора
                Section(header: Text("Measurements (\(unitsManager.sizeUnitString()))")) {
                    measurementField("Neck", text: $neckStr)
                    measurementField("Shoulders", text: $shouldersStr)
                    measurementField("Chest", text: $chestStr)
                    measurementField("Waist", text: $waistStr)
                    measurementField("Pelvis", text: $pelvisStr)
                    measurementField("Biceps", text: $bicepsStr)
                    measurementField("Thigh", text: $thighStr)
                    measurementField("Calves", text: $calvesStr)
                }
            }
            .navigationTitle(LocalizedStringKey("Add Measurement"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Save")) { save() }
                }
            }
            .onAppear {
                if let latest = latestMeasurement {
                    neckStr = format(latest.neck)
                    shouldersStr = format(latest.shoulders)
                    chestStr = format(latest.chest)
                    waistStr = format(latest.waist)
                    pelvisStr = format(latest.pelvis)
                    bicepsStr = format(latest.biceps)
                    thighStr = format(latest.thigh)
                    calvesStr = format(latest.calves)
                }
            }
        }
    }
    
    private func measurementField(_ title: String, text: Binding<String>) -> some View {
        HStack {
            Text(LocalizedStringKey(title))
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 100)
        }
    }
    
    private func format(_ val: Double?) -> String {
        guard let val = val else { return "" }
        let converted = unitsManager.convertFromCentimeters(val)
        return LocalizationHelper.shared.formatDecimal(converted).replacingOccurrences(of: ",", with: ".")
    }
    
    private func parse(_ str: String) -> Double? {
        guard let val = Double(str.replacingOccurrences(of: ",", with: ".")) else { return nil }
        return unitsManager.convertToCentimeters(val)
    }
    
    private func save() {
        userStatsViewModel.addBodyMeasurement(
            neck: parse(neckStr),
            shoulders: parse(shouldersStr),
            chest: parse(chestStr),
            waist: parse(waistStr),
            pelvis: parse(pelvisStr),
            biceps: parse(bicepsStr),
            thigh: parse(thighStr),
            calves: parse(calvesStr),
            date: date
        )
        dismiss()
    }
}
