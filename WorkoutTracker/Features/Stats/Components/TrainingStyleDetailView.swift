//
//  TrainingStyleDetailView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 8.04.26.
//

internal import SwiftUI
import SwiftData
import Charts

struct TrainingStyleDetailView: View {
    @Environment(DIContainer.self) private var di
    @Query(filter: #Predicate<Workout> { $0.endTime != nil }, sort: \.date, order: .reverse)
    private var allWorkouts: [Workout]
    
    enum TrendPeriod: String, CaseIterable, Identifiable, Sendable {
        case week = "Week", month = "Month", year = "Year", allTime = "All Time"
        var id: String { self.rawValue }
        var localizedName: LocalizedStringKey { LocalizedStringKey(self.rawValue) }
    }
    
    @State private var selectedPeriod: TrendPeriod = .month
    @State private var stats: TrainingStyleDTO? = nil
    
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme // 👈 АДАПТАЦИЯ ТЕМЫ

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                Picker(LocalizedStringKey("Period"), selection: $selectedPeriod) {
                    ForEach(TrendPeriod.allCases) { period in
                        Text(period.localizedName).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 10)
                
                if let stats = stats, stats.totalMechanicSets > 0 {
                    mechanicDonutChart(stats: stats)
                    equipmentArsenal(stats: stats)
                    aiInsightCard(stats: stats)
                } else {
                    EmptyStateView(
                        icon: "chart.pie.fill",
                        title: "No Data",
                        message: "Complete workouts during this period to see your training style breakdown."
                    )
                    .frame(height: 300)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(LocalizedStringKey("Training Style"))
        .navigationBarTitleDisplayMode(.inline)
        // 👈 Адаптивный фон экрана
        .background(colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground))
        .task(id: selectedPeriod) {
            await loadData()
        }
    }
    
    @ViewBuilder
    private func mechanicDonutChart(stats: TrainingStyleDTO) -> some View {
        let total = stats.totalMechanicSets
        let compPct = total > 0 ? Int((Double(stats.compoundSets) / Double(total)) * 100) : 0
        let isoPct = total > 0 ? Int((Double(stats.isolationSets) / Double(total)) * 100) : 0
        
        let isCompoundDominant = compPct >= isoPct
        let dominantPct = isCompoundDominant ? compPct : isoPct
        let dominantName: LocalizedStringKey = isCompoundDominant ? "Compound" : "Isolation"
        
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedStringKey("Mechanic Breakdown"))
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
            
            Chart {
                SectorMark(angle: .value("Sets", stats.compoundSets), innerRadius: .ratio(0.65), angularInset: 2)
                    .cornerRadius(6)
                    .foregroundStyle(LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom))
                
                SectorMark(angle: .value("Sets", stats.isolationSets), innerRadius: .ratio(0.65), angularInset: 2)
                    .cornerRadius(6)
                    .foregroundStyle(LinearGradient(colors: [.purple, .indigo], startPoint: .top, endPoint: .bottom))
            }
            .frame(height: 240)
            .chartBackground { proxy in
                VStack {
                    Text(LocalizedStringKey("Focus"))
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                    Text("\(dominantPct)% ")
                        .font(.headline).bold()
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    + Text(dominantName)
                        .font(.headline).bold()
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }
            }
            
            HStack(spacing: 16) {
                legendItem(title: "Compound", color: .orange, value: stats.compoundSets)
                legendItem(title: "Isolation", color: .purple, value: stats.isolationSets)
            }
        }
        .padding(20)
        // 👈 Адаптивный фон карточки
        .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.clear, lineWidth: 1))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 8, y: 4)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func equipmentArsenal(stats: TrainingStyleDTO) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedStringKey("Equipment Arsenal"))
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
            
            let totalEq = stats.totalEquipmentSets
            ForEach(EquipmentCategory.allCases) { category in
                let count = stats.equipmentDistribution[category] ?? 0
                if count > 0 || category != .other {
                    let pct = totalEq > 0 ? Double(count) / Double(totalEq) : 0.0
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(category.color.opacity(0.15)).frame(width: 36, height: 36)
                            Image(systemName: category.icon).font(.caption.bold()).foregroundColor(category.color)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(LocalizedStringKey(category.rawValue))
                                    .font(.subheadline).bold()
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                Spacer()
                                Text("\(count) sets (\(Int(pct * 100))%)")
                                    .font(.caption).foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.gray.opacity(0.15))
                                    Capsule().fill(LinearGradient(colors: [category.color.opacity(0.6), category.color], startPoint: .leading, endPoint: .trailing))
                                        .frame(width: geo.size.width * CGFloat(pct))
                                }
                            }.frame(height: 8)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.clear, lineWidth: 1))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 8, y: 4)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func aiInsightCard(stats: TrainingStyleDTO) -> some View {
        let insight = generateInsight(stats: stats)
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(insight.color.opacity(0.2)).frame(width: 50, height: 50)
                Image(systemName: insight.icon).font(.title2).foregroundColor(insight.color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey("ИИ инсайт: \(insight.title)"))
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                Text(LocalizedStringKey(insight.message))
                    .font(.subheadline)
                    .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(20)
        .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(insight.color.opacity(0.3), lineWidth: 1))
        .shadow(color: insight.color.opacity(0.1), radius: 10, y: 4)
        .padding(.horizontal)
    }
    
    private func legendItem(title: String, color: Color, value: Int) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(LocalizedStringKey(title))
                .font(.subheadline)
                .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                .lineLimit(1).minimumScaleFactor(0.5)
            Spacer(minLength: 2)
            Text("\(value)")
                .font(.headline).bold()
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .lineLimit(1)
        }
        .padding(12)
        .background(colorScheme == .dark ? Color(UIColor.tertiarySystemFill).opacity(0.5) : Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // Logic (Оставляем как было)
    private func loadData() async {
        let calendar = Calendar.current; let now = Date(); let interval: DateInterval?
        switch selectedPeriod {
        case .week: interval = calendar.dateInterval(of: .weekOfYear, for: now)
        case .month: interval = calendar.dateInterval(of: .month, for: now)
        case .year: interval = calendar.dateInterval(of: .year, for: now)
        case .allTime: interval = nil
        }
        let newStats = await di.analyticsService.fetchTrainingStyleStats(for: interval, workouts: allWorkouts)
        await MainActor.run { withAnimation(.spring()) { self.stats = newStats } }
    }
    
    private func generateInsight(stats: TrainingStyleDTO) -> (title: String, message: String, icon: String, color: Color) {
        let fwPct = Double(stats.equipmentDistribution[.freeWeights] ?? 0) / Double(max(stats.totalEquipmentSets, 1))
        let machPct = Double(stats.equipmentDistribution[.machines] ?? 0) / Double(max(stats.totalEquipmentSets, 1))
        let bwPct = Double(stats.equipmentDistribution[.bodyweight] ?? 0) / Double(max(stats.totalEquipmentSets, 1))
        let compPct = Double(stats.compoundSets) / Double(max(stats.totalMechanicSets, 1))
        
        if compPct > 0.6 && fwPct > 0.5 { return ("Free Weight Warrior", "You focus on heavy compound lifts. Great for strength!", "flame.fill", .orange) }
        else if machPct > 0.5 { return ("Machine Master", "You often use machines. This is a safe approach for hypertrophy.", "gearshape.2.fill", .purple) }
        else if bwPct > 0.5 { return ("Calisthenics Ninja", "Bodyweight work builds incredible body control.", "figure.core.training", .cyan) }
        else if stats.isolationSets > stats.compoundSets { return ("Sculptor", "You emphasize isolation. Perfect for muscle detail.", "paintpalette.fill", .pink) }
        else { return ("Balanced Athlete", "Your workouts are well-balanced across mechanics.", "scale.3d", .green) }
    }
}
