//
//  OpenMeteoWeatherRepository.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import Foundation

/// Open-Meteo Forecast API。MockWeatherRepository 仍然保留，給不需要網路的測試使用。
final class OpenMeteoWeatherRepository: WeatherRepositoryProtocol {
    private let client: APIClientProtocol

    init(client: APIClientProtocol = APIClient()) {
        self.client = client
    }

    func fetchWeather(for location: Location) async throws -> WeatherResult {
        try await fetchWeather(
            at: Coordinates(latitude: location.latitude, longitude: location.longitude)
        )
    }

    func fetchWeather(at coordinates: Coordinates) async throws -> WeatherResult {
        guard let baseURL = URL(string: "https://api.open-meteo.com") else {
            throw APIError.invalidURL
        }
        let dto: WeatherResponseDTO = try await client.request(
            ForecastEndpoint(baseURL: baseURL, coordinates: coordinates)
        )
        guard let currentWeather = dto.toCurrentWeather() else {
            throw APIError.decodingError(
                DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: [], debugDescription: "Missing current weather")
                )
            )
        }
        return WeatherResult(
            currentWeather: currentWeather,
            dailyForecasts: dto.toDailyForecasts(),
            timeZone: dto.forecastTimeZone()
        )
    }
}

private struct ForecastEndpoint: Endpoint {
    let baseURL: URL
    let coordinates: Coordinates

    var path: String { "v1/forecast" }

    var queryItems: [URLQueryItem] {
        [
            URLQueryItem(name: "latitude", value: Self.decimal(coordinates.latitude)),
            URLQueryItem(name: "longitude", value: Self.decimal(coordinates.longitude)),
            URLQueryItem(
                name: "current",
                value: "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m"
            ),
            URLQueryItem(
                name: "daily",
                value: "weather_code,temperature_2m_max,temperature_2m_min"
            ),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "7")
        ]
    }

    private static func decimal(_ value: Double) -> String {
        String(format: "%.6f", value)
    }
}
