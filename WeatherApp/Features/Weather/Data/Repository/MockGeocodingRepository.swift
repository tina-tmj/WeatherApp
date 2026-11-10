//
//  MockGeocodingRepository.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

#if DEBUG
import Foundation

/// 寫死的五個城市，只給測試使用。正式搜尋走 Open-Meteo Geocoding API。
/// 整個檔案包在 `#if DEBUG`：正式版不編譯，也就沒有機會被誤用到。
final class MockGeocodingRepository: GeocodingRepositoryProtocol {
    static let hongKong = Location(
        id: 1819729,
        name: "Hong Kong",
        country: "Hong Kong",
        admin1: nil,
        latitude: 22.3193,
        longitude: 114.1694,
        timezone: "Asia/Hong_Kong"
    )

    static let shenzhen = Location(
        id: 1795565,
        name: "Shenzhen",
        country: "China",
        admin1: "Guangdong",
        latitude: 22.5455,
        longitude: 114.0683,
        timezone: "Asia/Shanghai"
    )

    static let shanghai = Location(
        id: 1796236,
        name: "Shanghai",
        country: "China",
        admin1: "Shanghai",
        latitude: 31.2222,
        longitude: 121.4581,
        timezone: "Asia/Shanghai"
    )

    static let tokyo = Location(
        id: 1850147,
        name: "Tokyo",
        country: "Japan",
        admin1: "Tokyo",
        latitude: 35.6895,
        longitude: 139.6917,
        timezone: "Asia/Tokyo"
    )

    static let newYork = Location(
        id: 5128581,
        name: "New York",
        country: "United States",
        admin1: "New York",
        latitude: 40.7143,
        longitude: -74.006,
        timezone: "America/New_York"
    )

    static let locations = [hongKong, shenzhen, shanghai, tokyo, newYork]

    func searchLocations(query: String) async throws -> [Location] {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return [] }

        return Self.locations.filter { location in
            location.name.localizedCaseInsensitiveContains(keyword)
                || location.country.localizedCaseInsensitiveContains(keyword)
        }
    }
}
#endif
