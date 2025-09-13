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
                if isLoading {
                    LoadingView()
                } else {
                    reportContent
                }
            }
            .padding()
        }
        .navigationTitle("Report")
        .navigationBarTitleDisplayMode(.large)
    }
    
    private var reportContent: some View {
        let analytics = WeeklyGlucoseAnalyzer.analyze(bloodGlucoseData)
        
        return VStack(spacing: 24) {
            WeekRangeHeader(dateRange: analytics.dateRange)
            
            GlucoseReportCard(
                title: "Fasting Glucose",
                metrics: analytics.fasting,
                chartData: analytics.fastingChartData,
                color: .blue
            )
            
            GlucoseReportCard(
                title: "Post-meal Glucose",
                metrics: analytics.postMeal,
                chartData: analytics.postMealChartData,
                color: .orange
            )
        }
    }
    
    private func loadReportData() async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
            let samples = try await healthKitManager.readBloodGlucoseSamples(since: twoWeeksAgo)
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

// MARK: - Week Range Header

struct WeekRangeHeader: View {
    let dateRange: WeekDateRange
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("This Week")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(dateRange.currentWeekFormatted)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Last Week")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(dateRange.previousWeekFormatted)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Report Card Component

struct GlucoseReportCard: View {
    let title: String
    let metrics: WeeklyMetrics
    let chartData: [WeeklyDataPoint]
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            cardHeader
            weeklyChart
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var cardHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
            
            HStack {
                Text("This Week Avg: \(metrics.formattedAverage) mg/dL")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if metrics.weekOverWeekChange != 0 {
                    PercentageChangeIndicator(change: metrics.weekOverWeekChange)
                }
            }
        }
    }
    
    private var weeklyChart: some View {
        Chart {
            ForEach(chartData, id: \.weekday) { dataPoint in
                BarMark(
                    x: .value("Day", dataPoint.dayName),
                    y: .value("Glucose", dataPoint.displayValue)
                )
                .foregroundStyle(dataPoint.hasData ? color : Color.gray.opacity(0.2))
            }
            
            if metrics.average > 0 {
                RuleMark(y: .value("Average", metrics.average))
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .annotation(position: .topTrailing) {
                        Text("Avg")
                            .font(.caption2)
                            .foregroundColor(color)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
            }
        }
        .frame(height: 180)
        .chartYScale(domain: 0...200)
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
            }
        }
    }
}

// MARK: - Percentage Change Indicator

struct PercentageChangeIndicator: View {
    let change: Double
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                .font(.caption)
            
            Text("\(abs(change), specifier: "%.1f")%")
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(change >= 0 ? .green : .red)
    }
}

// MARK: - Data Models

struct WeeklyAnalytics {
    let fasting: WeeklyMetrics
    let postMeal: WeeklyMetrics
    let fastingChartData: [WeeklyDataPoint]
    let postMealChartData: [WeeklyDataPoint]
    let dateRange: WeekDateRange
}

struct WeekDateRange {
    let currentWeekStart: Date
    let currentWeekEnd: Date
    let previousWeekStart: Date
    let previousWeekEnd: Date
    
    var currentWeekFormatted: String {
        formatWeekRange(start: currentWeekStart, end: currentWeekEnd)
    }
    
    var previousWeekFormatted: String {
        formatWeekRange(start: previousWeekStart, end: previousWeekEnd)
    }
    
    private func formatWeekRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let startString = formatter.string(from: start)
        let endString = formatter.string(from: end)
        
        return "\(startString) - \(endString)"
    }
}

struct WeeklyMetrics {
    let average: Double
    let weekOverWeekChange: Double
    
    var formattedAverage: String {
        String(format: "%.0f", average)
    }
}

struct WeeklyDataPoint {
    let weekday: Int // 1 = Sunday, 2 = Monday, ...
    let value: Double
    let hasData: Bool
    
    var dayName: String {
        let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return days[weekday - 1]
    }
    
    var displayValue: Double {
        hasData ? value : 0 // Minimum value for empty days
    }
}

// MARK: - Analytics Engine

struct WeeklyGlucoseAnalyzer {
    static func analyze(_ readings: [BloodGlucoseReading]) -> WeeklyAnalytics {
        let calendar = Calendar.current
        let now = Date()
        
        guard let currentWeek = calendar.dateInterval(of: .weekOfYear, for: now),
              let previousWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeek.start),
              let previousWeek = calendar.dateInterval(of: .weekOfYear, for: previousWeekStart) else {
            return createEmptyAnalytics()
        }
        
        let dateRange = WeekDateRange(
            currentWeekStart: currentWeek.start,
            currentWeekEnd: calendar.date(byAdding: .day, value: -1, to: currentWeek.end) ?? currentWeek.end,
            previousWeekStart: previousWeek.start,
            previousWeekEnd: calendar.date(byAdding: .day, value: -1, to: previousWeek.end) ?? previousWeek.end
        )
        
        let currentWeekReadings = filterReadings(readings, in: currentWeek)
        let previousWeekReadings = filterReadings(readings, in: previousWeek)
        
        let fastingMetrics = calculateMetrics(
            current: filterFastingReadings(currentWeekReadings),
            previous: filterFastingReadings(previousWeekReadings)
        )
        
        let postMealMetrics = calculateMetrics(
            current: filterPostMealReadings(currentWeekReadings),
            previous: filterPostMealReadings(previousWeekReadings)
        )
        
        let fastingChartData = generateChartData(
            filterFastingReadings(currentWeekReadings),
            weekInterval: currentWeek
        )
        
        let postMealChartData = generateChartData(
            filterPostMealReadings(currentWeekReadings),
            weekInterval: currentWeek
        )
        
        return WeeklyAnalytics(
            fasting: fastingMetrics,
            postMeal: postMealMetrics,
            fastingChartData: fastingChartData,
            postMealChartData: postMealChartData,
            dateRange: dateRange
        )
    }
    
    private static func createEmptyAnalytics() -> WeeklyAnalytics {
        let emptyMetrics = WeeklyMetrics(average: 0, weekOverWeekChange: 0)
        let emptyChartData = createEmptyChartData()
        
        let calendar = Calendar.current
        let now = Date()
        let currentWeek = calendar.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: now, duration: 0)
        let previousWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeek.start) ?? now
        let previousWeek = calendar.dateInterval(of: .weekOfYear, for: previousWeekStart) ?? DateInterval(start: previousWeekStart, duration: 0)
        
        let dateRange = WeekDateRange(
            currentWeekStart: currentWeek.start,
            currentWeekEnd: calendar.date(byAdding: .day, value: -1, to: currentWeek.end) ?? currentWeek.end,
            previousWeekStart: previousWeek.start,
            previousWeekEnd: calendar.date(byAdding: .day, value: -1, to: previousWeek.end) ?? previousWeek.end
        )
        
        return WeeklyAnalytics(
            fasting: emptyMetrics,
            postMeal: emptyMetrics,
            fastingChartData: emptyChartData,
            postMealChartData: emptyChartData,
            dateRange: dateRange
        )
    }
    
    private static func createEmptyChartData() -> [WeeklyDataPoint] {
        return (1...7).map { weekday in
            WeeklyDataPoint(weekday: weekday, value: 0, hasData: false)
        }
    }
    
    private static func filterReadings(_ readings: [BloodGlucoseReading], in interval: DateInterval) -> [BloodGlucoseReading] {
        return readings.filter { interval.contains($0.date) }
    }
    
    private static func filterFastingReadings(_ readings: [BloodGlucoseReading]) -> [BloodGlucoseReading] {
        return readings.filter { isFastingTime($0.date) }
    }
    
    private static func filterPostMealReadings(_ readings: [BloodGlucoseReading]) -> [BloodGlucoseReading] {
        return readings.filter { !isFastingTime($0.date) }
    }
    
    private static func isFastingTime(_ date: Date) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        return hour >= 6 && hour <= 9
    }
    
    private static func calculateMetrics(current: [BloodGlucoseReading], previous: [BloodGlucoseReading]) -> WeeklyMetrics {
        let currentAverage = calculateAverage(current)
        let previousAverage = calculateAverage(previous)
        let change = calculatePercentageChange(current: currentAverage, previous: previousAverage)
        
        return WeeklyMetrics(average: currentAverage, weekOverWeekChange: change)
    }
    
    private static func calculateAverage(_ readings: [BloodGlucoseReading]) -> Double {
        guard !readings.isEmpty else { return 0 }
        let sum = readings.reduce(0) { $0 + $1.value }
        return sum / Double(readings.count)
    }
    
    private static func calculatePercentageChange(current: Double, previous: Double) -> Double {
        guard previous > 0, current > 0 else { return 0 }
        return ((current - previous) / previous) * 100
    }
    
    private static func generateChartData(_ readings: [BloodGlucoseReading], weekInterval: DateInterval) -> [WeeklyDataPoint] {
        let calendar = Calendar.current
        var chartData: [WeeklyDataPoint] = []
        
        for dayOffset in 0..<7 {
            guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: weekInterval.start) else {
                continue
            }
            
            let weekday = dayOffset + 1
            let dayReadings = readings.filter { calendar.isDate($0.date, inSameDayAs: dayDate) }
            
            if dayReadings.isEmpty {
                chartData.append(WeeklyDataPoint(weekday: weekday, value: 0, hasData: false))
            } else {
                let average = calculateAverage(dayReadings)
                chartData.append(WeeklyDataPoint(weekday: weekday, value: average, hasData: true))
            }
        }
        
        return chartData
    }
}

#Preview {
    ReportView()
}
