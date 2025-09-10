//
//  MealTimeType.swift
//  GlucoseTracker
//
//  Created by taeni on 9/10/25.
//

import SwiftUI
import Foundation

enum MealTimeType: String, CaseIterable, Codable {
    case fasting = "fasting"
    case postMeal = "postMeal"
    case other = "other"
    
    // Display name for UI
    var displayName: String {
        switch self {
        case .fasting:
            return "Fasting"
        case .postMeal:
            return "After Meal"
        case .other:
            return "Other"
        }
    }
    
    // Target range description
    var targetRangeDescription: String {
        switch self {
        case .fasting:
            return "Target fasting blood glucose: 80-130mg/dL (American Diabetes Association)"
        case .postMeal:
            return "Target post-meal blood glucose: < 180mg/dL (American Diabetes Association)"
        case .other:
            return "Maintain a healthy blood glucose level for overall well-being."
        }
    }
    
    // Normal glucose range
    var normalRange: ClosedRange<Int> {
        switch self {
        case .fasting:
            return 80...130
        case .postMeal:
            return 100...179  // Less than 180 is considered normal
        case .other:
            return 70...200
        }
    }
    
    // Check if glucose level is normal for this meal type
    func isNormal(glucoseLevel: Double) -> Bool {
        let level = Int(glucoseLevel)
        return normalRange.contains(level)
    }
    
    // Get color based on glucose level for this meal type
    func getGlucoseColor(for glucoseLevel: Double) -> Color {
        return isNormal(glucoseLevel: glucoseLevel) ? .primary : .orange
    }
    
    // Static method to determine meal type from reading time
    static func from(reading: BloodGlucoseReading) -> MealTimeType {
        let hour = Calendar.current.component(.hour, from: reading.date)
        return from(hour: hour)
    }
    
    // Static method to determine meal type from hour
    static func from(hour: Int) -> MealTimeType {
        switch hour {
        case 6...9:
            return .fasting
        case 10...23:
            return .postMeal
        default:
            return .other
        }
    }
    
    // Get greeting message based on meal type and current time
    var greetingMessage: String {
        switch self {
        case .fasting:
            return "Good Morning,\nLet's check fasting glucose level"
        case .postMeal:
            return "Good Afternoon,\nHave you checked your glucose today?"
        case .other:
            return "Hello,\nTime to check your glucose level"
        }
    }
    
    // Get reminder message based on meal type
    var reminderMessage: String {
        switch self {
        case .fasting:
            return "Please remember to check your fasting blood sugar in the morning before eating or drinking anything. It's important for monitoring your health effectively."
        case .postMeal:
            return "Monitoring your glucose levels throughout the day is crucial. Make sure to record your post-meal readings for better tracking."
        case .other:
            return "Regular glucose monitoring helps maintain better control of your condition."
        }
    }
}

// MARK: - Helper Extensions
extension MealTimeType {
    // Get current meal type based on current time
    static var current: MealTimeType {
        let hour = Calendar.current.component(.hour, from: Date())
        return from(hour: hour)
    }
}
