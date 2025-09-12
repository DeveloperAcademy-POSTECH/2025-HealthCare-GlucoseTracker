//
//  HomeView.swift
//  GlucoseTracker
//
//  Created by taeni on 9/9/25.
//

import SwiftUI

struct HomeView: View {

    // 기존에 있던 웹뷰 상태 그대로 유지
    @State private var showWebView = false

//MARK: - 혈당 기록 상태
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    @State private var bloodGlucose: String = ""          // 처음은 빈칸이고 사용자가 입력
    @State private var mealTime: MealTime = .fasting       // 기본값 Fasting
    @State private var showSavedAlert = false
    @FocusState private var bgFieldFocused: Bool

    // 계산 속성
    private var glucoseInt: Int? { Int(bloodGlucose) }
    private var isFastingTargetOK: Bool {
        guard let v = glucoseInt else { return false }
        return (80...130).contains(v)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // 상단 고정 메시지 카드
                    greetingCard

                    // Record Blood Glucose 카드
                    recordCard

                    // Record 버튼
                    Button(action: saveRecord) {
                        Label("Record", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundStyle(.white)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationTitle("Home")
        }
// 저장 완료 알림
        .alert("Saved", isPresented: $showSavedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your blood glucose record has been saved.")
        }
        // 기존 개인정보정책 전체화면 웹뷰
        .fullScreenCover(isPresented: $showWebView) {
            SafariView(url: URLConstants.naverURL)
                .ignoresSafeArea()
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
                    .keyboardType(.numberPad)
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

// Meal Time
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

    private func saveRecord() {
        guard let value = glucoseInt else {
            bgFieldFocused = true
            return
        }
        let when = combine(datePart: selectedDate, timePart: selectedTime)
        let record = GlucoseRecord(date: when, glucose: value, mealTime: mealTime)
        GlucoseStore.shared.add(record)
        showSavedAlert = true
        bloodGlucose = "" // 입력값 초기화(선택)
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

// MARK: - Models & Store (같은 파일 맨 아래에 그대로 두는게 좋다고 함)

enum MealTime: String, CaseIterable, Codable {
    case fasting = "Fasting"
    case eating  = "Eating"
}

struct GlucoseRecord: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let glucose: Int
    let mealTime: MealTime
}

final class GlucoseStore {
    static let shared = GlucoseStore()
    private let key = "glucose_records_v1"

    private(set) var records: [GlucoseRecord] = []

    private init() {
        load()
    }

    func add(_ record: GlucoseRecord) {
        records.insert(record, at: 0)
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let arr = try? JSONDecoder().decode([GlucoseRecord].self, from: data) else { return }
        records = arr
    }
}


#Preview {
    HomeView()
}
