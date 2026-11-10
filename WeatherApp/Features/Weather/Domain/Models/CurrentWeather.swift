//
//  CurrentWeather.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import Foundation

/// 目前這一刻的天氣。溫度是攝氏，風速是公里／小時，降雨量是毫米。
struct CurrentWeather: Equatable, Sendable {
    let temperature: Double
    let apparentTemperature: Double
    let humidity: Int
    let windSpeed: Double
    let precipitation: Double
    let weatherCondition: WeatherCondition
    let isDay: Bool
}
