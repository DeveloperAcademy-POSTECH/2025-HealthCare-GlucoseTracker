//
//  HealthKitAuthorizationManager.swift
//  GlucoseTracker
//
//  Created by taeni on 9/9/25.
//

import HealthKit
import SwiftUI

@MainActor
class HealthKitAuthorizationManager: ObservableObject {
    @Published var authorizationStatus: HealthKitAuthorizationStatus = .notDetermined
    @Published var showingPermissionAlert = false
    @Published var showingSettingsAlert = false
    
    private let healthKitManager: HealthKitManagerProtocol
    
    var isAuthorized: Bool {
        authorizationStatus == .authorized
    }
    
    var needsAuthorization: Bool {
        authorizationStatus == .notDetermined
    }
    
    var isDenied: Bool {
        authorizationStatus == .denied
    }
    
    init(healthKitManager: HealthKitManagerProtocol = HealthKitManager.shared) {
        self.healthKitManager = healthKitManager
    }
    
    func checkAuthorizationStatus() {
        let status = healthKitManager.getAuthorizationStatus()
        authorizationStatus = HealthKitAuthorizationStatus(from: status)
    }
    
    func requestAuthorization() async {
        do {
            let granted = try await healthKitManager.requestAuthorization()
            
            checkAuthorizationStatus()
            
            if !granted {
                showingPermissionAlert = true
            }
            
        } catch {
            if case HealthKitError.healthDataNotAvailable = error {
                authorizationStatus = .unavailable
            } else {
                showingPermissionAlert = true
            }
        }
    }
    
    func showSettingsAlert() {
        showingSettingsAlert = true
    }
}


struct HealthKitAuthorizationModifier: ViewModifier {
    @StateObject private var authManager = HealthKitAuthorizationManager()
    let onAuthorized: () -> Void
    
    func body(content: Content) -> some View {
        content
            .environmentObject(authManager)
            .task {
                authManager.checkAuthorizationStatus()
                
                if authManager.isAuthorized {
                    onAuthorized()
                } else if authManager.needsAuthorization {
                    await authManager.requestAuthorization()
                    if authManager.isAuthorized {
                        onAuthorized()
                    }
                }
            }
            .alert(authManager.authorizationStatus.title, isPresented: $authManager.showingPermissionAlert) {
                Button("Grant Permission") {
                    Task {
                        await authManager.requestAuthorization()
                        if authManager.isAuthorized {
                            onAuthorized()
                        }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(authManager.authorizationStatus.message)
            }
    }
}

extension View {
    func requiresHealthKitAuthorization(onAuthorized: @escaping () -> Void) -> some View {
        modifier(HealthKitAuthorizationModifier(onAuthorized: onAuthorized))
    }
}

struct HealthKitAuthorizationView: View {
    @EnvironmentObject private var authManager: HealthKitAuthorizationManager
    let content: () -> AnyView
    
    var body: some View {
        Group {
            switch authManager.authorizationStatus {
            case .notDetermined:
                PermissionRequestView()
            case .authorized:
                content()
            case .denied:
                PermissionDeniedView()
            case .unavailable:
                HealthKitUnavailableView()
            }
        }
    }
}

struct PermissionRequestView: View {
    @EnvironmentObject private var authManager: HealthKitAuthorizationManager
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "heart.circle")
                .font(.system(size: 80))
                .foregroundColor(.red)
            
            VStack(spacing: 16) {
                Text("HealthKit Permission Required")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("This app needs access to HealthKit to read and write your blood glucose data securely.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                Button("Grant Permission") {
                    Task {
                        await authManager.requestAuthorization()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Text("Your health data will remain private and secure")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct PermissionDeniedView: View {
    @EnvironmentObject private var authManager: HealthKitAuthorizationManager
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 80))
                .foregroundColor(.orange)
            
            VStack(spacing: 16) {
                Text("HealthKit Access Denied")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("To use this app, please enable HealthKit access in your device settings.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                Button("Try Again") {
                    authManager.checkAuthorizationStatus()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding()
    }
}

struct HealthKitUnavailableView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "heart.slash")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            VStack(spacing: 16) {
                Text("HealthKit Unavailable")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("HealthKit is not available on this device. This app requires HealthKit to function properly.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

#Preview("Permission Request") {
    PermissionRequestView()
        .environmentObject(HealthKitAuthorizationManager())
}

#Preview("Permission Denied") {
    PermissionDeniedView()
        .environmentObject(HealthKitAuthorizationManager())
}

#Preview("HealthKit Unavailable") {
    HealthKitUnavailableView()
}
