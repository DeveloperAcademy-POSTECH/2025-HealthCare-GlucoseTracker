//
//  MealTimeType.swift
//  GlucoseTracker
//
//  Created by taeni on 9/10/25.
//

//
//  MealTimeType.swift
//  GlucoseTracker
//
//  Created by taeni on 9/13/25.
//

import SwiftUI
import Foundation

enum MealTimeType: CaseIterable {
    case fasting
    case postMeal
    case other
    
    var displayName: String {
        switch self {
        case .fasting:
            return "Fasting"
        case .postMeal:
            return "Post-meal"
        case .other:
            return "Other"
        }
    }
    
    var normalRange: ClosedRange<Double> {
        switch self {
        case .fasting:
            return 80...130
        case .postMeal:
            return 80...180
        case .other:
            return 80...140
        }
    }
    
    var lowThreshold: Double {
        return 80
    }
    
    static func from(reading: BloodGlucoseReading) -> MealTimeType {
        let hour = Calendar.current.component(.hour, from: reading.date)
        return from(hour: hour)
    }
    
    static func from(hour: Int) -> MealTimeType {
        if hour >= 6 && hour <= 9 {
            return .fasting
        } else if hour > 9 && hour <= 23 {
            return .postMeal
        } else {
            return .other
        }
    }
    
    func getGlucoseColor(for value: Double) -> Color {
        if value < lowThreshold {
            return .blue // Low glucose
        } else if normalRange.contains(value) {
            return .green // Normal range
        } else {
            return .red // High glucose
        }
    }
    
    func getGlucoseStatus(for value: Double) -> GlucoseStatus {
        if value < lowThreshold {
            return .low
        } else if normalRange.contains(value) {
            return .normal
        } else {
            return .high
        }
    }
}

enum GlucoseStatus {
    case low
    case normal
    case high
    
    var displayName: String {
        switch self {
        case .low:
            return "Low"
        case .normal:
            return "Normal"
        case .high:
            return "High"
        }
    }
    
    var color: Color {
        switch self {
        case .low:
            return .blue
        case .normal:
            return .green
        case .high:
            return .red
        }
    }
    
    var systemImageName: String {
        switch self {
        case .low:
            return "arrow.down.circle.fill"
        case .normal:
            return "checkmark.circle.fill"
        case .high:
            return "arrow.up.circle.fill"
        }
    }
}
