//
//  OpenMeteoWeatherRepositoryTests.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import XCTest
@testable import WeatherApp

final class OpenMeteoWeatherRepositoryTests: XCTestCase {
    private let coordinates = Coordinates(latitude: 22.3193, longitude: 114.1694)

    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testCoordinateQueryMatchesTheRequestedLocation() async throws {
        let capture = RequestCapture()
        MockURLProtocol.handler = { request in
            capture.request = request
            return try Self.httpResponse(for: request, statusCode: 200, data: Self.weatherJSON)
        }
        let repository = OpenMeteoWeatherRepository(client: makeClient())

        _ = try await repository.fetchWeather(at: coordinates)

        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(capture.request?.url), resolvingAgainstBaseURL: false))
        let items = try XCTUnwrap(components.queryItems)
        XCTAssertEqual(components.path, "/v1/forecast")
        XCTAssertEqual(doubleValue("latitude", in: items), coordinates.latitude, accuracy: 0.000_001)
        XCTAssertEqual(doubleValue("longitude", in: items), coordinates.longitude, accuracy: 0.000_001)
        XCTAssertEqual(value("timezone", in: items), "auto")
        XCTAssertEqual(value("forecast_days", in: items), "7")
        XCTAssertEqual(
            value("current", in: items),
            "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m"
        )
    }

    func testSuccessfulResponseDecodesCurrentWeather() async throws {
        MockURLProtocol.handler = { request in
            try Self.httpResponse(for: request, statusCode: 200, data: Self.weatherJSON)
        }
        let repository = OpenMeteoWeatherRepository(client: makeClient())

        let result = try await repository.fetchWeather(at: coordinates)

        XCTAssertEqual(result.currentWeather.temperature, 26.4)
        XCTAssertEqual(result.currentWeather.apparentTemperature, 28.1)
        XCTAssertEqual(result.currentWeather.humidity, 72)
        XCTAssertEqual(result.currentWeather.weatherCondition, .partlyCloudy)
        XCTAssertEqual(result.dailyForecasts.count, 1)
        XCTAssertEqual(result.dailyForecasts[0].id, "2026-11-09")
        XCTAssertEqual(result.dailyForecasts[0].maxTemperature, 30.2)
        XCTAssertEqual(result.dailyForecasts[0].minTemperature, 22.1)
        XCTAssertEqual(result.timeZone.identifier, "Asia/Hong_Kong")
        XCTAssertEqual(
            result.dailyForecasts[0].weekdayText(locale: Locale(identifier: "en_US"), timeZone: result.timeZone),
            "Mon"
        )
    }

    func testSearchedCityKeepsTheAPIDateWhenLocationTimezoneIsMissing() async throws {
        MockURLProtocol.handler = { request in
            try Self.httpResponse(for: request, statusCode: 200, data: Self.weatherJSON)
        }
        let repository = OpenMeteoWeatherRepository(client: makeClient())
        let location = Location(
            id: 1,
            name: "Somewhere",
            country: "Ocean",
            admin1: nil,
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
            timezone: nil
        )

        let result = try await repository.fetchWeather(for: location)

        XCTAssertEqual(result.timeZone.identifier, "Asia/Hong_Kong")
        XCTAssertEqual(result.dailyForecasts.map(\.id), ["2026-11-09"])
        XCTAssertEqual(result.currentWeather.temperature, 26.4)
    }

    func testNetworkFailurePropagates() async throws {
        MockURLProtocol.handler = { _ in
            throw URLError(.cannotConnectToHost)
        }
        let repository = OpenMeteoWeatherRepository(client: makeClient())

        do {
            _ = try await repository.fetchWeather(at: coordinates)
            XCTFail("Expected transport error")
        } catch let APIError.transportError(underlying) {
            XCTAssertEqual((underlying as? URLError)?.code, .cannotConnectToHost)
        } catch {
            XCTFail("Expected transport error, got \(error)")
        }
    }

    private func makeClient() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        configuration.urlCache = nil
        return APIClient(session: URLSession(configuration: configuration))
    }

    private func value(_ name: String, in items: [URLQueryItem]) -> String? {
        items.first { $0.name == name }?.value
    }

    private func doubleValue(_ name: String, in items: [URLQueryItem]) -> Double {
        Double(value(name, in: items) ?? "") ?? .nan
    }

    private static func httpResponse(for request: URLRequest, statusCode: Int, data: Data) throws -> (URLResponse, Data) {
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil) else {
            throw URLError(.badURL)
        }
        return (response, data)
    }

    private static let weatherJSON = Data(
        """
        {
          "timezone": "Asia/Hong_Kong",
          "utc_offset_seconds": 28800,
          "current": {
            "temperature_2m": 26.4,
            "relative_humidity_2m": 72,
            "apparent_temperature": 28.1,
            "is_day": 1,
            "precipitation": 0.2,
            "weather_code": 2,
            "wind_speed_10m": 15.6
          },
          "daily": {
            "time": ["2026-11-09"],
            "weather_code": [2],
            "temperature_2m_max": [30.2],
            "temperature_2m_min": [22.1]
          }
        }
        """.utf8
    )
}

private final class RequestCapture: @unchecked Sendable {
    var request: URLRequest?
}
