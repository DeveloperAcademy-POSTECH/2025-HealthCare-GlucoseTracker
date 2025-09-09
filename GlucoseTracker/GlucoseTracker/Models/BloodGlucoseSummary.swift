//
//  BloodGlucoseSummary.swift
//  GlucoseTracker
//
//  Created by taeni on 9/9/25.
//

import Foundation

struct BloodGlucoseSummary: Identifiable {
    let id = UUID()
    let date: Date
    let fastingAverage: Double?
    let postMealAverage: Double?
}

extension BloodGlucoseSummary {
    var formattedFastingAverage: String {
        guard let average = fastingAverage else { return "--" }
        return String(format: "%.1f", average)
    }
    
    var formattedPostMealAverage: String {
        guard let average = postMealAverage else { return "--" }
        return String(format: "%.1f", average)
    }
    
    var formattedDate: String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}
