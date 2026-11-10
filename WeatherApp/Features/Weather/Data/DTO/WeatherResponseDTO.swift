//
//  WeatherResponseDTO.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import Foundation

/// Open-Meteo Forecast API 的 JSON。欄位用 CodingKeys 對應 snake_case，不靠 decoder 自動轉換。
struct WeatherResponseDTO: Codable {
    let timezone: String?
    let utcOffsetSeconds: Int?
    let current: CurrentWeatherDTO?
    let daily: DailyWeatherDTO?

    enum CodingKeys: String, CodingKey {
        case timezone
        case utcOffsetSeconds = "utc_offset_seconds"
        case current
        case daily
    }

    // MARK: - Conversion

    /// 目前天氣缺任一必要欄位時回傳 nil，避免做出半套資料。
    func toCurrentWeather() -> CurrentWeather? {
        current?.toCurrentWeather()
    }

    /// 每日陣列按同一個 index 對齊。缺值或日期無法解析的那一列略過，後面的列不往前補。
    /// `yyyy-MM-dd` 直接保留成年、月、日，不先轉成某個時區下的絕對時間。
    func toDailyForecasts() -> [DailyForecast] {
        guard let daily else { return [] }

        let dates = daily.time ?? []
        let codes = daily.weatherCode ?? []
        let maxima = daily.temperature2mMax ?? []
        let minima = daily.temperature2mMin ?? []
        let count = [dates.count, codes.count, maxima.count, minima.count].min() ?? 0

        var forecasts: [DailyForecast] = []
        forecasts.reserveCapacity(count)

        for index in 0..<count {
            guard
                let weatherCode = codes[index],
                let maxTemperature = maxima[index],
                let minTemperature = minima[index],
                let day = WeatherDayParser.day(from: dates[index])
            else {
                continue
            }

            forecasts.append(
                DailyForecast(
                    year: day.year,
                    month: day.month,
                    day: day.day,
                    maxTemperature: maxTemperature,
                    minTemperature: minTemperature,
                    weatherCondition: WeatherCondition(weatherCode: weatherCode)
                )
            )
        }

        return forecasts
    }

    /// 預報地點的時區。IANA 名稱會跟著夏令時走；固定偏移只在沒有名稱時使用。不用手機時區。
    func forecastTimeZone() -> TimeZone {
        if let timezone, let timeZone = TimeZone(identifier: timezone) {
            return timeZone
        }
        if let utcOffsetSeconds, let timeZone = TimeZone(secondsFromGMT: utcOffsetSeconds) {
            return timeZone
        }
        return TimeZone(secondsFromGMT: 0) ?? TimeZone(identifier: "GMT")!
    }
}

struct CurrentWeatherDTO: Codable {
    let temperature2m: Double?
    let relativeHumidity2m: Double?
    let apparentTemperature: Double?
    let isDay: Int?
    let precipitation: Double?
    let weatherCode: Int?
    let windSpeed10m: Double?

    enum CodingKeys: String, CodingKey {
        case temperature2m = "temperature_2m"
        case relativeHumidity2m = "relative_humidity_2m"
        case apparentTemperature = "apparent_temperature"
        case isDay = "is_day"
        case precipitation
        case weatherCode = "weather_code"
        case windSpeed10m = "wind_speed_10m"
    }

    // MARK: - Conversion

    func toCurrentWeather() -> CurrentWeather? {
        guard
            let temperature2m,
            let relativeHumidity2m,
            let apparentTemperature,
            let isDay,
            let precipitation,
            let weatherCode,
            let windSpeed10m,
            isDay == 0 || isDay == 1
        else {
            return nil
        }

        return CurrentWeather(
            temperature: temperature2m,
            apparentTemperature: apparentTemperature,
            humidity: Int(relativeHumidity2m.rounded()),
            windSpeed: windSpeed10m,
            precipitation: precipitation,
            weatherCondition: WeatherCondition(weatherCode: weatherCode),
            isDay: isDay == 1
        )
    }
}

struct DailyWeatherDTO: Codable {
    let time: [String]?
    let weatherCode: [Int?]?
    let temperature2mMax: [Double?]?
    let temperature2mMin: [Double?]?

    enum CodingKeys: String, CodingKey {
        case time
        case weatherCode = "weather_code"
        case temperature2mMax = "temperature_2m_max"
        case temperature2mMin = "temperature_2m_min"
    }
}

private enum WeatherDayParser {
    /// 只接受 `yyyy-MM-dd`。用公曆核對這一天是否存在，核對時的時區不寫進結果。
    static func day(from value: String) -> (year: Int, month: Int, day: Int)? {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4,
              parts[1].count == 2,
              parts[2].count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone(identifier: "GMT")!
        let components = DateComponents(calendar: calendar, year: year, month: month, day: day)
        guard let date = calendar.date(from: components) else { return nil }
        let checked = calendar.dateComponents([.year, .month, .day], from: date)
        guard checked.year == year, checked.month == month, checked.day == day else { return nil }
        return (year, month, day)
    }
}
