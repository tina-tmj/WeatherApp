//
//  AccessibilityID.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import Foundation

/// UI 測試用的識別碼。集中放在一處，避免同一組字串同時散落在 ViewController 和測試裡，
/// 改名時只需要動這裡。這裡只放識別碼，不放文案。
enum AccessibilityID {
    enum Weather {
        static let cityName = "weather.cityName"
        static let temperature = "weather.temperature"
        static let condition = "weather.condition"
        static let changeCity = "weather.changeCity"
        static let returnToCurrentLocation = "weather.returnToCurrentLocation"
        static let humidity = "weather.humidity"
        static let wind = "weather.wind"
        static let precipitation = "weather.precipitation"
        static let forecastList = "weather.forecastList"
        static let errorMessage = "weather.errorMessage"
        static let retry = "weather.retry"
        static let openSettings = "weather.openSettings"
        static let loading = "weather.loading"

        /// 預報每一行都帶序號，測試才能穩定取出第 n 天。
        static func forecastRow(_ index: Int) -> String {
            "weather.forecastRow.\(index)"
        }
    }

    enum CitySearch {
        static let results = "search.results"
        static let emptyState = "search.emptyState"
        static let errorMessage = "search.errorMessage"
        static let retry = "search.retry"
        static let loading = "search.loading"

        static func resultRow(_ index: Int) -> String {
            "search.result.\(index)"
        }
    }
}
