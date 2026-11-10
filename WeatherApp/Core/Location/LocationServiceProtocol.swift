//
//  LocationServiceProtocol.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import Foundation

/// 定位失敗的原因。反向地理編碼失敗不在這裡，天氣仍可依座標載入。
enum LocationAccessError: Error, Equatable {
    /// 使用者拒絕 When In Use，或系統限制了定位權限。不要再次彈出授權框。
    case denied
    /// 裝置的定位服務已關閉。
    case servicesDisabled
    /// 已授權，但這一次沒有拿到位置。
    case failed
}

/// 只取得一次目前位置。呼叫端可以換成 Mock，不必碰到真實 GPS。
@MainActor
protocol LocationServiceProtocol: AnyObject {
    func currentCoordinates() async throws -> Coordinates
}

/// 把座標轉成可顯示的地名。呼叫端提供失敗時的名稱，這裡不決定文案語言。
/// 反查失敗仍回傳 Location；任務取消時拋出 CancellationError，不把取消當成地名失敗。
@MainActor
protocol PlaceResolving: AnyObject {
    func place(for coordinates: Coordinates, fallbackName: String) async throws -> Location
}
