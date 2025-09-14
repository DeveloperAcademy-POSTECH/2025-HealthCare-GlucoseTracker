//
//  HistoryView.swift
//  GlucoseTracker
//
//  Created by taeni on 9/9/25.
//

import SwiftUI
import HealthKit

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
                    
                    Text(reading.mealTime.displayName)
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
                        .foregroundColor(reading.mealTime.getGlucoseColor(for: reading.value))
                    
                    let status = reading.mealTime.getGlucoseStatus(for: reading.value)
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
        let preprandialToday = getGlucoseAverage(for: .preprandial, on: selectedDate)
        let preprandialYesterday = getGlucoseAverage(for: .preprandial, on: Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!)
        let preprandialChange = calculatePercentageChange(today: preprandialToday.rawValue, yesterday: preprandialYesterday.rawValue)

        let postprandialToday = getGlucoseAverage(for: .postprandial, on: selectedDate)
        let postprandialYesterday = getGlucoseAverage(for: .postprandial, on: Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!)
        let postprandialChange = calculatePercentageChange(today: postprandialToday.rawValue, yesterday: postprandialYesterday.rawValue)

        return VStack(spacing: 16) {
            HStack(spacing: 20) {
                summaryCardView(
                    title: "Preprandial",
                    value: preprandialToday.value,
                    change: preprandialChange,
                    color: .blue
                )
                
                summaryCardView(
                    title: "Postprandial",
                    value: postprandialToday.value,
                    change: postprandialChange,
                    color: .orange
                )
            }
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
    
    private func getFilteredRecords() -> [BloodGlucoseReading] {
        return bloodGlucoseData
            .filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.date > $1.date }
    }
    
    private func getGlucoseAverage(for mealType: HKBloodGlucoseMealTime, on date: Date) -> (value: String, rawValue: Double) {
        let records = bloodGlucoseData
            .filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .filter { $0.mealTime == mealType }
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
