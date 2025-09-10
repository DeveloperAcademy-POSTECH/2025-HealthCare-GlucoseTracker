//
//  HistoryView.swift
//  GlucoseTracker
//
//  Created by taeni on 9/9/25.
//

import SwiftUI
import HealthKit

struct HistoryView: View {
    @StateObject private var authManager = HealthKitAuthorizationManager()
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
        .onChange(of: selectedDate) { _, _ in
            // Date changed, no need to reload all data, just filter existing data
        }
    }
    
    private var historyContent: some View {
        VStack {
            DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(GraphicalDatePickerStyle())
                .frame(minHeight: 320)
                .padding()

            List {
                Section(header: Text("Summary").font(.headline)) {
                    summaryView()
                }

                let filteredRecords = getFilteredRecords()

                if filteredRecords.isEmpty {
                    Text("No records for this date")
                        .foregroundColor(.gray)
                } else {
                    Section(header: Text("Detailed Info").font(.headline)) {
                        ForEach(filteredRecords, id: \.id) { reading in
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(reading.formattedTime)
                                        .foregroundStyle(.gray)
                                    Text(MealTimeType.from(reading: reading).displayName)
                                        .padding(.leading, 5)
                                    Spacer()
                                    Text("\(reading.formattedValue) mg/dL")
                                        .foregroundColor(MealTimeType.from(reading: reading).getGlucoseColor(for: reading.value))
                                }
                            }
                            .padding(.vertical, 5)
                        }
                    }
                }
            }
        }
    }
    
    private func summaryView() -> some View {
        let fastingToday = getGlucoseAverage(for: .fasting, on: selectedDate)
        let fastingYesterday = getGlucoseAverage(for: .fasting, on: Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!)
        let fastingChange = calculatePercentageChange(today: fastingToday.rawValue, yesterday: fastingYesterday.rawValue)

        let postMealToday = getGlucoseAverage(for: .postMeal, on: selectedDate)
        let postMealYesterday = getGlucoseAverage(for: .postMeal, on: Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!)
        let postMealChange = calculatePercentageChange(today: postMealToday.rawValue, yesterday: postMealYesterday.rawValue)

        return VStack {
            HStack {
                VStack {
                    Text(MealTimeType.fasting.displayName + " Glucose")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(fastingToday.value)
                        .font(.headline)
                    Text(fastingChange.text)
                        .font(.caption)
                        .foregroundColor(fastingChange.color)
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Text(MealTimeType.postMeal.displayName + " Glucose")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(postMealToday.value)
                        .font(.headline)
                    Text(postMealChange.text)
                        .font(.caption)
                        .foregroundColor(postMealChange.color)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
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
            // Load data from the last 30 days for better performance
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            let samples = try await healthKitManager.readBloodGlucoseSamples(since: thirtyDaysAgo)
            let readings = BloodGlucoseDataProcessor.processBloodGlucoseSamples(samples)
            
            await MainActor.run {
                bloodGlucoseData = readings
                isLoading = false
            }
            
        } catch {
            await MainActor.run {
                let healthKitError = HealthKitError.from(error)
                errorMessage = healthKitError.userFriendlyMessage
                bloodGlucoseData = []
                isLoading = false
            }
        }
    }
}

#Preview {
    HistoryView()
}
