

internal import SwiftUI
import SwiftData
import Charts

struct BodyMeasurementsView: View {
    @Environment(UserStatsViewModel.self) var userStatsViewModel
    @Environment(\.modelContext) private var context
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]
    @Environment(UnitsManager.self) var unitsManager
    @Environment(\.dismiss) var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme 

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

        var icon: String {
            switch self {
            case .bodyFat: return "percent"
            case .neck: return "person.crop.circle"
            case .shoulders: return "figure.arms.open"
            case .chest: return "shield.fill"
            case .waist, .abdomen, .hips: return "ruler.fill"
            case .leftBicep, .rightBicep, .leftForearm, .rightForearm: return "hand.raised.fill"
            case .leftThigh, .rightThigh, .leftCalf, .rightCalf: return "figure.walk"
            }
        }

        func getValue(from m: BodyMeasurement) -> Double? {
            switch self {
            case .bodyFat: return m.bodyFat
            case .neck: return m.neck
            case .shoulders: return m.shoulders
            case .chest: return m.chest
            case .waist: return m.waist
            case .abdomen: return m.abdomen ?? m.pelvis 
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
        return mapped.reversed() 
    }

    var body: some View {
        NavigationStack {
            ZStack {

                (colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color(UIColor.secondarySystemBackground))
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        Menu {
                            ForEach(MeasurementType.allCases) { metric in
                                Button {
                                    withAnimation { selectedMetric = metric }
                                } label: {
                                    Label(LocalizedStringKey(metric.rawValue), systemImage: metric.icon)
                                }
                            }
                        } label: {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(themeManager.current.deepPremiumAccent.opacity(0.15))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: selectedMetric.icon)
                                        .foregroundColor(themeManager.current.deepPremiumAccent)
                                        .font(.subheadline.bold())
                                }

                                Text(LocalizedStringKey(selectedMetric.rawValue))
                                    .font(.headline)
                                    .foregroundColor(colorScheme == .dark ? .white : .black)

                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .foregroundColor(.gray)
                                    .font(.subheadline)
                            }
                            .padding(12)
                            .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05), lineWidth: 1))
                            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 5, y: 2)
                        }
                        .padding(.horizontal, 20)

                        Picker(LocalizedStringKey("Period"), selection: $selectedPeriod) {
                            ForEach(PeriodFilter.allCases, id: \.self) { p in
                                Text(LocalizedStringKey(p.rawValue)).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 20)

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

    private var unitString: String {
        selectedMetric.isPercentage ? "%" : unitsManager.sizeUnitString()
    }

    private var statsHeaderSection: some View {
        let firstVal = chartData.first?.value ?? 0
        let currentVal = chartData.last?.value ?? 0
        let change = currentVal - firstVal

        return HStack(spacing: 16) {
            WeightStatCard(title: LocalizedStringKey("Start"), value: LocalizationHelper.shared.formatDecimal(firstVal), unit: unitString, color: themeManager.current.deepPremiumAccent)
            WeightStatCard(title: LocalizedStringKey("Current"), value: LocalizationHelper.shared.formatDecimal(currentVal), unit: unitString, color: .green)
            WeightStatCard(
                title: LocalizedStringKey("Change"),
                value: (change >= 0 ? "+" : "") + LocalizationHelper.shared.formatDecimal(change),
                unit: unitString,
                color: change >= 0 ? .green : .red
            )
        }
        .padding(.horizontal, 20)
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Chart {
                ForEach(Array(chartData.enumerated()), id: \.offset) { index, data in
                    if chartData.count > 1 {
                        LineMark(x: .value("Date", data.date), y: .value("Value", data.value))
                            .foregroundStyle(themeManager.current.deepPremiumAccent)
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 3))

                        AreaMark(x: .value("Date", data.date), y: .value("Value", data.value))
                            .foregroundStyle(LinearGradient(colors: [themeManager.current.deepPremiumAccent.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.catmullRom)
                    }

                    PointMark(x: .value("Date", data.date), y: .value("Value", data.value))
                        .foregroundStyle(themeManager.current.deepPremiumAccent)
                        .symbolSize(chartData.count == 1 ? 50 : 30)
                        .annotation(position: .top) {
                            if chartData.count < 15 {
                                Text(LocalizationHelper.shared.formatDecimal(data.value))
                                    .font(.caption2).foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                            }
                        }
                }
            }
            .frame(height: 220)
            .chartXAxis { AxisMarks(values: .automatic) { _ in AxisGridLine(); AxisTick(); AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true) } }
            .chartYScale(domain: .automatic(includesZero: false))
            .padding()

            .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05), lineWidth: 1))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 5, y: 2)
            .padding(.horizontal, 20)
        }
    }

    private var emptyStateSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(themeManager.current.deepPremiumAccent.opacity(0.1)).frame(width: 80, height: 80)
                Image(systemName: selectedMetric.icon)
                    .font(.system(size: 30))
                    .foregroundColor(themeManager.current.deepPremiumAccent)
            }
            Text(LocalizedStringKey("No data for this period"))
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .black)
            Text(LocalizedStringKey("Tap + to add your first measurement."))
                .font(.subheadline)
                .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var historyListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey("History"))
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .padding(.horizontal, 20)

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
                            Divider().padding(.leading, 20)
                        }
                    }
                }
            }

            .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05), lineWidth: 1))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 5, y: 2)
            .padding(.horizontal, 20)
        }
    }
}

struct MeasurementEntryRow: View {
    let entry: BodyMeasurement
    let selectedMetric: BodyMeasurementsView.MeasurementType
    let unitsManager: UnitsManager
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.date, style: .date).font(.body).bold().foregroundColor(colorScheme == .dark ? .white : .black)
                Text(entry.date, style: .time).font(.caption).foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
            }
            Spacer()
            if let val = selectedMetric.getValue(from: entry) {
                let displayVal = selectedMetric.isPercentage ? val : unitsManager.convertFromCentimeters(val)
                let unit = selectedMetric.isPercentage ? "%" : unitsManager.sizeUnitString()
                Text("\(LocalizationHelper.shared.formatDecimal(displayVal)) \(unit)")
                    .font(.headline)
                    .foregroundColor(themeManager.current.deepPremiumAccent)
            } else {
                Text("-").foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
            }
        }
        .padding(16)
    }
}

struct AddMeasurementSheet: View {
    @Environment(UserStatsViewModel.self) var userStatsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(UnitsManager.self) var unitsManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var date = Date()

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

                Section(header: Text("\(String(localized: "Upper Body")) (\(unitsManager.sizeUnitString()))")) {
                    measurementField("Neck", value: $neck)
                    measurementField("Shoulders", value: $shoulders)
                    measurementField("Chest", value: $chest)
                }

                Section(header: Text("\(String(localized: "Arms")) (\(unitsManager.sizeUnitString()))")) {
                    measurementField("Left Bicep", value: $leftBicep)
                    measurementField("Right Bicep", value: $rightBicep)
                    measurementField("Left Forearm", value: $leftForearm)
                    measurementField("Right Forearm", value: $rightForearm)
                }

                Section(header: Text("\(String(localized: "Core")) (\(unitsManager.sizeUnitString()))")) {
                    measurementField("Waist", value: $waist)
                    measurementField("Abdomen", value: $abdomen)
                    measurementField("Hips", value: $hips)
                }

                Section(header: Text("\(String(localized: "Legs")) (\(unitsManager.sizeUnitString()))")) {
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
