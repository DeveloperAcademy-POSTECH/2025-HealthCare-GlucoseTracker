//
//  ReportView 2.swift
//  GlucoseTracker
//
//  Created by taeni on 9/9/25.
//


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
    
    private var chartData: [ChartDataPoint] {
        BloodGlucoseAnalytics.generateChartData(
            from: bloodGlucoseData,
            timeRange: selectedTimeRange
        )
    }
    
    private var fastingAnalytics: GlucoseAnalytics {
        BloodGlucoseAnalytics.calculateFastingAnalytics(from: bloodGlucoseData)
    }
    
    private var postMealAnalytics: GlucoseAnalytics {
        BloodGlucoseAnalytics.calculatePostMealAnalytics(from: bloodGlucoseData)
    }
    
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
            AnalyticsCard(
                title: "Fasting Glucose",
                analytics: fastingAnalytics,
                chartData: chartData.filter { $0.type == .fasting },
                color: .blue,
                timeRange: selectedTimeRange
            )
            
            AnalyticsCard(
                title: "Post-meal Glucose",
                analytics: postMealAnalytics,
                chartData: chartData.filter { $0.type == .postMeal },
                color: .orange,
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

struct AnalyticsCard: View {
    let title: String
    let analytics: GlucoseAnalytics
    let chartData: [ChartDataPoint]
    let color: Color
    let timeRange: TimeRange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection
            chartSection
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
            
            HStack {
                Text("\(timeRange.displayName) Avg: \(analytics.formattedAverage) mg/dL")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if analytics.percentageChange != 0 {
                    PercentageChangeView(percentage: analytics.percentageChange)
                }
            }
        }
    }
    
    private var chartSection: some View {
        Group {
            if chartData.isEmpty {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(chartData, id: \.date) { dataPoint in
                    BarMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Glucose", dataPoint.value)
                    )
                    .foregroundStyle(color)
                }
                .frame(height: 120)
                .chartYScale(domain: 50...200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
            }
        }
    }
}

struct PercentageChangeView: View {
    let percentage: Double
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: percentage >= 0 ? "arrow.up" : "arrow.down")
                .font(.caption)
            
            Text("\(abs(percentage), specifier: "%.1f")%")
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(percentage >= 0 ? .green : .red)
    }
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
    
    var startDate: Date {
        let calendar = Calendar.current
        switch self {
        case .sevenDays:
            return calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        case .thirtyDays:
            return calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        case .ninetyDays:
            return calendar.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        }
    }
}

struct ChartDataPoint {
    let date: Date
    let value: Double
    let type: GlucoseType
}

enum GlucoseType {
    case fasting
    case postMeal
}

struct GlucoseAnalytics {
    let average: Double
    let percentageChange: Double
    
    var formattedAverage: String {
        String(format: "%.1f", average)
    }
}

struct BloodGlucoseAnalytics {
    static func generateChartData(
        from readings: [BloodGlucoseReading],
        timeRange: TimeRange
    ) -> [ChartDataPoint] {
        let calendar = Calendar.current
        let startDate = timeRange.startDate
        let endDate = Date()
        
        var chartData: [ChartDataPoint] = []
        var currentDate = startDate
        
        while currentDate <= endDate {
            let dayReadings = readings.filter { reading in
                calendar.isDate(reading.date, inSameDayAs: currentDate)
            }
            
            let fastingReadings = dayReadings.filter { isFastingReading($0) }
            let postMealReadings = dayReadings.filter { !isFastingReading($0) }
            
            if !fastingReadings.isEmpty {
                let average = fastingReadings.map { $0.value }.reduce(0, +) / Double(fastingReadings.count)
                chartData.append(ChartDataPoint(date: currentDate, value: average, type: .fasting))
            }
            
            if !postMealReadings.isEmpty {
                let average = postMealReadings.map { $0.value }.reduce(0, +) / Double(postMealReadings.count)
                chartData.append(ChartDataPoint(date: currentDate, value: average, type: .postMeal))
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return chartData
    }
    
    static func calculateFastingAnalytics(from readings: [BloodGlucoseReading]) -> GlucoseAnalytics {
        let fastingReadings = readings.filter { isFastingReading($0) }
        
        guard !fastingReadings.isEmpty else {
            return GlucoseAnalytics(average: 0, percentageChange: 0)
        }
        
        let average = fastingReadings.map { $0.value }.reduce(0, +) / Double(fastingReadings.count)
        let percentageChange = calculatePercentageChange(for: fastingReadings)
        
        return GlucoseAnalytics(average: average, percentageChange: percentageChange)
    }
    
    static func calculatePostMealAnalytics(from readings: [BloodGlucoseReading]) -> GlucoseAnalytics {
        let postMealReadings = readings.filter { !isFastingReading($0) }
        
        guard !postMealReadings.isEmpty else {
            return GlucoseAnalytics(average: 0, percentageChange: 0)
        }
        
        let average = postMealReadings.map { $0.value }.reduce(0, +) / Double(postMealReadings.count)
        let percentageChange = calculatePercentageChange(for: postMealReadings)
        
        return GlucoseAnalytics(average: average, percentageChange: percentageChange)
    }
    
    private static func isFastingReading(_ reading: BloodGlucoseReading) -> Bool {
        let hour = Calendar.current.component(.hour, from: reading.date)
        return hour >= 6 && hour <= 9
    }
    
    private static func calculatePercentageChange(for readings: [BloodGlucoseReading]) -> Double {
        guard readings.count >= 2 else { return 0 }
        
        let sortedReadings = readings.sorted { $0.date < $1.date }
        let firstHalf = Array(sortedReadings.prefix(sortedReadings.count / 2))
        let secondHalf = Array(sortedReadings.suffix(sortedReadings.count / 2))
        
        guard !firstHalf.isEmpty && !secondHalf.isEmpty else { return 0 }
        
        let firstAverage = firstHalf.map { $0.value }.reduce(0, +) / Double(firstHalf.count)
        let secondAverage = secondHalf.map { $0.value }.reduce(0, +) / Double(secondHalf.count)
        
        guard firstAverage > 0 else { return 0 }
        
        return ((secondAverage - firstAverage) / firstAverage) * 100
    }
}

#Preview {
    ReportView()
}
