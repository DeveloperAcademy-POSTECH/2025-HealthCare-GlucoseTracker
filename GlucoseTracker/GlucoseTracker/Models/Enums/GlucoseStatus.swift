//
//  GlucoseStatus.swift
//  GlucoseTracker
//
//  Created by taeni on 9/14/25.
//

import SwiftUI

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
