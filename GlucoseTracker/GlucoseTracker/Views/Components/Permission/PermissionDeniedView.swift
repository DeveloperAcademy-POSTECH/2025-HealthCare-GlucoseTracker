//
//  PermissionDeniedView.swift
//  GlucoseTracker
//
//  Created by taeni on 9/14/25.
//

import SwiftUI

struct PermissionDeniedView: View {
    @EnvironmentObject private var authManager: HealthKitAuthorizationManager
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "heart.slash")
                    .font(.system(size: 80))
                    .foregroundColor(.red)
                
                Text("Health Access Required")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("GlucoseTracker needs access to your Health data to read and write blood glucose information.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(alignment: .leading, spacing: 20) {
                Text("To enable Health access:")
                    .font(.headline)
                    .fontWeight(.bold)
                
                VStack(spacing: 16) {
                    instructionStep(
                        number: "1",
                        icon: "heart.fill",
                        title: "Open Health App",
                        description: "Find and tap the Health app on your home screen"
                    )
                    
                    instructionStep(
                        number: "2",
                        icon: "square.and.arrow.up",
                        title: "Go to Sharing",
                        description: "Tap 'Sharing' tab at the bottom of the screen"
                    )
                    
                    instructionStep(
                        number: "3",
                        icon: "app.badge",
                        title: "Find GlucoseTracker",
                        description: "Look for 'GlucoseTracker' in the Apps section"
                    )
                    
                    instructionStep(
                        number: "4",
                        icon: "checkmark.circle",
                        title: "Enable Blood Glucose",
                        description: "Turn on both 'Read Data' and 'Write Data' for Blood Glucose"
                    )
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            Button("Check Again") {
                authManager.checkAuthorizationStatus()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            
            Spacer()
        }
        .padding()
    }
    
    private func instructionStep(number: String, icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 28, height: 28)
                
                Text(number)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}
