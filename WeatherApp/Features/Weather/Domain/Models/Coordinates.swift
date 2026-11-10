//
//  Coordinates.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import Foundation

/// 不依賴 Core Location 的經緯度，方便 Repository 與測試使用。
struct Coordinates: Equatable, Sendable {
    let latitude: Double
    let longitude: Double
}
