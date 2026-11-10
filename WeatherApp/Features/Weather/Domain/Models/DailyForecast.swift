//
//  DailyForecast.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import Foundation

/// 某一天的預報。日期是預報地點的日曆日，直接來自 `daily.time` 的 `yyyy-MM-dd`。
/// 不把這一天換成絕對時間，避免再用另一個時區格式化時把日期提前或延後。
struct DailyForecast: Identifiable, Equatable, Sendable {
    var id: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    let year: Int
    let month: Int
    let day: Int
    let maxTemperature: Double
    let minTemperature: Double
    let weatherCondition: WeatherCondition

    /// 「今天」用預報地點的日曆，不用手機時區。
    func isSameDay(as instant: Date, in timeZone: TimeZone) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: instant)
        return parts.year == year && parts.month == month && parts.day == day
    }

    /// 星期由這一天的年、月、日在同一個預報時區裡算出。中午避開夏令時切換的空檔。
    func weekdayText(locale: Locale, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        guard let date = calendar.date(from: components) else { return id }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter.string(from: date)
    }
}
