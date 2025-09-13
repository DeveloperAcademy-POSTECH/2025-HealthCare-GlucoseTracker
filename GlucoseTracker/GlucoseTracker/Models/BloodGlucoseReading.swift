//
//  BloodGlucoseReading.swift
//  GlucoseTracker
//
//  Created by taeni on 9/9/25.
//

import Foundation
import HealthKit

struct BloodGlucoseReading: Identifiable {
    let id = UUID()
    let value: Double
    let date: Date
    
    init(from sample: HKQuantitySample) {
        let bloodGlucoseUnit = HKUnit.gramUnit(with: .milli).unitDivided(by: HKUnit.liter())
        self.value = sample.quantity.doubleValue(for: bloodGlucoseUnit)
        self.date = sample.startDate
    }
    
    init(value: Double, date: Date) {
        self.value = value
        self.date = date
    }
}

extension BloodGlucoseReading {
    var formattedTime: String {
        self.date.formatted(date: .omitted, time: .shortened)
    }
    
    var formattedValue: String {
        String(format: "%.1f", self.value)
    }
    
    var formattedDate: String {
        self.date.formatted(date: .abbreviated, time: .omitted)
    }
}
