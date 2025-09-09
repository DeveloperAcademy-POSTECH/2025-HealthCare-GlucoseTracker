//
//  TestView.swift
//  GlucoseTracker
//
//  Created by taeni on 9/9/25.
//

import SwiftUI
import HealthKit

struct TestView: View {
    @StateObject private var mockManager = MockHealthKitManager.shared
    @State private var customValue = "95.0"
    @State private var customDate = Date()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var sampleCount = 0
    @State private var recentSamples: [HKQuantitySample] = []
    
    var body: some View {
        NavigationView {
            List {
                currentStatusSection
                quickActionsSection
                scenarioDataSection
                customDataSection
                deletionSection
                managementSection
            }
            .navigationTitle("Test Data Manager")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await refreshData()
            }
        }
        .alert("Test Data", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            Task {
                await refreshData()
            }
        }
    }
    
    private var currentStatusSection: some View {
        Section("Current Status") {
            HStack {
                Text("HealthKit Samples Count")
                Spacer()
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("\(sampleCount)")
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
//                Text("Authorization Status")
//                Spacer()
//                Text(mockManager.getAuthorizationStatus().statusName)
//                    .foregroundColor(mockManager.getAuthorizationStatus() == .sharingAuthorized ? .green : .orange)
            }
            
            HStack {
                Text("HealthKit Available")
                Spacer()
                Text(mockManager.isHealthKitAvailable() ? "Yes" : "No")
                    .foregroundColor(mockManager.isHealthKitAvailable() ? .green : .red)
            }
        }
    }
    
    private var quickActionsSection: some View {
        Section("Quick Actions") {
            Button("Grant Authorization") {
                Task {
                    do {
                        _ = try await mockManager.requestAuthorization()
                        await refreshData()
                        showAlert("Authorization request completed!")
                    } catch {
                        showAlert("Authorization failed: \(error.localizedDescription)")
                    }
                }
            }
            .foregroundColor(.green)
            
            Button("Reset Authorization (Restart Required)") {
                showAlert("Please delete and reinstall the app to reset authorization")
            }
            .foregroundColor(.orange)
            
            Button("Refresh Data") {
                Task {
                    await refreshData()
                    showAlert("Data refreshed!")
                }
            }
            .foregroundColor(.blue)
        }
    }
    
    private var scenarioDataSection: some View {
        Section("Generate Test Data") {
            Button("Normal Pattern (14 days)") {
                Task {
                    isLoading = true
                    do {
                        try await mockManager.generateMockDataForTesting(scenario: .normal)
                        await refreshData()
                        showAlert("Generated normal pattern data with 3 readings per day")
                    } catch {
                        showAlert("Failed to generate data: \(error.localizedDescription)")
                    }
                    isLoading = false
                }
            }
            .disabled(isLoading)
            
            Button("High Variability (14 days)") {
                Task {
                    isLoading = true
                    do {
                        try await mockManager.generateMockDataForTesting(scenario: .highVariability)
                        await refreshData()
                        showAlert("Generated high variability data (70-180 mg/dL range)")
                    } catch {
                        showAlert("Failed to generate data: \(error.localizedDescription)")
                    }
                    isLoading = false
                }
            }
            .disabled(isLoading)
            
            Button("Trending Up (14 days)") {
                Task {
                    isLoading = true
                    do {
                        try await mockManager.generateMockDataForTesting(scenario: .trendingUp)
                        await refreshData()
                        showAlert("Generated upward trending data")
                    } catch {
                        showAlert("Failed to generate data: \(error.localizedDescription)")
                    }
                    isLoading = false
                }
            }
            .disabled(isLoading)
            
            Button("Trending Down (14 days)") {
                Task {
                    isLoading = true
                    do {
                        try await mockManager.generateMockDataForTesting(scenario: .trendingDown)
                        await refreshData()
                        showAlert("Generated downward trending data")
                    } catch {
                        showAlert("Failed to generate data: \(error.localizedDescription)")
                    }
                    isLoading = false
                }
            }
            .disabled(isLoading)
            
            Button("Sparse Data (5 readings)") {
                Task {
                    isLoading = true
                    do {
                        try await mockManager.generateMockDataForTesting(scenario: .sparseData)
                        await refreshData()
                        showAlert("Generated sparse data with gaps")
                    } catch {
                        showAlert("Failed to generate data: \(error.localizedDescription)")
                    }
                    isLoading = false
                }
            }
            .disabled(isLoading)
            
            Button("Empty Dataset") {
                Task {
                    isLoading = true
                    do {
                        try await mockManager.generateMockDataForTesting(scenario: .empty)
                        await refreshData()
                        showAlert("Cleared all data - empty dataset created")
                    } catch {
                        showAlert("Failed to clear data: \(error.localizedDescription)")
                    }
                    isLoading = false
                }
            }
            .disabled(isLoading)
        }
    }
    
    private var customDataSection: some View {
        Section("Add Custom Reading") {
            HStack {
                Text("Glucose Value")
                Spacer()
                TextField("mg/dL", text: $customValue)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                    .frame(width: 80)
                Text("mg/dL")
                    .foregroundColor(.secondary)
            }
            
            DatePicker("Date & Time", selection: $customDate)
            
            Button("Add Reading") {
                Task {
                    await addCustomReading()
                }
            }
            .disabled(!isValidValue || isLoading)
        }
    }
    
    private var deletionSection: some View {
        Section("Recent Samples (Last 10)") {
            if recentSamples.isEmpty {
                Text("No recent samples found")
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(recentSamples.prefix(10).enumerated()), id: \.offset) { index, sample in
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .milli).unitDivided(by: HKUnit.liter())), specifier: "%.1f") mg/dL")
                                .font(.headline)
                            Text(sample.startDate.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Delete") {
                            Task {
                                await deleteSample(sample)
                            }
                        }
                        .foregroundColor(.red)
                        .disabled(isLoading)
                    }
                }
            }
        }
    }
    
    private var managementSection: some View {
        Section("Data Management") {
            Button("Clear All Data (Last 30 Days)") {
                Task {
                    isLoading = true
                    do {
                        try await mockManager.clearMockSamples()
                        await refreshData()
                        showAlert("All data from last 30 days cleared!")
                    } catch {
                        showAlert("Failed to clear data: \(error.localizedDescription)")
                    }
                    isLoading = false
                }
            }
            .foregroundColor(.red)
            .disabled(isLoading)
            
            Button("Generate Random Today Data") {
                Task {
                    isLoading = true
                    do {
                        try await generateTodayData()
                        await refreshData()
                        showAlert("Added 3-5 random readings for today")
                    } catch {
                        showAlert("Failed to generate today's data: \(error.localizedDescription)")
                    }
                    isLoading = false
                }
            }
            .foregroundColor(.blue)
            .disabled(isLoading)
            
            Button("Generate Last Week Data") {
                Task {
                    isLoading = true
                    do {
                        try await generateLastWeekData()
                        await refreshData()
                        showAlert("Generated realistic data for the past 7 days")
                    } catch {
                        showAlert("Failed to generate week data: \(error.localizedDescription)")
                    }
                    isLoading = false
                }
            }
            .foregroundColor(.blue)
            .disabled(isLoading)
            
            Button("Simulate Request Failures") {
                mockManager.setShouldFailRequests(true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    mockManager.setShouldFailRequests(false)
                }
                showAlert("Requests will fail for the next 5 seconds")
            }
            .foregroundColor(.orange)
        }
    }
    
    private var isValidValue: Bool {
        guard let value = Double(customValue) else { return false }
        return value > 0 && value <= 500
    }
    
    private func refreshData() async {
        isLoading = true
        do {
            let count = try await mockManager.getMockSamplesCount()
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            let samples = try await mockManager.readBloodGlucoseSamples(since: thirtyDaysAgo)
            
            await MainActor.run {
                sampleCount = count
                recentSamples = Array(samples.prefix(10))
                isLoading = false
            }
        } catch {
            await MainActor.run {
                sampleCount = 0
                recentSamples = []
                isLoading = false
            }
        }
    }
    
    private func addCustomReading() async {
        guard let value = Double(customValue) else { return }
        
        isLoading = true
        do {
            try await mockManager.addMockSample(value: value, date: customDate)
            await refreshData()
            showAlert("Added reading: \(value) mg/dL at \(customDate.formatted(date: .abbreviated, time: .shortened))")
            
            await MainActor.run {
                customValue = ""
                customDate = Date()
            }
        } catch {
            showAlert("Failed to add reading: \(error.localizedDescription)")
            isLoading = false
        }
    }
    
    private func deleteSample(_ sample: HKQuantitySample) async {
        isLoading = true
        do {
            try await mockManager.deleteBloodGlucoseSample(sample)
            await refreshData()
            
            let value = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .milli).unitDivided(by: HKUnit.liter()))
            showAlert("Deleted reading: \(String(format: "%.1f", value)) mg/dL")
        } catch {
            showAlert("Failed to delete sample: \(error.localizedDescription)")
            isLoading = false
        }
    }
    
    private func generateTodayData() async throws {
        let calendar = Calendar.current
        let today = Date()
        let hours = [7, 12, 15, 18, 21]
        
        for i in 0..<Int.random(in: 3...5) {
            let hour = hours[i % hours.count]
            let minute = Int.random(in: 0...59)
            
            guard let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) else { continue }
            
            let value = generateRealisticValue(for: hour)
            try await mockManager.addMockSample(value: value, date: date)
        }
    }
    
    private func generateLastWeekData() async throws {
        let calendar = Calendar.current
        let today = Date()
        
        for day in 1...7 {
            guard let baseDate = calendar.date(byAdding: .day, value: -day, to: today) else { continue }
            
            let readingsPerDay = Int.random(in: 2...4)
            let hours = [7, 13, 19]
            
            for i in 0..<readingsPerDay {
                let hour = hours[i % hours.count]
                let minute = Int.random(in: 0...59)
                
                guard let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: baseDate) else { continue }
                
                let value = generateRealisticValue(for: hour)
                try await mockManager.addMockSample(value: value, date: date)
            }
        }
    }
    
    private func generateRealisticValue(for hour: Int) -> Double {
        switch hour {
        case 6...9:
            return Double.random(in: 80...100)
        case 12...14:
            return Double.random(in: 110...140)
        case 18...20:
            return Double.random(in: 100...130)
        default:
            return Double.random(in: 90...120)
        }
    }
    
    private func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
}

extension HKAuthorizationStatus {
    var statusName: String {
        switch self {
        case .notDetermined:
            return "Not Determined"
        case .sharingDenied:
            return "Denied"
        case .sharingAuthorized:
            return "Authorized"
        @unknown default:
            return "Unknown"
        }
    }
}

#Preview {
    TestView()
}
