//
//  HealthKitManager.swift
//  GlucoseTracker
//
//  Created by taeni on 9/9/25.
//

import HealthKit

class HealthKitManager: HealthKitManagerProtocol {
    
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    private let bloodGlucoseType = HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!
    private let bloodGlucoseUnit = HKUnit.gramUnit(with: .milli).unitDivided(by: HKUnit.liter())
    
    private init() {
        setupHealthKit()
    }
    
    private func setupHealthKit() {
        guard HKHealthStore.isHealthDataAvailable() else {
            return
        }
        
        guard validateBloodGlucoseTypeSupport() else {
            return
        }
    }
    
    private func validateBloodGlucoseTypeSupport() -> Bool {
        return bloodGlucoseType.identifier == HKQuantityTypeIdentifier.bloodGlucose.rawValue
    }
    
    func getAuthorizationStatus() -> HKAuthorizationStatus {
        return healthStore.authorizationStatus(for: bloodGlucoseType)
    }
    
    func requestAuthorization() async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthDataNotAvailable
        }
        
        let currentStatus = getAuthorizationStatus()
        
        if currentStatus == .sharingAuthorized {
            return true
        }
        
        let typesToShare: Set<HKSampleType> = [bloodGlucoseType]
        let typesToRead: Set<HKObjectType> = [bloodGlucoseType]
        
        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
            
            let newStatus = getAuthorizationStatus()
            return newStatus == .sharingAuthorized
            
        } catch {
            throw HealthKitError.authorizationFailed
        }
    }
    
    func readBloodGlucoseSamples(since date: Date) async throws -> [HKQuantitySample] {
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
    
    func isHealthKitAvailable() -> Bool {
        return HKHealthStore.isHealthDataAvailable() && validateBloodGlucoseTypeSupport()
    }
    
    func readBloodGlucoseSamples(from startDate: Date, to endDate: Date) async throws -> [HKQuantitySample] {
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
    
    func deleteBloodGlucoseSample(_ sample: HKQuantitySample) async throws {
        try await verifyAuthorizationForWriting()
        
        do {
            try await healthStore.delete(sample)
        } catch {
            throw HealthKitError.dataSaveFailed("Failed to delete sample: \(error.localizedDescription)")
        }
    }
    
    func getLatestBloodGlucoseReading() async throws -> HKQuantitySample? {
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
    
    func saveBloodGlucoseSample(value: Double, unit: HKUnit, date: Date) async throws {
        try await verifyAuthorizationForWriting()
        
        guard value > 0 else {
            throw HealthKitError.dataSaveFailed("Blood glucose value must be greater than 0")
        }
        
        guard date <= Date() else {
            throw HealthKitError.dataSaveFailed("Cannot save data for future dates")
        }
        
        let quantity = HKQuantity(unit: unit, doubleValue: value)
        let sample = HKQuantitySample(
            type: bloodGlucoseType,
            quantity: quantity,
            start: date,
            end: date
        )
        
        do {
            try await healthStore.save(sample)
        } catch {
            throw HealthKitError.dataSaveFailed(error.localizedDescription)
        }
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
