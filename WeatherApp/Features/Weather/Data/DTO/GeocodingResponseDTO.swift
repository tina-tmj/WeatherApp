//
//  GeocodingResponseDTO.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import Foundation

/// Open-Meteo Geocoding API 的 JSON。轉換後才變成 `Location`，缺名字或國家的列會被丟掉。
struct GeocodingResponseDTO: Codable {
    let results: [GeocodingResultDTO]?

    // MARK: - Conversion

    func toLocations() -> [Location] {
        results?.compactMap { $0.toLocation() } ?? []
    }
}

struct GeocodingResultDTO: Codable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let country: String?
    let admin1: String?
    let timezone: String?

    // MARK: - Conversion

    /// 名字或國家是空白時回傳 nil。id 保留，同名城市仍然分得開。
    func toLocation() -> Location? {
        guard
            let name = normalizedText(name),
            let country = normalizedText(country)
        else {
            return nil
        }

        return Location(
            id: id,
            name: name,
            country: country,
            admin1: normalizedText(admin1),
            latitude: latitude,
            longitude: longitude,
            timezone: normalizedText(timezone)
        )
    }
}

private func normalizedText(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    return trimmed
}
