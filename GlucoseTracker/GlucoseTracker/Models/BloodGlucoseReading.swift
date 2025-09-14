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
    let mealTime: HKBloodGlucoseMealTime? // HKBloodGlucoseMealTime? 직접 사용
    
    init(from sample: HKQuantitySample) {
        let bloodGlucoseUnit = HKUnit.gramUnit(with: .milli).unitDivided(by: HKUnit.liter())
        self.value = sample.quantity.doubleValue(for: bloodGlucoseUnit)
        self.date = sample.startDate
        
        // HealthKit 표준 metadata에서 읽기
        if let metadata = sample.metadata,
           let mealTimeValue = metadata[HKMetadataKeyBloodGlucoseMealTime] as? NSNumber,
           let hkMealTime = HKBloodGlucoseMealTime(rawValue: mealTimeValue.intValue) {
            self.mealTime = hkMealTime
        } else {
            // metadata가 없으면 시간 기반으로 추정
            self.mealTime = HKBloodGlucoseMealTime.estimateFromTime(sample.startDate)
        }
    }
    
    init(value: Double, date: Date, mealTime: HKBloodGlucoseMealTime? = nil) {
        self.value = value
        self.date = date
        self.mealTime = mealTime
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
