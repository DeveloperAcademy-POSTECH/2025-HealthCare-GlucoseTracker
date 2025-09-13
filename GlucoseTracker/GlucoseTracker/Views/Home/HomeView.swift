//
//  HomeView.swift
//  GlucoseTracker
//
//  Created by taeni on 9/9/25.
//

import SwiftUI
import HealthKit

struct HomeView: View {

    // 기존에 있던 웹뷰 상태 그대로 유지
    @State private var showWebView = false

// MARK: - HealthKit Manager
    @StateObject private var mockManager = MockHealthKitManager.shared
    @State private var isRequestingAuth = false
    @State private var isSaving = false
    @State private var errorAlertMessage: String?
    @State private var showErrorAlert = false

// MARK: - 혈당 기록 상태
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    @State private var bloodGlucose: String = ""          // 사용자가 입력 (mg/dL)
    @State private var mealTime: MealTime = .fasting      // 기본값 Fasting
    @State private var showSavedAlert = false
    @FocusState private var bgFieldFocused: Bool

    // 계산 속성
    private var glucoseDouble: Double? { Double(bloodGlucose) }
    private var isFastingTargetOK: Bool {
        guard let v = glucoseDouble else { return false }
        // 80~130 mg/dL
        return (80.0...130.0).contains(v)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // 상단 고정 메시지 카드
                    greetingCard

                    // 권한 상태/요청
                    authorizationCard

                    // Record Blood Glucose 카드
                    recordCard

                    // Record 버튼
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
                    .disabled(isSaving)
                }
                .padding()
            }
            .navigationTitle("Home")
        }
        // 저장 완료 알림
        .alert("Saved", isPresented: $showSavedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your blood glucose record has been saved to Health.")
        }
        // 오류 알림
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorAlertMessage ?? "Unknown error")
        }
        // 기존 개인정보정책 전체화면 웹뷰
        .fullScreenCover(isPresented: $showWebView) {
            SafariView(url: URLConstants.naverURL)
                .ignoresSafeArea()
        }
        .task {
            // 앱 진입 시 HealthKit 사용가능 여부 점검
            _ = mockManager.isHealthKitAvailable()
        }
    }

    // MARK: - Subviews

    private var greetingCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.text.square")
                .resizable()
                .frame(width: 80, height: 80)
                .padding(.bottom, 8)

            Text("Good Morning,\nLet's check fasting glucose level")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("Please remember to check your fasting blood sugar in the morning before eating or drinking anything. It's important for monitoring your health effectively.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var authorizationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Health Access", systemImage: "heart.fill")
                    .font(.headline)
                Spacer()
                Text(mockManager.isHealthKitAvailable() ? "Available" : "Unavailable")
                    .foregroundColor(mockManager.isHealthKitAvailable() ? .green : .red)
                    .font(.subheadline)
            }

            Text("Grant permission to save your blood glucose to the Health app.")
                .font(.caption)
                .foregroundColor(.secondary)

            Button {
                Task {
                    await requestAuthorization()
                }
            } label: {
                HStack {
                    if isRequestingAuth { ProgressView().scaleEffect(0.9) }
                    Text("Grant Authorization")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRequestingAuth)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var recordCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECORD BLOOD GLUCOSE")
                .font(.caption)
                .foregroundColor(.secondary)

            // Date
            HStack {
                Text("Date")
                Spacer()
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
            }
            Divider()

            // Time
            HStack {
                Text("Time")
                Spacer()
                DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.compact)
            }
            Divider()

            // Blood Glucose
            HStack(spacing: 8) {
                Text("Blood Glucose")
                Spacer()
                TextField("—", text: $bloodGlucose)
                    .keyboardType(.decimalPad)
                    .focused($bgFieldFocused)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("mg/dL")
                    .foregroundColor(.secondary)

                if isFastingTargetOK {
                    Image(systemName: "checkmark.circle.fill")
                        .imageScale(.medium)
                        .foregroundColor(.green)
                }
            }
            Divider()

            // Meal Time (UI 유지 — 현재 Mock 저장 API는 값/날짜만 받으므로 메타데이터 저장은 패스)
            HStack {
                Text("Meal Time")
                Spacer()
                Picker("Meal Time", selection: $mealTime) {
                    ForEach(MealTime.allCases, id: \.self) { mt in
                        Text(mt.rawValue).tag(mt)
                    }
                }
                .pickerStyle(.menu)
            }

            Text("Target fasting blood glucose: 80–130 mg/dL\n(American Diabetes Association)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Actions

    private func requestAuthorization() async {
        guard mockManager.isHealthKitAvailable() else {
            showError("HealthKit is not available on this device.")
            return
        }
        isRequestingAuth = true
        do {
            _ = try await mockManager.requestAuthorization()
        } catch {
            showError("Authorization failed: \(error.localizedDescription)")
        }
        isRequestingAuth = false
    }

    private func saveRecordToHealth() async {
        // 값 검증
        guard let value = glucoseDouble, value > 0, value <= 500 else {
            bgFieldFocused = true
            return
        }

        // 권한 없을 수 있으니 시도 전 한 번 요청(이미 허용이면 빠르게 통과)
        if mockManager.isHealthKitAvailable() {
            do {
                _ = try await mockManager.requestAuthorization()
            } catch {
                showError("Please grant Health access to save readings. \(error.localizedDescription)")
                return
            }
        } else {
            showError("HealthKit is not available on this device.")
            return
        }

        let when = combine(datePart: selectedDate, timePart: selectedTime)

        isSaving = true
        do {
            try await mockManager.addMockSample(value: value, date: when)
            showSavedAlert = true
            bloodGlucose = "" // 입력값 초기화(선택)
        } catch {
            showError("Failed to save to Health: \(error.localizedDescription)")
        }
        isSaving = false
    }

    private func showError(_ msg: String) {
        errorAlertMessage = msg
        showErrorAlert = true
    }

    private func combine(datePart: Date, timePart: Date) -> Date {
        let cal = Calendar.current
        let d = cal.dateComponents([.year, .month, .day], from: datePart)
        let t = cal.dateComponents([.hour, .minute, .second], from: timePart)
        var c = DateComponents()
        c.year = d.year; c.month = d.month; c.day = d.day
        c.hour = t.hour; c.minute = t.minute; c.second = t.second
        return cal.date(from: c) ?? datePart
    }
}

// MARK: - UI용 enum (UI는 유지, 저장은 HealthKit에 Double mg/dL로 기록)
enum MealTime: String, CaseIterable, Codable {
    case fasting = "Fasting"
    case eating  = "Eating"
}

#Preview {
    HomeView()
}
