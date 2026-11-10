//
//  GeocodingRepositoryProtocol.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import Foundation

/// 依關鍵字搜尋城市。只回傳領域模型，呼叫端看不到 URL 和 JSON。
protocol GeocodingRepositoryProtocol {
    func searchLocations(query: String) async throws -> [Location]
}
