//
//  CoreLocationPlaceResolver.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import CoreLocation
import Foundation

/// 反查地名時實際會用到的方法。正式環境是 CLGeocoder，測試可以暫停或取消。
protocol ReverseGeocoding: AnyObject {
    func reverseGeocodeLocation(
        _ location: CLLocation,
        completionHandler: @escaping CLGeocodeCompletionHandler
    )
    func cancelGeocode()
}

extension CLGeocoder: ReverseGeocoding {}

/// 用 CLGeocoder 把目前座標翻成城市名。解析失敗時使用呼叫端傳入的名稱，天氣請求仍繼續。
/// 任務取消時結束等待並呼叫 cancelGeocode()，避免 continuation 一直掛著。
@MainActor
final class CoreLocationPlaceResolver: PlaceResolving {
    /// 目前位置不是 Geocoding API 的城市 id，用負值與搜尋結果分開。
    static let currentLocationID = -1

    private let geocoder: ReverseGeocoding
    private let geocodeWait = CancellableWait<[CLPlacemark]>()

    init(geocoder: ReverseGeocoding = CLGeocoder()) {
        self.geocoder = geocoder
    }

    func place(for coordinates: Coordinates, fallbackName: String) async throws -> Location {
        let location = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
        do {
            let placemarks = try await reverseGeocode(location)
            if let placemark = placemarks.first {
                return makeLocation(from: placemark, coordinates: coordinates, fallbackName: fallbackName)
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // 地名失敗不影響後續天氣請求。
        }
        return fallbackLocation(for: coordinates, fallbackName: fallbackName)
    }

    private func reverseGeocode(_ location: CLLocation) async throws -> [CLPlacemark] {
        let geocoder = self.geocoder
        return try await geocodeWait.wait(onCancel: { [geocoder] in
            geocoder.cancelGeocode()
        }) { [geocoder, geocodeWait] generation in
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                Task { @MainActor in
                    if let error {
                        if let coreLocationError = error as? CLError, coreLocationError.code == .geocodeCanceled {
                            geocodeWait.resume(.failure(CancellationError()), matching: generation)
                        } else {
                            geocodeWait.resume(.failure(error), matching: generation)
                        }
                        return
                    }
                    geocodeWait.resume(.success(placemarks ?? []), matching: generation)
                }
            }
        }
    }

    private func makeLocation(
        from placemark: CLPlacemark,
        coordinates: Coordinates,
        fallbackName: String
    ) -> Location {
        let name = placemark.locality
            ?? placemark.subAdministrativeArea
            ?? placemark.administrativeArea
            ?? placemark.name
            ?? fallbackName
        return Location(
            id: Self.currentLocationID,
            name: name,
            country: placemark.country ?? "",
            admin1: placemark.administrativeArea,
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
            timezone: placemark.timeZone?.identifier
        )
    }

    private func fallbackLocation(for coordinates: Coordinates, fallbackName: String) -> Location {
        Location(
            id: Self.currentLocationID,
            name: fallbackName,
            country: "",
            admin1: nil,
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
            timezone: nil
        )
    }
}
