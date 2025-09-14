//
//  PermissionRequestView.swift
//  GlucoseTracker
//
//  Created by taeni on 9/14/25.
//

import SwiftUI

struct PermissionRequestView: View {
    @EnvironmentObject private var authManager: HealthKitAuthorizationManager
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 80))
                    .foregroundColor(.red)
                
                Text("Welcome to GlucoseTracker")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Track your blood glucose levels and sync with the Health app for comprehensive health monitoring.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 16) {
                Button("Allow Health Access") {
                    Task {
                        await authManager.requestAuthorization()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                
                Text("We need access to read and write blood glucose data to the Health app. Your data remains private and secure.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding()
    }
}
