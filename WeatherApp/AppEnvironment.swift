//
//  AppEnvironment.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import Foundation

/// 依賴組裝的唯一入口。SceneDelegate 只負責視窗與頁面跳轉，不在那裡 new 任何 Repository。
///
/// 這裡刻意不使用 DI 容器：目前只有一組依賴、只有一個組裝點，多一層容器只會讓閱讀時
/// 需要多跳一層才能知道實際注入的是什麼。要換實作時，改的就是這一個檔案。
@MainActor
struct AppEnvironment {
    let weatherRepository: WeatherRepositoryProtocol
    let geocodingRepository: GeocodingRepositoryProtocol
    let locationService: LocationServiceProtocol
    let placeResolver: PlaceResolving

    /// 正式啟動：Open-Meteo 加上 CoreLocation。
    static func live() -> AppEnvironment {
        AppEnvironment(
            weatherRepository: OpenMeteoWeatherRepository(),
            geocodingRepository: OpenMeteoGeocodingRepository(),
            locationService: CoreLocationService(),
            placeResolver: CoreLocationPlaceResolver()
        )
    }

    #if DEBUG
    /// UI 測試用：固定座標、固定資料、不碰 GPS 與外網，結果可重現。
    /// 只在 DEBUG 編譯，正式版二進位不含這些替身。
    static func uiTesting() -> AppEnvironment {
        AppEnvironment(
            weatherRepository: MockWeatherRepository(),
            geocodingRepository: MockGeocodingRepository(),
            locationService: UITestDoubles.LocationService(),
            placeResolver: UITestDoubles.PlaceResolver()
        )
    }

    /// 文件截圖用：定位回傳指定座標，天氣與反查仍走真實 API，
    /// 讓 README 上的畫面是真實資料，又不依賴模擬器的 GPS 授權。
    static func preview(coordinates: Coordinates) -> AppEnvironment {
        AppEnvironment(
            weatherRepository: OpenMeteoWeatherRepository(),
            geocodingRepository: OpenMeteoGeocodingRepository(),
            locationService: PreviewLocationService(coordinates: coordinates),
            placeResolver: CoreLocationPlaceResolver()
        )
    }

    /// 只回傳固定座標的 LocationService 替身，其餘一律真實。
    private final class PreviewLocationService: LocationServiceProtocol {
        private let coordinates: Coordinates

        init(coordinates: Coordinates) {
            self.coordinates = coordinates
        }

        func currentCoordinates() async throws -> Coordinates {
            coordinates
        }
    }

    /// 讀取 `-PreviewCoordinates 22.3193,114.1694` 形式的啟動參數。
    private static func previewCoordinates(from arguments: [String]) -> Coordinates? {
        guard let index = arguments.firstIndex(of: "-PreviewCoordinates"),
              arguments.count > index + 1 else { return nil }
        let parts = arguments[index + 1].split(separator: ",")
        guard parts.count == 2,
              let lat = Double(parts[0]),
              let lon = Double(parts[1]) else { return nil }
        return Coordinates(latitude: lat, longitude: lon)
    }
    #endif

    /// 啟動參數帶 `-UITestMode` 時切到測試替身，帶 `-PreviewCoordinates` 時走真實 API
    /// 但固定座標，其餘一律走正式實作。
    static func resolve() -> AppEnvironment {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-UITestMode") {
            return .uiTesting()
        }
        if let coordinates = previewCoordinates(from: ProcessInfo.processInfo.arguments) {
            return .preview(coordinates: coordinates)
        }
        #endif
        return .live()
    }
}
