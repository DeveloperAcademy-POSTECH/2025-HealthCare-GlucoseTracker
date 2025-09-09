//
//  BloodGlucoseDataProcessor.swift
//  GlucoseTracker
//
//  Created by taeni on 9/9/25.
//

import Foundation
import HealthKit

struct BloodGlucoseDataProcessor {
    
    static func processBloodGlucoseSamples(_ samples: [HKQuantitySample]) -> [BloodGlucoseReading] {
        return samples.compactMap { BloodGlucoseReading(from: $0) }
    }
    
    static func calculateSummary(from readings: [BloodGlucoseReading]) -> BloodGlucoseSummary {
        
        let fastingReadings = readings.filter { reading in
            let hour = Calendar.current.component(.hour, from: reading.date)
            return hour >= 6 && hour <= 9
        }
        
        let postMealReadings = readings.filter { reading in
            let hour = Calendar.current.component(.hour, from: reading.date)
            return hour > 9
        }
        
        let fastingAverage = fastingReadings.isEmpty ? nil : fastingReadings.map { $0.value }.reduce(0, +) / Double(fastingReadings.count)
        let postMealAverage = postMealReadings.isEmpty ? nil : postMealReadings.map { $0.value }.reduce(0, +) / Double(postMealReadings.count)
        
        return BloodGlucoseSummary(date: readings.first?.date ?? Date(), fastingAverage: fastingAverage, postMealAverage: postMealAverage)
    }
    
    static func processSamplesForReport(samples: [HKQuantitySample]) -> [BloodGlucoseReading] {
        return samples.compactMap { BloodGlucoseReading(from: $0) }
    }
    
    static func groupReadingsByDate(_ readings: [BloodGlucoseReading]) -> [String: [BloodGlucoseReading]] {
        let calendar = Calendar.current
        return Dictionary(grouping: readings) { reading in
            calendar.dateInterval(of: .day, for: reading.date)?.start.formatted(date: .abbreviated, time: .omitted) ?? ""
        }
    }
    
    static func calculateDailyAverages(_ readings: [BloodGlucoseReading]) -> [(date: Date, average: Double)] {
        let calendar = Calendar.current
        let groupedByDay = Dictionary(grouping: readings) { reading in
            calendar.startOfDay(for: reading.date)
        }
        
        return groupedByDay.compactMap { (date, dayReadings) in
            let average = dayReadings.map { $0.value }.reduce(0, +) / Double(dayReadings.count)
            return (date: date, average: average)
        }.sorted { $0.date < $1.date }
    }
}
