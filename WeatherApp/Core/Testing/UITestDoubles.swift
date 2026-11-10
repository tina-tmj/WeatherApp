//
//  UITestDoubles.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

#if DEBUG
import Foundation

/// UI 測試專用的替身。定位與反查地名在模擬器上不穩定，這裡直接給固定結果，
/// 讓 UI 測試驗證的是畫面流程，而不是 CoreLocation 或網路。
enum UITestDoubles {
    /// 固定回傳香港座標，對應 MockGeocodingRepository.hongKong 的天氣資料。
    @MainActor
    final class LocationService: LocationServiceProtocol {
        func currentCoordinates() async throws -> Coordinates {
            Coordinates(latitude: MockGeocodingRepository.hongKong.latitude,
                        longitude: MockGeocodingRepository.hongKong.longitude)
        }
    }

    /// 反查地名直接回傳香港，不經過 CLGeocoder。
    @MainActor
    final class PlaceResolver: PlaceResolving {
        func place(for coordinates: Coordinates, fallbackName: String) async throws -> Location {
            MockGeocodingRepository.hongKong
        }
    }
}
#endif
