//
//  TimeBasedGreeting.swift
//  GlucoseTracker
//
//  Created by taeni on 9/14/25.
//

import Foundation
import SwiftUI
import HealthKit

struct TimeBasedGreeting {
    let greeting: String
    let title: String
    let message: String
    let icon: String
    let iconColor: Color
    
    static func current() -> TimeBasedGreeting {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 5..<12:
            return TimeBasedGreeting(
                greeting: "Good Morning!",
                title: "Let's start with your fasting glucose level",
                message: "Remember to check your fasting blood sugar in the morning before eating or drinking anything.",
                icon: "sunrise.fill",
                iconColor: .orange
            )
            
        case 12..<17:
            return TimeBasedGreeting(
                greeting: "Good Afternoon!",
                title: "Time to track your post-meal glucose",
                message: "Monitor your blood glucose levels 1-2 hours after your meal to understand how food affects your levels.",
                icon: "sun.max.fill",
                iconColor: .yellow
            )
            
        case 17..<22:
            return TimeBasedGreeting(
                greeting: "Good Evening!",
                title: "Record your evening glucose reading",
                message: "Evening readings help track how your glucose levels change throughout the day and after dinner.",
                icon: "sunset.fill",
                iconColor: .orange
            )
            
        default: // 22-4시 (밤/새벽)
            return TimeBasedGreeting(
                greeting: "Good Night!",
                title: "Late night glucose check",
                message: "If you're checking your glucose at this hour, make sure to get adequate rest for better glucose control.",
                icon: "moon.stars.fill",
                iconColor: .purple
            )
        }
    }
}

// MARK: - Time Period Enum for better organization
enum TimePeriod {
    case morning    // 5-11시
    case afternoon  // 12-16시  
    case evening    // 17-21시
    case night      // 22-4시
    
    static func current() -> TimePeriod {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 5..<12: 
            return .morning
        case 12..<17: 
            return .afternoon
        case 17..<22: 
            return .evening
        default: 
            return .night
        }
    }
    
    var recommendedMealTime: HKBloodGlucoseMealTime? {
        switch self {
        case .morning:
            return .preprandial  // 공복혈당 권장
        case .afternoon, .evening:
            return .postprandial // 식후혈당 권장
        case .night:
            return nil // 특별한 권장 없음
        }
    }
    
    var displayName: String {
        switch self {
        case .morning:
            return "Morning"
        case .afternoon:
            return "Afternoon"
        case .evening:
            return "Evening"
        case .night:
            return "Night"
        }
    }
    
    var description: String {
        switch self {
        case .morning:
            return "Best time for fasting glucose measurements"
        case .afternoon:
            return "Good time for post-meal readings"
        case .evening:
            return "Track your evening glucose levels"
        case .night:
            return "Late night monitoring if needed"
        }
    }
}
