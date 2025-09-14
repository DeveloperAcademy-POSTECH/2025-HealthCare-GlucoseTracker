//
//  HKBloodGlucoseMealTime+.swift
//  GlucoseTracker
//
//  Created by taeni on 9/14/25.
//

import Foundation
import HealthKit
import SwiftUI

extension HKBloodGlucoseMealTime {
    // CaseIterable conformance 제거하고 static 속성으로 제공
    static var allMealTimes: [HKBloodGlucoseMealTime] {
        return [.preprandial, .postprandial]
    }
    
    var displayName: String {
        switch self {
        case .preprandial:
            return "Before Meal (Fasting)"
        case .postprandial:
            return "After Meal"
        @unknown default:
            return "Unknown"
        }
    }
    
    var normalRange: ClosedRange<Double> {
        switch self {
        case .preprandial:
            return 80...130  // 공복혈당 범위
        case .postprandial:
            return 80...180  // 식후혈당 범위
        @unknown default:
            return 80...140
        }
    }
    
    var lowThreshold: Double {
        return 80
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
    
    // 시간 기반으로 추측하는 헬퍼 메서드
    static func estimateFromTime(_ date: Date) -> HKBloodGlucoseMealTime {
        let hour = Calendar.current.component(.hour, from: date)
        if hour >= 6 && hour <= 9 {
            return .preprandial
        } else {
            return .postprandial
        }
    }
}

// nil 상태(기타)를 위한 헬퍼 함수들
extension Optional where Wrapped == HKBloodGlucoseMealTime {
    var displayName: String {
        switch self {
        case .some(let mealTime):
            return mealTime.displayName
        case .none:
            return "Other"
        }
    }
    
    var normalRange: ClosedRange<Double> {
        switch self {
        case .some(let mealTime):
            return mealTime.normalRange
        case .none:
            return 80...140  // 기타일 때 기본 범위
        }
    }
    
    func getGlucoseColor(for value: Double) -> Color {
        switch self {
        case .some(let mealTime):
            return mealTime.getGlucoseColor(for: value)
        case .none:
            if value < 80 {
                return .blue
            } else if (80...140).contains(value) {
                return .green
            } else {
                return .red
            }
        }
    }
    
    func getGlucoseStatus(for value: Double) -> GlucoseStatus {
        switch self {
        case .some(let mealTime):
            return mealTime.getGlucoseStatus(for: value)
        case .none:
            if value < 80 {
                return .low
            } else if (80...140).contains(value) {
                return .normal
            } else {
                return .high
            }
        }
    }
}
