//
//  WeatherRepositoryProtocol.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import Foundation

/// 一次天氣查詢的結果：目前天氣加上每日預報。
/// `timeZone` 只服務預報日期，目前天氣仍然表示這一刻。
struct WeatherResult: Equatable, Sendable {
    let currentWeather: CurrentWeather
    let dailyForecasts: [DailyForecast]
    /// 這次回應裡的預報地點時區。優先是 IANA 名稱，沒有時才用固定 UTC 偏移，最後才是 UTC。
    let timeZone: TimeZone
}

/// 天氣資料來源。正式環境走 Open-Meteo，測試可換成會暫停或失敗的 Mock。
protocol WeatherRepositoryProtocol {
    /// 使用者從搜尋結果選中的城市。
    func fetchWeather(for location: Location) async throws -> WeatherResult
    /// 裝置目前座標。與搜尋城市分開，避免把定位結果當成某一個城市 id。
    func fetchWeather(at coordinates: Coordinates) async throws -> WeatherResult
}
