//
//  Location.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import Foundation

/// 一個可以查天氣的地點。
/// 搜尋結果的 id 來自 Geocoding API；目前位置使用負數 id，避免和城市 id 撞在一起。
struct Location: Identifiable, Equatable, Codable, Sendable {
    let id: Int
    let name: String
    let country: String
    let admin1: String?
    let latitude: Double
    let longitude: Double
    let timezone: String?
}
