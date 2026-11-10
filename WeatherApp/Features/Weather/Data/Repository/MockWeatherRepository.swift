//
//  MockWeatherRepository.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

#if DEBUG
import Foundation

/// 固定的範例天氣，只給測試和不想打網路時使用。每個城市的數字都不一樣，方便確認畫面切換的是哪一城。
/// 整個檔案包在 `#if DEBUG`：正式版不編譯。
final class MockWeatherRepository: WeatherRepositoryProtocol {
    func fetchWeather(for location: Location) async throws -> WeatherResult {
        let sample = Self.samples[location.id] ?? Self.hongKongSample
        let timeZone = Self.timeZone(for: location.timezone)
        return WeatherResult(
            currentWeather: sample.current,
            dailyForecasts: Self.forecasts(sample.days, timeZone: timeZone),
            timeZone: timeZone
        )
    }

    func fetchWeather(at coordinates: Coordinates) async throws -> WeatherResult {
        let location = Location(
            id: Self.nearestCityID(to: coordinates),
            name: "",
            country: "",
            admin1: nil,
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
            timezone: nil
        )
        return try await fetchWeather(for: location)
    }

    private static func nearestCityID(to coordinates: Coordinates) -> Int {
        let nearest = MockGeocodingRepository.locations.min { lhs, rhs in
            distance(from: coordinates, to: lhs) < distance(from: coordinates, to: rhs)
        }
        return nearest?.id ?? MockGeocodingRepository.hongKong.id
    }

    private static func distance(from coordinates: Coordinates, to location: Location) -> Double {
        let latitude = coordinates.latitude - location.latitude
        let longitude = coordinates.longitude - location.longitude
        return latitude * latitude + longitude * longitude
    }

    private struct DaySample {
        let maxTemperature: Double
        let minTemperature: Double
        let condition: WeatherCondition
    }

    private struct CitySample {
        let current: CurrentWeather
        let days: [DaySample]
    }

    private static let hongKongSample = CitySample(
        current: CurrentWeather(
            temperature: 26,
            apparentTemperature: 28,
            humidity: 72,
            windSpeed: 15,
            precipitation: 0.2,
            weatherCondition: .partlyCloudy,
            isDay: true
        ),
        days: [
            DaySample(maxTemperature: 28, minTemperature: 23, condition: .partlyCloudy),
            DaySample(maxTemperature: 29, minTemperature: 24, condition: .clear),
            DaySample(maxTemperature: 27, minTemperature: 23, condition: .rain),
            DaySample(maxTemperature: 26, minTemperature: 22, condition: .drizzle),
            DaySample(maxTemperature: 28, minTemperature: 23, condition: .mainlyClear),
            DaySample(maxTemperature: 30, minTemperature: 24, condition: .overcast),
            DaySample(maxTemperature: 27, minTemperature: 22, condition: .thunderstorm)
        ]
    )

    private static let samples: [Int: CitySample] = [
        MockGeocodingRepository.hongKong.id: hongKongSample,
        MockGeocodingRepository.shenzhen.id: CitySample(
            current: CurrentWeather(
                temperature: 24,
                apparentTemperature: 26,
                humidity: 80,
                windSpeed: 12,
                precipitation: 4.5,
                weatherCondition: .rain,
                isDay: true
            ),
            days: [
                DaySample(maxTemperature: 25, minTemperature: 22, condition: .rain),
                DaySample(maxTemperature: 26, minTemperature: 22, condition: .drizzle),
                DaySample(maxTemperature: 28, minTemperature: 23, condition: .partlyCloudy),
                DaySample(maxTemperature: 29, minTemperature: 24, condition: .mainlyClear),
                DaySample(maxTemperature: 30, minTemperature: 25, condition: .clear),
                DaySample(maxTemperature: 29, minTemperature: 24, condition: .overcast),
                DaySample(maxTemperature: 27, minTemperature: 23, condition: .rain)
            ]
        ),
        MockGeocodingRepository.shanghai.id: CitySample(
            current: CurrentWeather(
                temperature: 18,
                apparentTemperature: 17,
                humidity: 64,
                windSpeed: 18,
                precipitation: 0,
                weatherCondition: .overcast,
                isDay: true
            ),
            days: [
                DaySample(maxTemperature: 19, minTemperature: 14, condition: .overcast),
                DaySample(maxTemperature: 20, minTemperature: 15, condition: .partlyCloudy),
                DaySample(maxTemperature: 21, minTemperature: 15, condition: .mainlyClear),
                DaySample(maxTemperature: 18, minTemperature: 13, condition: .rain),
                DaySample(maxTemperature: 17, minTemperature: 12, condition: .drizzle),
                DaySample(maxTemperature: 19, minTemperature: 13, condition: .fog),
                DaySample(maxTemperature: 22, minTemperature: 14, condition: .clear)
            ]
        ),
        MockGeocodingRepository.tokyo.id: CitySample(
            current: CurrentWeather(
                temperature: 16,
                apparentTemperature: 15,
                humidity: 58,
                windSpeed: 9,
                precipitation: 0,
                weatherCondition: .clear,
                isDay: true
            ),
            days: [
                DaySample(maxTemperature: 18, minTemperature: 11, condition: .clear),
                DaySample(maxTemperature: 19, minTemperature: 12, condition: .mainlyClear),
                DaySample(maxTemperature: 17, minTemperature: 12, condition: .partlyCloudy),
                DaySample(maxTemperature: 16, minTemperature: 11, condition: .overcast),
                DaySample(maxTemperature: 15, minTemperature: 10, condition: .rain),
                DaySample(maxTemperature: 17, minTemperature: 11, condition: .partlyCloudy),
                DaySample(maxTemperature: 20, minTemperature: 12, condition: .clear)
            ]
        ),
        MockGeocodingRepository.newYork.id: CitySample(
            current: CurrentWeather(
                temperature: 4,
                apparentTemperature: 1,
                humidity: 55,
                windSpeed: 22,
                precipitation: 1.2,
                weatherCondition: .snow,
                isDay: true
            ),
            days: [
                DaySample(maxTemperature: 5, minTemperature: -1, condition: .snow),
                DaySample(maxTemperature: 3, minTemperature: -2, condition: .overcast),
                DaySample(maxTemperature: 6, minTemperature: 0, condition: .partlyCloudy),
                DaySample(maxTemperature: 8, minTemperature: 1, condition: .mainlyClear),
                DaySample(maxTemperature: 7, minTemperature: 2, condition: .rain),
                DaySample(maxTemperature: 4, minTemperature: -1, condition: .snow),
                DaySample(maxTemperature: 2, minTemperature: -3, condition: .clear)
            ]
        )
    ]

    private static func forecasts(_ days: [DaySample], timeZone: TimeZone) -> [DailyForecast] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let startOfToday = calendar.startOfDay(for: Date())

        return days.enumerated().compactMap { offset, day in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startOfToday) else {
                return nil
            }
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            guard let year = parts.year, let month = parts.month, let dayNumber = parts.day else {
                return nil
            }
            return DailyForecast(
                year: year,
                month: month,
                day: dayNumber,
                maxTemperature: day.maxTemperature,
                minTemperature: day.minTemperature,
                weatherCondition: day.condition
            )
        }
    }

    /// 範例資料沒有 API 時區時用 UTC，不用手機時區。
    private static func timeZone(for identifier: String?) -> TimeZone {
        if let identifier, let timeZone = TimeZone(identifier: identifier) {
            return timeZone
        }
        return TimeZone(secondsFromGMT: 0) ?? TimeZone(identifier: "GMT")!
    }
}
#endif
