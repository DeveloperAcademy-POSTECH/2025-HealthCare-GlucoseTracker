//
//  HomeView.swift
//  GlucoseTracker
//
//  Created by taeni on 9/9/25.
//

import SwiftUI
import HealthKit

struct HomeView: View {
    @EnvironmentObject private var authManager: HealthKitAuthorizationManager
    
    // 혈당 기록 상태
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    @State private var bloodGlucose: String = ""
    @State private var mealTime: HKBloodGlucoseMealTime? = .preprandial
    @State private var isSaving = false
    @State private var showSavedAlert = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @FocusState private var bgFieldFocused: Bool
    
    // 개인정보 처리 방침
    @State private var showWebView = false
    // Support 링크 이동
    @State private var showSupport = false
    // Diabetes Association
    @State private var showDiabetes = false
    
    // 시간대별 인사말
    @State private var currentGreeting = TimeBasedGreeting.current()
    
    private let healthKitManager: HealthKitManagerProtocol
    
    init(healthKitManager: HealthKitManagerProtocol = HealthKitManager.shared) {
        self.healthKitManager = healthKitManager
    }
    
    // 계산 속성
    private var glucoseDouble: Double? { Double(bloodGlucose) }
    
    private var isValidInput: Bool {
        guard let value = glucoseDouble else { return false }
        return value > 0 && value <= 500
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    greetingCard
                    recordCard
                    
                    Button(action: { Task { await saveRecordToHealth() } }) {
                        Label("Record", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundStyle(.white)
                            .background(isSaving ? Color.gray : Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.horizontal)
                    .disabled(isSaving || !isValidInput)
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showWebView = true }) {
                        Image(systemName: "doc.text")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSupport = true }) {
                        Image(systemName: "questionmark.circle")
                    }
                }
                
            }
            .navigationTitle("Home")
            .onAppear {
                updateGreeting()
                updateRecommendedMealTime()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                updateGreeting()
                updateRecommendedMealTime()
            }
        }
        .alert("Saved", isPresented: $showSavedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your blood glucose record has been saved to Health.")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
        .fullScreenCover(isPresented: $showWebView) {
            SafariView(url: URLConstants.privacyURL)
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showSupport) {
            SafariView(url: URLConstants.supportURL)
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showDiabetes) {
            SafariView(url: URLConstants.glucoseDiabetesURL)
                .ignoresSafeArea()
        }
    }
    
    private var greetingCard: some View {
        VStack(spacing: 12) {
            Image(systemName: currentGreeting.icon)
                .font(.system(size: 40))
                .foregroundColor(currentGreeting.iconColor)
                .padding(.bottom, 8)
            
            Text(currentGreeting.greeting)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(currentGreeting.title)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text(currentGreeting.message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private var recordCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("RECORD BLOOD GLUCOSE")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Date")
                        .fontWeight(.medium)
                    Spacer()
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }
                
                Divider()
                
                HStack {
                    Text("Time")
                        .fontWeight(.medium)
                    Spacer()
                    DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }
                
                Divider()
                
                HStack(spacing: 8) {
                    Text("Blood Glucose")
                        .fontWeight(.medium)
                    Spacer()
                    
                    TextField("Enter value", text: $bloodGlucose)
                        .keyboardType(.decimalPad)
                        .focused($bgFieldFocused)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: bloodGlucose) { _, newValue in
                            let filtered = newValue.filter { $0.isNumber || $0 == "." }
                            let components = filtered.components(separatedBy: ".")
                            
                            if components.count > 2 {
                                bloodGlucose = components.prefix(2).joined(separator: ".")
                            } else {
                                bloodGlucose = filtered
                            }
                        }
                    
                    Text("mg/dL")
                        .foregroundColor(.secondary)
                    
                    if let value = glucoseDouble {
                        let status = mealTime.getGlucoseStatus(for: value)
                        Image(systemName: status.systemImageName)
                            .foregroundColor(status.color)
                    }
                }
                
                Divider()
                
                HStack {
                    Text("Meal Time")
                        .fontWeight(.medium)
                    Spacer()
                    
                    Picker("Meal Time", selection: $mealTime) {
                        Text("Before Meal (Fasting)").tag(HKBloodGlucoseMealTime?.some(.preprandial))
                        Text("After Meal").tag(HKBloodGlucoseMealTime?.some(.postprandial))
                        Text("Other").tag(HKBloodGlucoseMealTime?.none)
                    }
                    .pickerStyle(.menu)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Target Range for \(mealTime.displayName):")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Text("\(Int(mealTime.normalRange.lowerBound))–\(Int(mealTime.normalRange.upperBound)) mg/dL")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button {
                    showDiabetes = true
                } label: {
                    Text("(American Diabetes Association)")
                        .font(.caption)
                        .bold()
                        .underline(true, color: .blue)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func updateGreeting() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentGreeting = TimeBasedGreeting.current()
        }
    }
    
    private func updateRecommendedMealTime() {
        let currentPeriod = TimePeriod.current()
        if let recommendedMealTime = currentPeriod.recommendedMealTime {
            mealTime = recommendedMealTime
        }
    }
    
    private func saveRecordToHealth() async {
        guard let value = glucoseDouble, value > 0, value <= 500 else {
            showError("Please enter a valid blood glucose value (1-500 mg/dL)")
            bgFieldFocused = true
            return
        }
        
        let combinedDateTime = combine(datePart: selectedDate, timePart: selectedTime)
        isSaving = true
        
        do {
            let unit = HKUnit.gramUnit(with: .milli).unitDivided(by: HKUnit.liter())
            let quantity = HKQuantity(unit: unit, doubleValue: value)
            
            var metadata: [String: Any] = [
                HKMetadataKeyWasUserEntered: true
            ]
            
            if let mealTime = mealTime {
                metadata[HKMetadataKeyBloodGlucoseMealTime] = mealTime.rawValue
            }
            
            guard let bloodGlucoseType = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) else {
                showError("Failed to create blood glucose type")
                isSaving = false
                return
            }
            
            let sample = HKQuantitySample(
                type: bloodGlucoseType,
                quantity: quantity,
                start: combinedDateTime,
                end: combinedDateTime,
                metadata: metadata
            )
            
            let healthStore = HKHealthStore()
            try await healthStore.save(sample)
            
            showSavedAlert = true
            bloodGlucose = ""
            selectedTime = Date()
            
        } catch {
            showError("Failed to save reading: \(error.localizedDescription)")
        }
        
        isSaving = false
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
    }
    
    private func combine(datePart: Date, timePart: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: datePart)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: timePart)
        
        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        combined.second = timeComponents.second
        
        return calendar.date(from: combined) ?? datePart
    }
}

#Preview {
    HomeView()
}
