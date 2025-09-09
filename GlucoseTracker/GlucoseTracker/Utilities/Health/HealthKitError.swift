//
//  HealthKitError.swift
//  GlucoseTracker
//
//  Created by taeni on 9/9/25.
//

import Foundation

enum HealthKitError: LocalizedError {
    case healthDataNotAvailable
    case authorizationFailed
    case authorizationDenied
    case dataReadFailed(String)
    case dataSaveFailed(String)
    case invalidData(String)
    case networkError(String)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .healthDataNotAvailable:
            return "HealthKit is not available on this device. This feature requires a device that supports HealthKit."
            
        case .authorizationFailed:
            return "HealthKit authorization request failed. Please check your device settings and try again."
            
        case .authorizationDenied:
            return "HealthKit access has been denied. Please enable HealthKit permissions in Settings to use this feature."
            
        case .dataReadFailed(let message):
            return "Failed to read health data: \(message)"
            
        case .dataSaveFailed(let message):
            return "Failed to save health data: \(message)"
            
        case .invalidData(let message):
            return "Invalid data provided: \(message)"
            
        case .networkError(let message):
            return "Network error occurred: \(message)"
            
        case .unknownError(let message):
            return "An unexpected error occurred: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .healthDataNotAvailable:
            return "This app requires a device with HealthKit support. Please use a compatible iPhone or iPad."
            
        case .authorizationFailed:
            return "Try restarting the app and granting permissions when prompted."
            
        case .authorizationDenied:
            return "Go to Settings → Privacy & Security → Health → GlucoseTracker and enable all permissions."
            
        case .dataReadFailed(_):
            return "Check your internet connection and try again. If the problem persists, restart the app."
            
        case .dataSaveFailed(_):
            return "Ensure you have sufficient storage space and try saving again."
            
        case .invalidData(_):
            return "Please check your input and ensure all values are valid."
            
        case .networkError(_):
            return "Check your internet connection and try again."
            
        case .unknownError(_):
            return "Please try again. If the problem persists, contact support."
        }
    }
    
    var errorCode: Int {
        switch self {
        case .healthDataNotAvailable:
            return 1001
        case .authorizationFailed:
            return 1002
        case .authorizationDenied:
            return 1003
        case .dataReadFailed(_):
            return 2001
        case .dataSaveFailed(_):
            return 2002
        case .invalidData(_):
            return 3001
        case .networkError(_):
            return 4001
        case .unknownError(_):
            return 9999
        }
    }
    
    var userFriendlyMessage: String {
        switch self {
        case .healthDataNotAvailable:
            return "HealthKit is not supported on this device."
            
        case .authorizationFailed, .authorizationDenied:
            return "Please enable HealthKit permissions in Settings to continue."
            
        case .dataReadFailed(_):
            return "Unable to load your health data. Please try again."
            
        case .dataSaveFailed(_):
            return "Unable to save your health data. Please try again."
            
        case .invalidData(_):
            return "Please check your input and try again."
            
        case .networkError(_):
            return "Please check your internet connection."
            
        case .unknownError(_):
            return "Something went wrong. Please try again."
        }
    }
    
    var suggestedActions: [String] {
        switch self {
        case .healthDataNotAvailable:
            return ["Use a compatible iPhone or iPad"]
            
        case .authorizationFailed, .authorizationDenied:
            return [
                "Open Settings",
                "Go to Privacy & Security → Health",
                "Select GlucoseTracker",
                "Enable all permissions"
            ]
            
        case .dataReadFailed(_):
            return ["Check internet connection", "Restart the app", "Try again"]
            
        case .dataSaveFailed(_):
            return ["Check available storage", "Restart the app", "Try again"]
            
        case .invalidData(_):
            return ["Check your input values", "Ensure all fields are filled correctly"]
            
        case .networkError(_):
            return ["Check internet connection", "Try again"]
            
        case .unknownError(_):
            return ["Restart the app", "Try again", "Contact support if problem persists"]
        }
    }
    
    static func from(_ error: Error) -> HealthKitError {
        if let healthKitError = error as? HealthKitError {
            return healthKitError
        }
        
        let nsError = error as NSError
        
        switch nsError.domain {
        case "NSURLErrorDomain":
            return .networkError(error.localizedDescription)
        default:
            return .unknownError(error.localizedDescription)
        }
    }
}
