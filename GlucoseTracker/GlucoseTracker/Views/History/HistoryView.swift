//
//  HistoryView.swift
//  GlucoseTracker
//
//  Created by taeni on 9/9/25.
//

import SwiftUI
import HealthKit

// MARK: - History Calendar Data Source

class HistoryCalendarDataSource: CalendarDataSource, ObservableObject {
    private var bloodGlucoseData: [BloodGlucoseReading] = []
    private let calendar = Calendar.current
    
    func updateData(_ data: [BloodGlucoseReading]) {
        bloodGlucoseData = data
    }
    
    func hasData(for date: Date) -> Bool {
        return bloodGlucoseData.contains { reading in
            calendar.isDate(reading.date, inSameDayAs: date)
        }
    }
}

// MARK: - History View

struct HistoryView: View {
    @StateObject private var authManager = HealthKitAuthorizationManager()
    @StateObject private var calendarDataSource = HistoryCalendarDataSource()
    @State private var selectedDate = Date()
    @State private var bloodGlucoseData: [BloodGlucoseReading] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
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
                Task { await loadHistoryData() }
            }
        }
        .refreshable {
            if authManager.isAuthorized {
                await loadHistoryData()
            }
        }
    }
    
    private var mainContent: some View {
        VStack {
            if isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                historyContent
            }
        }
        .navigationTitle("History")
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }
    
    private var historyContent: some View {
        VStack {
            CustomCalendarView(
                selectedDate: $selectedDate,
                dataSource: calendarDataSource,
                onDateSelected: { date in
                    selectedDate = date
                }
            )
            .padding()

            List {
                Section(header: Text("Summary").font(.headline)) {
                    summaryView()
                }

                let filteredRecords = getFilteredRecords()

                if filteredRecords.isEmpty {
                    HStack {
                        Spacer()
                        Text("No records for this date")
                            .foregroundColor(.gray)
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding()
                } else {
                    Section(header: Text("Detailed Info").font(.headline)) {
                        ForEach(filteredRecords, id: \.id) { reading in
                            readingRowView(reading: reading)
                        }
                    }
                }
            }
        }
    }
    
    private func readingRowView(reading: BloodGlucoseReading) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(reading.formattedTime)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(MealTimeType.from(reading: reading).displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(reading.formattedValue) mg/dL")
                        .font(.headline)
                        .foregroundColor(MealTimeType.from(reading: reading).getGlucoseColor(for: reading.value))
                    
                    let status = MealTimeType.from(reading: reading).getGlucoseStatus(for: reading.value)
                    HStack(spacing: 4) {
                        Image(systemName: status.systemImageName)
                            .font(.caption)
                            .foregroundColor(status.color)
                        Text(status.displayName)
                            .font(.caption)
                            .foregroundColor(status.color)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func summaryView() -> some View {
        let fastingToday = getGlucoseAverage(for: .fasting, on: selectedDate)
        let fastingYesterday = getGlucoseAverage(for: .fasting, on: Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!)
        let fastingChange = calculatePercentageChange(today: fastingToday.rawValue, yesterday: fastingYesterday.rawValue)

        let postMealToday = getGlucoseAverage(for: .postMeal, on: selectedDate)
        let postMealYesterday = getGlucoseAverage(for: .postMeal, on: Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!)
        let postMealChange = calculatePercentageChange(today: postMealToday.rawValue, yesterday: postMealYesterday.rawValue)

        return VStack(spacing: 16) {
            HStack(spacing: 20) {
                summaryCardView(
                    title: MealTimeType.fasting.displayName,
                    value: fastingToday.value,
                    change: fastingChange,
                    color: .blue
                )
                
                summaryCardView(
                    title: MealTimeType.postMeal.displayName,
                    value: postMealToday.value,
                    change: postMealChange,
                    color: .orange
                )
            }
            
//            selectedDateView
        }
        .padding()
    }
    
    private func summaryCardView(title: String, value: String, change: (text: String, color: Color), color: Color) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text(value)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(change.text)
                .font(.caption)
                .foregroundColor(change.color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var selectedDateView: some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundColor(.accentColor)
            
            Text(selectedDate.formatted(date: .complete, time: .omitted))
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            let recordCount = getFilteredRecords().count
            Text("\(recordCount) record\(recordCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func getFilteredRecords() -> [BloodGlucoseReading] {
        return bloodGlucoseData
            .filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.date > $1.date }
    }
    
    private func getGlucoseAverage(for mealType: MealTimeType, on date: Date) -> (value: String, rawValue: Double) {
        let records = bloodGlucoseData
            .filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .filter { MealTimeType.from(reading: $0) == mealType }
            .map { $0.value }

        if records.isEmpty {
            return ("No data", 0)
        } else {
            let avg = records.reduce(0, +) / Double(records.count)
            return ("\(Int(avg)) mg/dL", avg)
        }
    }
    
    private func calculatePercentageChange(today: Double, yesterday: Double) -> (text: String, color: Color) {
        guard yesterday > 0 else { return ("No comparison", .gray) }

        let change = ((today - yesterday) / yesterday) * 100
        let roundedChange = round(change * 10) / 10

        if change > 0 {
            return ("↑ \(roundedChange)%", .orange)
        } else if change < 0 {
            return ("↓ \(-roundedChange)%", .blue)
        } else {
            return ("No change", .gray)
        }
    }
    
    private func loadHistoryData() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // Load data from the last 60 days for better performance
            let sixtyDaysAgo = Calendar.current.date(byAdding: .day, value: -60, to: Date()) ?? Date()
            let samples = try await healthKitManager.readBloodGlucoseSamples(since: sixtyDaysAgo)
            let readings = BloodGlucoseDataProcessor.processBloodGlucoseSamples(samples)
            
            await MainActor.run {
                bloodGlucoseData = readings
                calendarDataSource.updateData(readings)
                isLoading = false
            }
            
        } catch {
            await MainActor.run {
                let healthKitError = HealthKitError.from(error)
                errorMessage = healthKitError.userFriendlyMessage
                bloodGlucoseData = []
                calendarDataSource.updateData([])
                isLoading = false
            }
        }
    }
}

#Preview {
    HistoryView()
}
