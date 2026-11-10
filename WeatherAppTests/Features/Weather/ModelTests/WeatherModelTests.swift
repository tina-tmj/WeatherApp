//
//  WeatherModelTests.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import XCTest
@testable import WeatherApp

final class WeatherModelTests: XCTestCase {
    // MARK: - Location

    func testLocationUsesGeocodingIdentifier() {
        let location = Location(
            id: 1819729,
            name: "Hong Kong",
            country: "Hong Kong",
            admin1: "Central and Western",
            latitude: 22.3193,
            longitude: 114.1694,
            timezone: "Asia/Hong_Kong"
        )

        XCTAssertEqual(location.id, 1819729)
        XCTAssertEqual(location.name, "Hong Kong")
        XCTAssertEqual(location.country, "Hong Kong")
        XCTAssertEqual(location.admin1, "Central and Western")
        XCTAssertEqual(location.latitude, 22.3193)
        XCTAssertEqual(location.longitude, 114.1694)
        XCTAssertEqual(location.timezone, "Asia/Hong_Kong")
    }

    func testLocationsWithTheSameNameStayDistinct() {
        let springfieldIllinois = Location(
            id: 4250542,
            name: "Springfield",
            country: "United States",
            admin1: "Illinois",
            latitude: 39.8017,
            longitude: -89.6436,
            timezone: "America/Chicago"
        )
        let springfieldMissouri = Location(
            id: 4409896,
            name: "Springfield",
            country: "United States",
            admin1: "Missouri",
            latitude: 37.2153,
            longitude: -93.2982,
            timezone: "America/Chicago"
        )

        XCTAssertEqual(springfieldIllinois.name, springfieldMissouri.name)
        XCTAssertNotEqual(springfieldIllinois.id, springfieldMissouri.id)
        XCTAssertNotEqual(springfieldIllinois, springfieldMissouri)
    }

    func testLocationAllowsMissingOptionalFields() {
        let location = Location(
            id: 1,
            name: "Atlantis",
            country: "Ocean",
            admin1: nil,
            latitude: 0,
            longitude: 0,
            timezone: nil
        )

        XCTAssertNil(location.admin1)
        XCTAssertNil(location.timezone)
    }

    // MARK: - Current Weather

    func testCurrentWeatherStoresBusinessFields() {
        let weather = CurrentWeather(
            temperature: 26.4,
            apparentTemperature: 28.1,
            humidity: 72,
            windSpeed: 15.6,
            precipitation: 0.2,
            weatherCondition: .rain,
            isDay: true
        )

        XCTAssertEqual(weather.temperature, 26.4)
        XCTAssertEqual(weather.apparentTemperature, 28.1)
        XCTAssertEqual(weather.humidity, 72)
        XCTAssertEqual(weather.windSpeed, 15.6)
        XCTAssertEqual(weather.precipitation, 0.2)
        XCTAssertEqual(weather.weatherCondition, .rain)
        XCTAssertTrue(weather.isDay)
        XCTAssertEqual(weather, weather)
    }

    // MARK: - Daily Forecast

    func testDailyForecastUsesCivilDateAsIdentity() {
        let forecast = DailyForecast(
            year: 2026,
            month: 11,
            day: 9,
            maxTemperature: 30.2,
            minTemperature: 22.1,
            weatherCondition: .partlyCloudy
        )

        XCTAssertEqual(forecast.id, "2026-11-09")
        XCTAssertEqual(forecast.maxTemperature, 30.2)
        XCTAssertEqual(forecast.minTemperature, 22.1)
        XCTAssertEqual(forecast.weatherCondition, .partlyCloudy)
    }

    func testTodayFollowsTheForecastTimeZoneRatherThanThePhone() throws {
        let now = try utcDate(year: 2026, month: 11, day: 9, hour: 20)
        let forecast = DailyForecast(
            year: 2026,
            month: 11,
            day: 10,
            maxTemperature: 29,
            minTemperature: 21,
            weatherCondition: .clear
        )
        let hongKong = try XCTUnwrap(TimeZone(identifier: "Asia/Hong_Kong"))
        let losAngeles = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))

        XCTAssertTrue(forecast.isSameDay(as: now, in: hongKong))
        XCTAssertFalse(forecast.isSameDay(as: now, in: losAngeles))
        XCTAssertEqual(
            forecast.weekdayText(locale: Locale(identifier: "en_US"), timeZone: hongKong),
            "Tue"
        )
        XCTAssertEqual(
            forecast.weekdayText(locale: Locale(identifier: "en_US"), timeZone: losAngeles),
            "Tue"
        )
    }

    // MARK: - Weather Condition

    func testWeatherCodeMapping() {
        let expectations: [(Int, WeatherCondition)] = [
            (0, .clear),
            (1, .mainlyClear),
            (2, .partlyCloudy),
            (3, .overcast),
            (45, .fog),
            (48, .fog),
            (51, .drizzle),
            (53, .drizzle),
            (55, .drizzle),
            (56, .drizzle),
            (57, .drizzle),
            (61, .rain),
            (63, .rain),
            (65, .rain),
            (66, .rain),
            (67, .rain),
            (80, .rain),
            (81, .rain),
            (82, .rain),
            (71, .snow),
            (73, .snow),
            (75, .snow),
            (77, .snow),
            (85, .snow),
            (86, .snow),
            (95, .thunderstorm),
            (96, .thunderstorm),
            (97, .thunderstorm),
            (99, .thunderstorm)
        ]

        for (code, expected) in expectations {
            XCTAssertEqual(WeatherCondition(weatherCode: code), expected, "weather code \(code)")
        }
    }

    func testUnknownWeatherCodeKeepsTheOriginalCode() {
        let condition = WeatherCondition(weatherCode: 123)

        XCTAssertEqual(condition, .unknown(code: 123))
        XCTAssertNotEqual(condition, .unknown(code: 124))
        XCTAssertEqual(L10n.condition(condition, locale: Locale(identifier: "en_US")), "Unknown")
        XCTAssertEqual(L10n.condition(condition, locale: Locale(identifier: "zh_CN")), "未知")
        XCTAssertEqual(condition.symbolName, "questionmark")
    }

    func testKnownConditionExposesDisplayNameAndSymbolName() {
        let condition = WeatherCondition(weatherCode: 0)

        XCTAssertEqual(L10n.condition(condition, locale: Locale(identifier: "en_US")), "Clear")
        XCTAssertEqual(L10n.condition(condition, locale: Locale(identifier: "zh_TW")), "晴")
        XCTAssertEqual(condition.symbolName, "sun.max")
    }

    // MARK: - Repository Protocols

    func testOpenMeteoLanguageFollowsThePreferredLanguage() {
        XCTAssertEqual(SystemLanguage.openMeteoCode(preferredLanguages: ["en-US"]), "en")
        XCTAssertEqual(SystemLanguage.openMeteoCode(preferredLanguages: ["zh-Hans-CN"]), "zh")
        XCTAssertEqual(SystemLanguage.openMeteoCode(preferredLanguages: ["zh-Hant-TW"]), "zh_tw")
    }

    func testRepositoryProtocolsExposeDomainModels() async throws {
        let location = Location(
            id: 1819729,
            name: "Hong Kong",
            country: "Hong Kong",
            admin1: nil,
            latitude: 22.3193,
            longitude: 114.1694,
            timezone: "Asia/Hong_Kong"
        )
        let geocoding = StaticGeocodingRepository(locations: [location])
        let weather = StaticWeatherRepository(
            result: WeatherResult(
                currentWeather: CurrentWeather(
                    temperature: 26,
                    apparentTemperature: 27,
                    humidity: 70,
                    windSpeed: 10,
                    precipitation: 0,
                    weatherCondition: .clear,
                    isDay: true
                ),
                dailyForecasts: [],
                timeZone: TimeZone(secondsFromGMT: 0)!
            )
        )

        let locations = try await geocoding.searchLocations(query: "Hong Kong")
        let result = try await weather.fetchWeather(for: location)

        XCTAssertEqual(locations.map(\.id), [1819729])
        XCTAssertEqual(result.currentWeather.temperature, 26)
        XCTAssertTrue(result.dailyForecasts.isEmpty)
    }
}

private func utcDate(year: Int, month: Int, day: Int, hour: Int) throws -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
    let components = DateComponents(calendar: calendar, year: year, month: month, day: day, hour: hour)
    return try XCTUnwrap(calendar.date(from: components))
}

private struct StaticGeocodingRepository: GeocodingRepositoryProtocol {
    let locations: [Location]

    func searchLocations(query: String) async throws -> [Location] {
        locations
    }
}

private struct StaticWeatherRepository: WeatherRepositoryProtocol {
    let result: WeatherResult

    func fetchWeather(for location: Location) async throws -> WeatherResult {
        result
    }

    func fetchWeather(at coordinates: Coordinates) async throws -> WeatherResult {
        result
    }
}
