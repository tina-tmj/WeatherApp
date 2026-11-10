//
//  DTOTests.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import XCTest
@testable import WeatherApp

private enum TestDateError: Error {
    case unavailable
}

final class DTOTests: XCTestCase {
    // MARK: - Geocoding

    func testGeocodingJSONDecodesMultipleLocations() throws {
        let dto = try decode(geocodingJSON, as: GeocodingResponseDTO.self)
        let locations = dto.toLocations()

        XCTAssertEqual(locations.count, 2)
        XCTAssertEqual(
            locations[0],
            Location(
                id: 1819729,
                name: "Hong Kong",
                country: "Hong Kong",
                admin1: "Central and Western",
                latitude: 22.3193,
                longitude: 114.1694,
                timezone: "Asia/Hong_Kong"
            )
        )
        XCTAssertEqual(locations[1].id, 2950159)
        XCTAssertEqual(locations[1].name, "Berlin")
        XCTAssertEqual(locations[1].country, "Germany")
        XCTAssertNil(locations[1].admin1)
        XCTAssertEqual(locations[1].timezone, "Europe/Berlin")
    }

    func testGeocodingEmptyResultsDecodeToNoLocations() throws {
        let missing = try decode("{}", as: GeocodingResponseDTO.self)
        let empty = try decode(#"{"results":[]}"#, as: GeocodingResponseDTO.self)
        let null = try decode(#"{"results":null}"#, as: GeocodingResponseDTO.self)

        XCTAssertEqual(missing.toLocations(), [])
        XCTAssertEqual(empty.toLocations(), [])
        XCTAssertEqual(null.toLocations(), [])
    }

    func testGeocodingSkipsResultsWithoutAUsableNameOrCountry() throws {
        let json = """
        {
          "results": [
            {
              "id": 1,
              "name": " ",
              "latitude": 1,
              "longitude": 2,
              "country": "Ocean"
            },
            {
              "id": 2,
              "name": "Valid",
              "latitude": 3,
              "longitude": 4
            },
            {
              "id": 3,
              "name": " Kept ",
              "latitude": 5,
              "longitude": 6,
              "country": " Country ",
              "admin1": "",
              "timezone": "  "
            }
        ]
        }
        """

        let locations = try decode(json, as: GeocodingResponseDTO.self).toLocations()

        XCTAssertEqual(locations.count, 1)
        XCTAssertEqual(locations[0].id, 3)
        XCTAssertEqual(locations[0].name, "Kept")
        XCTAssertEqual(locations[0].country, "Country")
        XCTAssertNil(locations[0].admin1)
        XCTAssertNil(locations[0].timezone)
    }

    func testMalformedGeocodingJSONThrows() {
        XCTAssertThrowsError(try decode(#"{"results":{}}"#, as: GeocodingResponseDTO.self))
    }

    // MARK: - Weather JSON

    func testWeatherJSONMapsSnakeCaseFields() throws {
        let dto = try decode(weatherJSON, as: WeatherResponseDTO.self)

        XCTAssertEqual(dto.timezone, "Asia/Hong_Kong")
        XCTAssertEqual(dto.utcOffsetSeconds, 28_800)
        XCTAssertEqual(dto.current?.temperature2m, 26.4)
        XCTAssertEqual(dto.current?.relativeHumidity2m, 72)
        XCTAssertEqual(dto.current?.apparentTemperature, 28.1)
        XCTAssertEqual(dto.current?.isDay, 1)
        XCTAssertEqual(dto.current?.precipitation, 0.2)
        XCTAssertEqual(dto.current?.weatherCode, 61)
        XCTAssertEqual(dto.current?.windSpeed10m, 15.6)
        XCTAssertEqual(dto.daily?.time, ["2026-11-09", "2026-11-10"])
        XCTAssertEqual(dto.daily?.weatherCode, [2, 80] as [Int?])
        XCTAssertEqual(dto.daily?.temperature2mMax, [30.2, 29] as [Double?])
        XCTAssertEqual(dto.daily?.temperature2mMin, [22.1, 21.4] as [Double?])
    }

    func testWeatherJSONConvertsToDomainModels() throws {
        let dto = try decode(weatherJSON, as: WeatherResponseDTO.self)
        let current = try XCTUnwrap(dto.toCurrentWeather())
        let forecasts = dto.toDailyForecasts()

        XCTAssertEqual(
            current,
            CurrentWeather(
                temperature: 26.4,
                apparentTemperature: 28.1,
                humidity: 72,
                windSpeed: 15.6,
                precipitation: 0.2,
                weatherCondition: .rain,
                isDay: true
            )
        )
        XCTAssertEqual(forecasts.count, 2)
        XCTAssertEqual(forecasts[0].weatherCondition, .partlyCloudy)
        XCTAssertEqual(forecasts[0].maxTemperature, 30.2)
        XCTAssertEqual(forecasts[0].minTemperature, 22.1)
        XCTAssertEqual(forecasts[1].weatherCondition, .rain)
        XCTAssertEqual(forecasts[0].year, 2026)
        XCTAssertEqual(forecasts[0].month, 11)
        XCTAssertEqual(forecasts[0].day, 9)
        XCTAssertEqual(forecasts[1].day, 10)
        XCTAssertEqual(forecasts[0].id, "2026-11-09")
        XCTAssertEqual(dto.forecastTimeZone().identifier, "Asia/Hong_Kong")
        XCTAssertEqual(
            forecasts[0].weekdayText(locale: Locale(identifier: "en_US"), timeZone: dto.forecastTimeZone()),
            "Mon"
        )
    }

    func testDailyDatesStayOnTheCalendarDayAcrossDaylightSaving() throws {
        let json = """
        {
          "timezone": "Europe/Berlin",
          "utc_offset_seconds": 3600,
          "daily": {
            "time": ["2026-03-28", "2026-03-29", "2026-03-30", "2026-07-01", "2026-10-25"],
            "weather_code": [0, 1, 2, 3, 45],
            "temperature_2m_max": [10, 11, 12, 24, 13],
            "temperature_2m_min": [2, 3, 4, 14, 5]
          }
        }
        """

        let dto = try decode(json, as: WeatherResponseDTO.self)
        let forecasts = dto.toDailyForecasts()
        let timeZone = dto.forecastTimeZone()

        XCTAssertEqual(timeZone.identifier, "Europe/Berlin")
        XCTAssertEqual(forecasts.map(\.id), [
            "2026-03-28", "2026-03-29", "2026-03-30", "2026-07-01", "2026-10-25"
        ])
        XCTAssertEqual(
            forecasts.map { $0.weekdayText(locale: Locale(identifier: "en_US"), timeZone: timeZone) },
            ["Sat", "Sun", "Mon", "Wed", "Sun"]
        )

        let summerEvening = try utcDate(year: 2026, month: 7, day: 1, hour: 22, minute: 30)
        XCTAssertFalse(forecasts[3].isSameDay(as: summerEvening, in: timeZone))
        XCTAssertEqual(forecasts[3].day, 1)
        let julySecond = DailyForecast(
            year: 2026, month: 7, day: 2,
            maxTemperature: 24, minTemperature: 14, weatherCondition: .clear
        )
        XCTAssertTrue(julySecond.isSameDay(as: summerEvening, in: timeZone))
        let winterOffset = try XCTUnwrap(TimeZone(secondsFromGMT: 3600))
        XCTAssertFalse(julySecond.isSameDay(as: summerEvening, in: winterOffset))
    }

    func testNewYorkTransitionDayDoesNotMove() throws {
        let json = """
        {
          "timezone": "America/New_York",
          "utc_offset_seconds": -18000,
          "daily": {
            "time": ["2026-03-07", "2026-03-08", "2026-03-09", "2026-11-01"],
            "weather_code": [0, 1, 2, 3],
            "temperature_2m_max": [8, 9, 10, 11],
            "temperature_2m_min": [0, 1, 2, 3]
          }
        }
        """

        let dto = try decode(json, as: WeatherResponseDTO.self)
        let forecasts = dto.toDailyForecasts()

        XCTAssertEqual(forecasts.map(\.id), ["2026-03-07", "2026-03-08", "2026-03-09", "2026-11-01"])
        XCTAssertEqual(
            forecasts.map {
                $0.weekdayText(locale: Locale(identifier: "en_US"), timeZone: dto.forecastTimeZone())
            },
            ["Sat", "Sun", "Mon", "Sun"]
        )
    }

    func testForecastTimeZoneIgnoresLocationAndTheDevice() throws {
        let json = """
        {
          "timezone": "Asia/Hong_Kong",
          "utc_offset_seconds": 28800,
          "daily": {
            "time": ["2026-11-09"],
            "weather_code": [1],
            "temperature_2m_max": [28],
            "temperature_2m_min": [22]
          }
        }
        """

        let dto = try decode(json, as: WeatherResponseDTO.self)
        let forecast = try XCTUnwrap(dto.toDailyForecasts().first)
        let losAngeles = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let absolute = try date(year: 2026, month: 11, day: 9, secondsFromGMT: 28_800)
        var phoneCalendar = Calendar(identifier: .gregorian)
        phoneCalendar.timeZone = losAngeles
        let shifted = phoneCalendar.dateComponents([.year, .month, .day], from: absolute)

        XCTAssertEqual(dto.forecastTimeZone().identifier, "Asia/Hong_Kong")
        XCTAssertEqual(forecast.id, "2026-11-09")
        XCTAssertEqual(shifted.day, 8)
        XCTAssertEqual(
            forecast.weekdayText(locale: Locale(identifier: "en_US"), timeZone: dto.forecastTimeZone()),
            "Mon"
        )
    }

    func testMissingTimezoneUsesTheFixedOffsetThenUTC() throws {
        let offsetOnly = """
        {
          "utc_offset_seconds": 28800,
          "daily": {
            "time": ["2026-11-09"],
            "weather_code": [1],
            "temperature_2m_max": [28],
            "temperature_2m_min": [22]
          }
        }
        """
        let neither = """
        {
          "daily": {
            "time": ["2026-02-31", "2026-11-09"],
            "weather_code": [0, 1],
            "temperature_2m_max": [1, 28],
            "temperature_2m_min": [0, 22]
          }
        }
        """

        let offsetDTO = try decode(offsetOnly, as: WeatherResponseDTO.self)
        let neitherDTO = try decode(neither, as: WeatherResponseDTO.self)

        XCTAssertEqual(offsetDTO.forecastTimeZone().secondsFromGMT(), 28_800)
        XCTAssertEqual(offsetDTO.toDailyForecasts().first?.id, "2026-11-09")
        XCTAssertEqual(neitherDTO.forecastTimeZone().secondsFromGMT(), 0)
        XCTAssertEqual(neitherDTO.toDailyForecasts().map(\.id), ["2026-11-09"])
    }

    // MARK: - Incomplete Weather Data

    func testIncompleteCurrentWeatherDoesNotProduceAModel() throws {
        let missingCurrent = try decode(
            #"{"timezone":"UTC","utc_offset_seconds":0}"#,
            as: WeatherResponseDTO.self
        )
        let missingField = try decode(
            """
            {
              "current": {
                "temperature_2m": 20,
                "relative_humidity_2m": 50,
                "apparent_temperature": 19,
                "is_day": 2,
                "precipitation": 0,
                "weather_code": 0,
                "wind_speed_10m": 3
              }
            }
            """,
            as: WeatherResponseDTO.self
        )
        let night = try decode(
            """
            {
              "current": {
                "temperature_2m": 18,
                "relative_humidity_2m": 80.4,
                "apparent_temperature": 17.2,
                "is_day": 0,
                "precipitation": 1.5,
                "weather_code": 100,
                "wind_speed_10m": 4
              }
            }
            """,
            as: WeatherResponseDTO.self
        )

        XCTAssertNil(missingCurrent.toCurrentWeather())
        XCTAssertNil(missingField.toCurrentWeather())
        XCTAssertEqual(
            night.toCurrentWeather(),
            CurrentWeather(
                temperature: 18,
                apparentTemperature: 17.2,
                humidity: 80,
                windSpeed: 4,
                precipitation: 1.5,
                weatherCondition: .unknown(code: 100),
                isDay: false
            )
        )
    }

    func testDailyArraysKeepIndexAlignmentAndSkipBrokenRows() throws {
        let json = """
        {
          "timezone": "UTC",
          "utc_offset_seconds": 0,
          "daily": {
            "time": ["not-a-date", "2026-11-10", "2026-11-11", "2026-11-12"],
            "weather_code": [0, 1, null, 3],
            "temperature_2m_max": [30, 29, 28],
            "temperature_2m_min": [20, 19, 18, 17]
          }
        }
        """

        let forecasts = try decode(json, as: WeatherResponseDTO.self).toDailyForecasts()

        XCTAssertEqual(forecasts.count, 1)
        XCTAssertEqual(forecasts[0].id, "2026-11-10")
        XCTAssertEqual(forecasts[0].weatherCondition, .mainlyClear)
        XCTAssertEqual(forecasts[0].maxTemperature, 29)
        XCTAssertEqual(forecasts[0].minTemperature, 19)
    }

    func testMissingDailySectionProducesNoForecasts() throws {
        let dto = try decode(#"{"timezone":"UTC"}"#, as: WeatherResponseDTO.self)

        XCTAssertEqual(dto.toDailyForecasts(), [])
    }

    func testMalformedWeatherJSONThrows() {
        XCTAssertThrowsError(try decode("{", as: WeatherResponseDTO.self))
    }

    // MARK: - Helpers

    private func decode<T: Decodable>(_ json: String, as type: T.Type) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    private func utcDate(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let components = DateComponents(
            calendar: calendar,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
        return try XCTUnwrap(calendar.date(from: components))
    }

    private func date(year: Int, month: Int, day: Int, secondsFromGMT: Int) throws -> Date {
        guard let timeZone = TimeZone(secondsFromGMT: secondsFromGMT) else {
            throw TestDateError.unavailable
        }
        return try date(in: timeZone, year: year, month: month, day: day)
    }

    private func date(in timeZone: TimeZone, year: Int, month: Int, day: Int) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
            throw TestDateError.unavailable
        }
        return date
    }

    private var geocodingJSON: String {
        """
        {
          "results": [
            {
              "id": 1819729,
              "name": "Hong Kong",
              "latitude": 22.3193,
              "longitude": 114.1694,
              "country": "Hong Kong",
              "admin1": "Central and Western",
              "timezone": "Asia/Hong_Kong"
            },
            {
              "id": 2950159,
              "name": "Berlin",
              "latitude": 52.52437,
              "longitude": 13.41053,
              "country": "Germany",
              "timezone": "Europe/Berlin"
            }
          ]
        }
        """
    }

    private var weatherJSON: String {
        """
        {
          "latitude": 22.3125,
          "longitude": 114.1875,
          "timezone": "Asia/Hong_Kong",
          "utc_offset_seconds": 28800,
          "current": {
            "temperature_2m": 26.4,
            "relative_humidity_2m": 72,
            "apparent_temperature": 28.1,
            "is_day": 1,
            "precipitation": 0.2,
            "weather_code": 61,
            "wind_speed_10m": 15.6
          },
          "daily": {
            "time": ["2026-11-09", "2026-11-10"],
            "weather_code": [2, 80],
            "temperature_2m_max": [30.2, 29],
            "temperature_2m_min": [22.1, 21.4]
          }
        }
        """
    }
}
