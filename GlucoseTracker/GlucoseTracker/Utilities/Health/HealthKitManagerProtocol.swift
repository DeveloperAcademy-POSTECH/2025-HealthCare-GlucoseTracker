//
//  HealthKitManagerProtocol.swift
//  GlucoseTracker
//
//  Created by taeni on 9/9/25.
//

import HealthKit

protocol HealthKitManagerProtocol {
    func getAuthorizationStatus() -> HKAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func readBloodGlucoseSamples(since date: Date) async throws -> [HKQuantitySample]
    func readBloodGlucoseSamples(from startDate: Date, to endDate: Date) async throws -> [HKQuantitySample]
    func getLatestBloodGlucoseReading() async throws -> HKQuantitySample?
    func saveBloodGlucoseSample(value: Double, unit: HKUnit, date: Date) async throws
    func deleteBloodGlucoseSample(_ sample: HKQuantitySample) async throws
    func isHealthKitAvailable() -> Bool
}
