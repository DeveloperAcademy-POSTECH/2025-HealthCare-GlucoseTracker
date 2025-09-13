//
//  CustomCalendarView.swift
//  GlucoseTracker
//
//  Created by taeni on 9/13/25.
//

import SwiftUI

// MARK: - Calendar Model

struct CalendarDay: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let hasData: Bool
    let isCurrentMonth: Bool
    let isToday: Bool
    let isSelected: Bool
}

struct CalendarMonth {
    let month: Int
    let year: Int
    let days: [CalendarDay]
    
    var displayName: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        let date = Calendar.current.date(from: DateComponents(year: year, month: month)) ?? Date()
        return dateFormatter.string(from: date)
    }
}

// MARK: - Calendar Data Source Protocol

protocol CalendarDataSource {
    func hasData(for date: Date) -> Bool
}

// MARK: - Custom Calendar View

struct CustomCalendarView: View {
    @Binding var selectedDate: Date
    let dataSource: CalendarDataSource?
    let onDateSelected: (Date) -> Void
    
    @State private var currentMonth: Date
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    init(selectedDate: Binding<Date>,
         dataSource: CalendarDataSource? = nil,
         onDateSelected: @escaping (Date) -> Void = { _ in }) {
        self._selectedDate = selectedDate
        self.dataSource = dataSource
        self.onDateSelected = onDateSelected
        self._currentMonth = State(initialValue: selectedDate.wrappedValue)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            headerView
            calendarGridView
        }
        .padding(.horizontal)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            Text(dateFormatter.string(from: currentMonth))
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            
            Button( action: goToToday) {
                Text("Today")
                    .foregroundColor(.accentColor)
            }
            
            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
        }
        .padding()
    }
    
    // MARK: - Calendar Grid View
    
    private var calendarGridView: some View {
        VStack {
            weekdayHeaderView
            calendarDaysView
        }
    }
    
    private var weekdayHeaderView: some View {
        HStack {
            ForEach(calendar.shortWeekdaySymbols, id: \.self) { weekday in
                Text(weekday)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
    }
    
    private var calendarDaysView: some View {
        let calendarMonth = generateCalendarMonth()
        let weeks = calendarMonth.days.chunked(into: 7)
        
        return VStack {
            ForEach(Array(weeks.enumerated()), id: \.offset) { weekIndex, week in
                HStack {
                    ForEach(week) { day in
                        CalendarDayView(
                            day: day,
                            onTap: { date in
                                selectedDate = date
                                onDateSelected(date)
                            }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Calendar Generation
    
    private func generateCalendarMonth() -> CalendarMonth {
        let startOfMonth = calendar.dateInterval(of: .month, for: currentMonth)?.start ?? currentMonth
        let endOfMonth = calendar.dateInterval(of: .month, for: currentMonth)?.end ?? currentMonth
        
        guard let monthRange = calendar.range(of: .day, in: .month, for: currentMonth) else {
            return CalendarMonth(month: 0, year: 0, days: [])
        }
        
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let leadingDays = firstWeekday - calendar.firstWeekday
        
        var days: [CalendarDay] = []
        
        // Add leading days from previous month
        for i in 0..<leadingDays {
            if let date = calendar.date(byAdding: .day, value: -(leadingDays - i), to: startOfMonth) {
                days.append(createCalendarDay(from: date, isCurrentMonth: false))
            }
        }
        
        // Add days of current month
        for day in monthRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(createCalendarDay(from: date, isCurrentMonth: true))
            }
        }
        
        // Add trailing days to complete the last week
        let totalCells = 42 // 6 weeks * 7 days
        let remainingCells = totalCells - days.count
        
        for i in 0..<remainingCells {
            if let date = calendar.date(byAdding: .day, value: i + 1, to: endOfMonth) {
                days.append(createCalendarDay(from: date, isCurrentMonth: false))
            }
        }
        
        let month = calendar.component(.month, from: currentMonth)
        let year = calendar.component(.year, from: currentMonth)
        
        return CalendarMonth(month: month, year: year, days: days)
    }
    
    private func createCalendarDay(from date: Date, isCurrentMonth: Bool) -> CalendarDay {
        let hasData = dataSource?.hasData(for: date) ?? false
        let isToday = calendar.isDateInToday(date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        
        return CalendarDay(
            date: date,
            hasData: hasData,
            isCurrentMonth: isCurrentMonth,
            isToday: isToday,
            isSelected: isSelected
        )
    }
    
    // MARK: - Navigation Actions
    
    private func previousMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        }
    }
    
    private func nextMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        }
    }
    
    private func goToToday() {
        let today = Date()
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = today
            selectedDate = today
        }
        onDateSelected(today)
    }
}

// MARK: - Calendar Day View

struct CalendarDayView: View {
    let day: CalendarDay
    let onTap: (Date) -> Void
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: day.date)
    }
    
    var body: some View {
        Button(action: { onTap(day.date) }) {
            ZStack {
                if day.hasData && day.isCurrentMonth {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 36, height: 36)
                }
                
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 36, height: 36)
                
                Text(dayNumber)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(textColor)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }
    
    private var backgroundColor: Color {
        if day.isSelected {
            return .accentColor
        } else if day.isToday && day.isCurrentMonth {
            return Color.accentColor.opacity(0.2)
        } else {
            return .clear
        }
    }
    
    private var textColor: Color {
        if day.isSelected {
            return .white
        } else if !day.isCurrentMonth {
            return .secondary
        } else if day.isToday {
            return .accentColor
        } else {
            return .primary
        }
    }
}

// MARK: - Array Extension for Chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

#Preview {
    struct PreviewCalendarDataSource: CalendarDataSource {
        func hasData(for date: Date) -> Bool {
            let calendar = Calendar.current
            let day = calendar.component(.day, from: date)
            return [1, 5, 10, 15, 20, 25].contains(day)
        }
    }
    
    @Previewable @State var selectedDate = Date()
    
    return CustomCalendarView(
        selectedDate: $selectedDate,
        dataSource: PreviewCalendarDataSource()
    )
    .padding()
}
