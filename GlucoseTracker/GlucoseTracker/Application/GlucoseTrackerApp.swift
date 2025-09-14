//
//  GlucoseTrackerApp.swift
//  GlucoseTracker
//
//  Created by taeni on 9/2/25.
//

import SwiftUI

@main
struct GlucoseTrackerApp: App {
    @StateObject private var authManager = HealthKitAuthorizationManager()
    
    var body: some Scene {
        WindowGroup {
            Group {
                switch authManager.authorizationStatus {
                case .notDetermined:
                    PermissionRequestView()
                case .authorized:
                    ContentView()
                case .denied:
                    PermissionDeniedView()
                case .unavailable:
                    HealthKitUnavailableView()
                }
            }
            .environmentObject(authManager)
            .task {
                authManager.checkAuthorizationStatus()
                
                if authManager.needsAuthorization {
                    await authManager.requestAuthorization()
                }
            }
        }
    }
}
