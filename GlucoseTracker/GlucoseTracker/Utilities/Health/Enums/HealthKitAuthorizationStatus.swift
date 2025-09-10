//
//  HealthKitAuthorizationStatus.swift
//  GlucoseTracker
//
//  Created by taeni on 9/10/25.
//

import HealthKit

enum HealthKitAuthorizationStatus {
    case notDetermined
    case authorized
    case denied
    case unavailable
    
    init(from hkStatus: HKAuthorizationStatus) {
        switch hkStatus {
        case .notDetermined:
            self = .notDetermined
        case .sharingAuthorized:
            self = .authorized
        case .sharingDenied:
            self = .denied
        @unknown default:
            self = .notDetermined
        }
    }
    
    var title: String {
        switch self {
        case .notDetermined:
            return "Permission Required"
        case .authorized:
            return "Authorized"
        case .denied:
            return "Permission Denied"
        case .unavailable:
            return "HealthKit Unavailable"
        }
    }
    
    var message: String {
        switch self {
        case .notDetermined:
            return "This app needs access to HealthKit to read and write blood glucose data."
        case .authorized:
            return "HealthKit access is granted."
        case .denied:
            return "HealthKit access is required for this app to function properly. Please enable it in Settings."
        case .unavailable:
            return "HealthKit is not available on this device."
        }
    }
}
