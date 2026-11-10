//
//  OpenMeteoGeocodingRepository.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import Foundation

/// Open-Meteo Geocoding API。MockGeocodingRepository 仍然保留。
final class OpenMeteoGeocodingRepository: GeocodingRepositoryProtocol {
    private let client: APIClientProtocol

    init(client: APIClientProtocol = APIClient()) {
        self.client = client
    }

    func searchLocations(query: String) async throws -> [Location] {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return [] }
        guard let baseURL = URL(string: "https://geocoding-api.open-meteo.com") else {
            throw APIError.invalidURL
        }
        let dto: GeocodingResponseDTO = try await client.request(
            GeocodingEndpoint(baseURL: baseURL, name: keyword)
        )
        return dto.toLocations()
    }
}

private struct GeocodingEndpoint: Endpoint {
    let baseURL: URL
    let name: String

    var path: String { "v1/search" }

    var queryItems: [URLQueryItem] {
        [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "count", value: "10"),
            URLQueryItem(name: "language", value: SystemLanguage.openMeteoCode())
        ]
    }
}
