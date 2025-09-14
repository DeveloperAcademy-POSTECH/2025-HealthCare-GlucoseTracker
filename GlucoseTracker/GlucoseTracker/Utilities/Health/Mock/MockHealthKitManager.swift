//
//  MockHealthKitManager.swift
//  GlucoseTracker
//
//  Created by taeni on 9/9/25.
//

import HealthKit
import Foundation

class MockHealthKitManager: HealthKitManagerProtocol, ObservableObject {
    
    static let shared = MockHealthKitManager()
    
    @Published private var mockSamples: [HKQuantitySample] = []
    @Published private var authorizationStatus: HKAuthorizationStatus = .notDetermined
    @Published private var shouldFailRequests = false
    
    private let healthStore = HKHealthStore()
    private let bloodGlucoseType = HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!
    private let bloodGlucoseUnit = HKUnit.gramUnit(with: .milli).unitDivided(by: HKUnit.liter())
    
    private init() {
        checkInitialAuthorizationStatus()
    }
    
    private func checkInitialAuthorizationStatus() {
        authorizationStatus = healthStore.authorizationStatus(for: bloodGlucoseType)
    }
    
    func getAuthorizationStatus() -> HKAuthorizationStatus {
        let currentStatus = healthStore.authorizationStatus(for: bloodGlucoseType)
        authorizationStatus = currentStatus
        return currentStatus
    }
    
    func requestAuthorization() async throws -> Bool {
        if shouldFailRequests {
            throw HealthKitError.authorizationFailed
        }
        
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthDataNotAvailable
        }
        
        let typesToShare: Set<HKSampleType> = [bloodGlucoseType]
        let typesToRead: Set<HKObjectType> = [bloodGlucoseType]
        
        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
            
            await MainActor.run {
                authorizationStatus = healthStore.authorizationStatus(for: bloodGlucoseType)
            }
            
            return authorizationStatus == .sharingAuthorized
            
        } catch {
            throw HealthKitError.authorizationFailed
        }
    }
    
    func readBloodGlucoseSamples(since date: Date) async throws -> [HKQuantitySample] {
        if shouldFailRequests {
            throw HealthKitError.dataReadFailed("Mock read failed")
        }
        
        try await verifyAuthorizationForReading()
        
        let predicate = HKQuery.predicateForSamples(withStart: date, end: nil, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: bloodGlucoseType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { (_, samples, error) in
                
                if let error = error {
                    continuation.resume(throwing: HealthKitError.dataReadFailed(error.localizedDescription))
                    return
                }
                
                guard let bloodGlucoseSamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }
                
                continuation.resume(returning: bloodGlucoseSamples)
            }
            
            healthStore.execute(query)
        }
    }
    
    func readBloodGlucoseSamples(from startDate: Date, to endDate: Date) async throws -> [HKQuantitySample] {
        if shouldFailRequests {
            throw HealthKitError.dataReadFailed("Mock read failed")
        }
        
        try await verifyAuthorizationForReading()
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: bloodGlucoseType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { (_, samples, error) in
                
                if let error = error {
                    continuation.resume(throwing: HealthKitError.dataReadFailed(error.localizedDescription))
                    return
                }
                
                guard let bloodGlucoseSamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }
                
                continuation.resume(returning: bloodGlucoseSamples)
            }
            
            healthStore.execute(query)
        }
    }
    
    func getLatestBloodGlucoseReading() async throws -> HKQuantitySample? {
        if shouldFailRequests {
            throw HealthKitError.dataReadFailed("Mock read failed")
        }
        
        try await verifyAuthorizationForReading()
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: bloodGlucoseType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { (_, samples, error) in
                
                if let error = error {
                    continuation.resume(throwing: HealthKitError.dataReadFailed(error.localizedDescription))
                    return
                }
                
                let sample = samples?.first as? HKQuantitySample
                continuation.resume(returning: sample)
            }
            
            healthStore.execute(query)
        }
    }
    
    // 기존 메서드 (하위 호환성)
    func saveBloodGlucoseSample(value: Double, date: Date) async throws {
        let unit = bloodGlucoseUnit
        let metadata: [String: Any] = [HKMetadataKeyWasUserEntered: true]
        try await saveBloodGlucoseSample(value: value, unit: unit, date: date, metadata: metadata)
    }
    
    // 새로운 metadata 지원 메서드 (완전 구현)
    func saveBloodGlucoseSample(value: Double, unit: HKUnit, date: Date, metadata: [String: Any]) async throws {
        if shouldFailRequests {
            throw HealthKitError.dataSaveFailed("Mock save failed")
        }
        
        try await verifyAuthorizationForWriting()
        
        guard value > 0 else {
            throw HealthKitError.dataSaveFailed("Blood glucose value must be greater than 0")
        }
        
        // 미래 날짜 체크를 더 관대하게 수정 (1분 여유)
        let now = Date()
        let allowedFutureDate = now.addingTimeInterval(60) // 1분 여유
        
        guard date <= allowedFutureDate else {
            print("Date validation failed:")
            print("Trying to save date: \(date)")
            print("Current time: \(now)")
            print("Difference: \(date.timeIntervalSince(now)) seconds")
            throw HealthKitError.dataSaveFailed("Cannot save data for future dates")
        }
        
        let quantity = HKQuantity(unit: unit, doubleValue: value)
        let sample = HKQuantitySample(
            type: bloodGlucoseType,
            quantity: quantity,
            start: date,
            end: date,
            metadata: metadata
        )
        
        do {
            try await healthStore.save(sample)
            print("Successfully saved sample: \(value) mg/dL at \(date) with metadata: \(metadata)")
        } catch {
            print("Failed to save sample: \(error)")
            throw HealthKitError.dataSaveFailed(error.localizedDescription)
        }
    }
    
    func deleteBloodGlucoseSample(_ sample: HKQuantitySample) async throws {
        if shouldFailRequests {
            throw HealthKitError.dataSaveFailed("Mock delete failed")
        }
        
        try await verifyAuthorizationForWriting()
        
        do {
            try await healthStore.delete(sample)
        } catch {
            throw HealthKitError.dataSaveFailed("Failed to delete sample: \(error.localizedDescription)")
        }
    }
    
    func isHealthKitAvailable() -> Bool {
        return HKHealthStore.isHealthDataAvailable()
    }
    
    private func verifyAuthorizationForReading() async throws {
        let status = getAuthorizationStatus()
        
        switch status {
        case .notDetermined:
            let granted = try await requestAuthorization()
            if !granted {
                throw HealthKitError.authorizationFailed
            }
            
        case .sharingDenied:
            throw HealthKitError.authorizationFailed
            
        case .sharingAuthorized:
            break
            
        @unknown default:
            throw HealthKitError.authorizationFailed
        }
    }
    
    private func verifyAuthorizationForWriting() async throws {
        let status = getAuthorizationStatus()
        
        switch status {
        case .notDetermined:
            let granted = try await requestAuthorization()
            if !granted {
                throw HealthKitError.authorizationFailed
            }
            
        case .sharingDenied:
            throw HealthKitError.authorizationFailed
            
        case .sharingAuthorized:
            break
            
        @unknown default:
            throw HealthKitError.authorizationFailed
        }
    }
}

// MARK: - Mock Data Generation Extensions

extension MockHealthKitManager {
    func setAuthorizationStatus(_ status: HKAuthorizationStatus) {
        Task { @MainActor in
            authorizationStatus = status
        }
    }
    
    func setShouldFailRequests(_ shouldFail: Bool) {
        Task { @MainActor in
            shouldFailRequests = shouldFail
        }
    }
    
    func addMockSample(value: Double, date: Date) async throws {
        try await saveBloodGlucoseSample(value: value, date: date)
    }
    
    func clearMockSamples() async throws {
        let sixtyDaysAgo = Calendar.current.date(byAdding: .day, value: -60, to: Date()) ?? Date()
        let samples = try await readBloodGlucoseSamples(since: sixtyDaysAgo)
        
        print("Clearing \(samples.count) existing samples...")
        
        for sample in samples {
            try await deleteBloodGlucoseSample(sample)
        }
    }
    
    func getMockSamplesCount() async throws -> Int {
        let sixtyDaysAgo = Calendar.current.date(byAdding: .day, value: -60, to: Date()) ?? Date()
        let samples = try await readBloodGlucoseSamples(since: sixtyDaysAgo)
        return samples.count
    }
    
    func generateMockDataForTesting(scenario: MockDataScenario) async throws {
        try await clearMockSamples()
        
        switch scenario {
        case .normal:
            try await generateNormalMockData()
        case .highVariability:
            try await generateHighVariabilityMockData()
        case .trendingUp:
            try await generateTrendingUpMockData()
        case .trendingDown:
            try await generateTrendingDownMockData()
        case .sparseData:
            try await generateSparseDataMockData()
        case .empty:
            break
        }
    }
    
    private func createSafeDate(daysAgo: Int, hour: Int, minute: Int = 0) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        
        guard let baseDate = calendar.date(byAdding: .day, value: -daysAgo, to: now) else {
            return nil
        }
        
        let startOfDay = calendar.startOfDay(for: baseDate)
        
        guard let finalDate = calendar.date(byAdding: .hour, value: hour, to: startOfDay),
              let finalDateWithMinute = calendar.date(byAdding: .minute, value: minute, to: finalDate) else {
            return nil
        }
        
        if finalDateWithMinute > now {
            print("Generated date \(finalDateWithMinute) is in the future, using \(now) instead")
            return now.addingTimeInterval(-Double.random(in: 60...3600))
        }
        
        return finalDateWithMinute
    }
    
    private func generateNormalMockData() async throws {
        print("Generating normal mock data...")
        
        for day in 0..<14 {
            let readings: [(hour: Int, value: Double, mealTime: HKBloodGlucoseMealTime)] = [
                (7, Double.random(in: 85...95), .preprandial),
                (13, Double.random(in: 110...125), .postprandial),
                (19, Double.random(in: 100...120), .postprandial)
            ]
            
            for reading in readings {
                guard let date = createSafeDate(
                    daysAgo: day,
                    hour: reading.hour,
                    minute: Int.random(in: 0...59)
                ) else {
                    print("Failed to create date for day \(day), hour \(reading.hour)")
                    continue
                }
                
                let metadata: [String: Any] = [
                    HKMetadataKeyWasUserEntered: true,
                    HKMetadataKeyBloodGlucoseMealTime: reading.mealTime.rawValue
                ]
                
                try await saveBloodGlucoseSample(
                    value: reading.value,
                    unit: bloodGlucoseUnit,
                    date: date,
                    metadata: metadata
                )
            }
        }
        
        print("Normal mock data generation completed")
    }
    
    private func generateHighVariabilityMockData() async throws {
        print("Generating high variability mock data...")
        
        for day in 0..<14 {
            let readings: [(hour: Int, value: Double, mealTime: HKBloodGlucoseMealTime)] = [
                (7, Double.random(in: 70...180), .preprandial),
                (13, Double.random(in: 70...180), .postprandial),
                (19, Double.random(in: 70...180), .postprandial)
            ]
            
            for reading in readings {
                guard let date = createSafeDate(
                    daysAgo: day,
                    hour: reading.hour,
                    minute: Int.random(in: 0...59)
                ) else {
                    continue
                }
                
                let metadata: [String: Any] = [
                    HKMetadataKeyWasUserEntered: true,
                    HKMetadataKeyBloodGlucoseMealTime: reading.mealTime.rawValue
                ]
                
                try await saveBloodGlucoseSample(
                    value: reading.value,
                    unit: bloodGlucoseUnit,
                    date: date,
                    metadata: metadata
                )
            }
        }
        
        print("High variability mock data generation completed")
    }
    
    private func generateTrendingUpMockData() async throws {
        print("Generating trending up mock data...")
        
        for day in 0..<14 {
            let trend = Double(14 - day) * 2.0
            let readings: [(hour: Int, baseValue: Double, mealTime: HKBloodGlucoseMealTime)] = [
                (7, 85.0, .preprandial),
                (13, 115.0, .postprandial),
                (19, 105.0, .postprandial)
            ]
            
            for reading in readings {
                let value = reading.baseValue + trend + Double.random(in: -3...3)
                let clampedValue = max(70.0, min(200.0, value))
                
                guard let date = createSafeDate(
                    daysAgo: day,
                    hour: reading.hour,
                    minute: Int.random(in: 0...59)
                ) else {
                    continue
                }
                
                let metadata: [String: Any] = [
                    HKMetadataKeyWasUserEntered: true,
                    HKMetadataKeyBloodGlucoseMealTime: reading.mealTime.rawValue
                ]
                
                try await saveBloodGlucoseSample(
                    value: clampedValue,
                    unit: bloodGlucoseUnit,
                    date: date,
                    metadata: metadata
                )
            }
        }
        
        print("Trending up mock data generation completed")
    }
    
    private func generateTrendingDownMockData() async throws {
        print("Generating trending down mock data...")
        
        for day in 0..<14 {
            let trend = Double(day) * -1.5
            let readings: [(hour: Int, baseValue: Double, mealTime: HKBloodGlucoseMealTime)] = [
                (7, 110.0, .preprandial),
                (13, 140.0, .postprandial),
                (19, 125.0, .postprandial)
            ]
            
            for reading in readings {
                let value = reading.baseValue + trend + Double.random(in: -3...3)
                let clampedValue = max(70.0, min(200.0, value))
                
                guard let date = createSafeDate(
                    daysAgo: day,
                    hour: reading.hour,
                    minute: Int.random(in: 0...59)
                ) else {
                    continue
                }
                
                let metadata: [String: Any] = [
                    HKMetadataKeyWasUserEntered: true,
                    HKMetadataKeyBloodGlucoseMealTime: reading.mealTime.rawValue
                ]
                
                try await saveBloodGlucoseSample(
                    value: clampedValue,
                    unit: bloodGlucoseUnit,
                    date: date,
                    metadata: metadata
                )
            }
        }
        
        print("Trending down mock data generation completed")
    }
    
    private func generateSparseDataMockData() async throws {
        print("Generating sparse mock data...")
        
        let sparseDays = [0, 3, 7, 10, 13]
        
        for day in sparseDays {
            let hour = Int.random(in: 7...19)
            let value = Double.random(in: 80...140)
            let mealTime: HKBloodGlucoseMealTime = hour <= 9 ? .preprandial : .postprandial
            
            guard let date = createSafeDate(
                daysAgo: day,
                hour: hour,
                minute: Int.random(in: 0...59)
            ) else {
                continue
            }
            
            let metadata: [String: Any] = [
                HKMetadataKeyWasUserEntered: true,
                HKMetadataKeyBloodGlucoseMealTime: mealTime.rawValue
            ]
            
            try await saveBloodGlucoseSample(
                value: value,
                unit: bloodGlucoseUnit,
                date: date,
                metadata: metadata
            )
        }
        
        print("Sparse mock data generation completed")
    }
}

enum MockDataScenario {
    case normal
    case highVariability
    case trendingUp
    case trendingDown
    case sparseData
    case empty
}

extension MockDataScenario {
    var description: String {
        switch self {
        case .normal:
            return "Normal glucose readings with typical daily patterns"
        case .highVariability:
            return "High variability with both very low and very high readings"
        case .trendingUp:
            return "Gradually increasing glucose levels over time"
        case .trendingDown:
            return "Gradually decreasing glucose levels over time"
        case .sparseData:
            return "Limited data with gaps between measurements"
        case .empty:
            return "No glucose data available"
        }
    }
}
