//
//  ReportView.swift
//  GlucoseTracker
//
//  Created by taeni on 9/9/25.
//

import SwiftUI
import Charts
import HealthKit

struct ReportView: View {
    @State private var bloodGlucoseData: [BloodGlucoseReading] = []
    @State private var isLoading = false
    @State private var selectedTimeRange: TimeRange = .sevenDays
    @StateObject private var authManager = HealthKitAuthorizationManager()
    
    private let healthKitManager: HealthKitManagerProtocol
    
    init(healthKitManager: HealthKitManagerProtocol = HealthKitManager.shared) {
        self.healthKitManager = healthKitManager
    }
    
    var body: some View {
        NavigationView {
            HealthKitAuthorizationView {
                AnyView(mainContent)
            }
        }
        .environmentObject(authManager)
        .onAppear {
            authManager.checkAuthorizationStatus()
            if authManager.isAuthorized {
                Task { await loadReportData() }
            }
        }
        .refreshable {
            if authManager.isAuthorized {
                await loadReportData()
            }
        }
    }
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                timeRangeSelector
                
                if isLoading {
                    LoadingView()
                } else {
                    analyticsContent
                }
            }
            .padding()
        }
        .navigationTitle("Report")
        .navigationBarTitleDisplayMode(.large)
    }
    
    private var timeRangeSelector: some View {
        Picker("Time Range", selection: $selectedTimeRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.displayName)
                    .tag(range)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedTimeRange) { _, _ in
            Task { await loadReportData() }
        }
    }
    
    private var analyticsContent: some View {
        VStack(spacing: 24) {
            ReportSection(
                title: MealTimeType.fasting.displayName + " Glucose",
                color: .blue,
                mealType: .fasting,
                bloodGlucoseData: bloodGlucoseData,
                timeRange: selectedTimeRange
            )
            
            ReportSection(
                title: MealTimeType.postMeal.displayName + " Glucose",
                color: .orange,
                mealType: .postMeal,
                bloodGlucoseData: bloodGlucoseData,
                timeRange: selectedTimeRange
            )
        }
    }
    
    private func loadReportData() async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let startDate = selectedTimeRange.startDate
            let samples = try await healthKitManager.readBloodGlucoseSamples(since: startDate)
            let readings = BloodGlucoseDataProcessor.processBloodGlucoseSamples(samples)
            
            await MainActor.run {
                bloodGlucoseData = readings
                isLoading = false
            }
            
        } catch {
            await MainActor.run {
                bloodGlucoseData = []
                isLoading = false
            }
        }
    }
}

struct ReportSection: View {
    let title: String
    let color: Color
    let mealType: MealTimeType
    let bloodGlucoseData: [BloodGlucoseReading]
    let timeRange: TimeRange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)

            let weeklyAverage = getWeeklyAverage(for: mealType)
            let percentageChange = getPercentageChange(for: mealType)

            HStack {
                Text("\(timeRange.displayName) Avg: \(weeklyAverage.value)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Spacer()
                Text(percentageChange.text)
                    .font(.subheadline)
                    .foregroundColor(percentageChange.color)
            }

            chartSection
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var chartSection: some View {
        Group {
            if let chartData = getChartData(for: mealType) {
                Chart(chartData) { entry in
                    BarMark(
                        x: .value("Date", entry.date, unit: .day),
                        y: .value("Glucose Level", entry.glucoseLevel)
                    )
                    .foregroundStyle(color)
                }
                .frame(height: 200)
                .chartYScale(domain: 50...200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: max(1, chartData.count / 5))) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
            } else {
                Text("No data available for the selected time range")
                    .foregroundColor(.gray)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func getWeeklyAverage(for mealType: MealTimeType) -> (value: String, rawValue: Double) {
        let startDate = timeRange.startDate
        let recentRecords = bloodGlucoseData
            .filter { $0.date >= startDate && $0.date <= Date() }
            .filter { MealTimeType.from(reading: $0) == mealType }
            .map { $0.value }

        if recentRecords.isEmpty {
            return ("No data", 0)
        } else {
            let avg = recentRecords.reduce(0, +) / Double(recentRecords.count)
            return ("\(Int(avg)) mg/dL", avg)
        }
    }

    private func getPercentageChange(for mealType: MealTimeType) -> (text: String, color: Color) {
        let currentAverage = getWeeklyAverage(for: mealType).rawValue
        let previousAverage = getPreviousAverage(for: mealType)

        guard previousAverage > 0 else { return ("No comparison", .gray) }

        let change = ((currentAverage - previousAverage) / previousAverage) * 100
        let roundedChange = round(change * 10) / 10

        if change > 0 {
            return ("↑ \(roundedChange)%", .red)
        } else if change < 0 {
            return ("↓ \(-roundedChange)%", .green)
        } else {
            return ("No change", .gray)
        }
    }

    private func getPreviousAverage(for mealType: MealTimeType) -> Double {
        let calendar = Calendar.current
        let currentPeriodDays = timeRange.days
        let startDate = calendar.date(byAdding: .day, value: -(currentPeriodDays * 2), to: Date()) ?? Date()
        let endDate = calendar.date(byAdding: .day, value: -currentPeriodDays, to: Date()) ?? Date()
        
        let previousRecords = bloodGlucoseData
            .filter { $0.date >= startDate && $0.date < endDate }
            .filter { MealTimeType.from(reading: $0) == mealType }
            .map { $0.value }

        if previousRecords.isEmpty {
            return 0
        } else {
            return previousRecords.reduce(0, +) / Double(previousRecords.count)
        }
    }

    private func getChartData(for mealType: MealTimeType) -> [GlucoseEntry]? {
        let startDate = timeRange.startDate
        let filteredReadings = bloodGlucoseData
            .filter { $0.date >= startDate }
            .filter { MealTimeType.from(reading: $0) == mealType }
        
        guard !filteredReadings.isEmpty else { return nil }
        
        // Group by day and calculate daily averages
        let calendar = Calendar.current
        let groupedByDay = Dictionary(grouping: filteredReadings) { reading in
            calendar.startOfDay(for: reading.date)
        }
        
        let chartData = groupedByDay.map { (date, readings) in
            let average = readings.map { $0.value }.reduce(0, +) / Double(readings.count)
            return GlucoseEntry(date: date, glucoseLevel: Int(average))
        }.sorted { $0.date < $1.date }
        
        return chartData.isEmpty ? nil : chartData
    }
}

struct GlucoseEntry: Identifiable {
    let id = UUID()
    let date: Date
    let glucoseLevel: Int
}

enum TimeRange: String, CaseIterable {
    case sevenDays = "7d"
    case thirtyDays = "30d"
    case ninetyDays = "90d"
    
    var displayName: String {
        switch self {
        case .sevenDays:
            return "7 Days"
        case .thirtyDays:
            return "30 Days"
        case .ninetyDays:
            return "90 Days"
        }
    }
    
    var days: Int {
        switch self {
        case .sevenDays:
            return 7
        case .thirtyDays:
            return 30
        case .ninetyDays:
            return 90
        }
    }
    
    var startDate: Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }
}

#Preview {
    ReportView()
}

// MARK: - View Extensions
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
