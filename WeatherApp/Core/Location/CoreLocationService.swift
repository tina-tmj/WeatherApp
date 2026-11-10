//
//  CoreLocationService.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import CoreLocation
import Foundation

/// `CLLocationManager` 上這次定位實際會用到的方法。測試可以換上不會觸發真實 GPS 的替身。
protocol OneShotLocationManaging: AnyObject {
    var authorizationStatus: CLAuthorizationStatus { get }
    var delegate: CLLocationManagerDelegate? { get set }
    func requestWhenInUseAuthorization()
    func requestLocation()
}

extension CLLocationManager: OneShotLocationManaging {}

/// 使用系統 CLLocationManager 取得一次位置。不註冊持續更新，也不申請 Always 權限。
/// 等待授權或定位時如果任務被取消，會結束對應的 continuation，避免下一次請求把它蓋掉後洩漏。
@MainActor
final class CoreLocationService: NSObject, LocationServiceProtocol, CLLocationManagerDelegate {
    private let manager: OneShotLocationManaging
    private let locationServicesEnabled: @Sendable () -> Bool
    private let authorizationWait = CancellableWait<CLAuthorizationStatus>()
    private let locationWait = CancellableWait<CLLocation>()

    init(
        manager: OneShotLocationManaging = CLLocationManager(),
        locationServicesEnabled: @escaping @Sendable () -> Bool = { CLLocationManager.locationServicesEnabled() }
    ) {
        self.manager = manager
        self.locationServicesEnabled = locationServicesEnabled
        super.init()
        self.manager.delegate = self
        if let coreLocationManager = manager as? CLLocationManager {
            coreLocationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        }
    }

    func currentCoordinates() async throws -> Coordinates {
        // 先看 authorizationStatus。不要在主執行緒呼叫 locationServicesEnabled()，
        // 那個同步查詢會卡住介面。
        try await resolveAuthorization()
        let location = try await requestOneLocation()
        return Coordinates(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }

    private func resolveAuthorization() async throws {
        try Task.checkCancellation()
        let status = manager.authorizationStatus
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return
        case .notDetermined:
            // 系統總開關關閉時，狀態也可能是尚未決定。先在背景確認，再決定要不要彈授權框。
            try await ensureLocationServicesEnabled()
            try Task.checkCancellation()
            let updated = try await requestWhenInUseAuthorization()
            try await validate(updated)
        case .denied:
            try await ensureLocationServicesEnabled()
            throw LocationAccessError.denied
        case .restricted:
            throw LocationAccessError.denied
        @unknown default:
            throw LocationAccessError.failed
        }
    }

    private func validate(_ status: CLAuthorizationStatus) async throws {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return
        case .denied:
            try await ensureLocationServicesEnabled()
            throw LocationAccessError.denied
        case .restricted:
            throw LocationAccessError.denied
        case .notDetermined:
            throw LocationAccessError.failed
        @unknown default:
            throw LocationAccessError.failed
        }
    }

    /// 只在已經看過授權狀態、而且需要分辨「使用者拒絕」和「系統定位關閉」時才查詢。
    /// 查詢放到背景，避免主執行緒出現 UI unresponsiveness 警告。
    private func ensureLocationServicesEnabled() async throws {
        let check = locationServicesEnabled
        let enabled = await Task.detached(priority: .userInitiated) {
            check()
        }.value
        try Task.checkCancellation()
        guard enabled else {
            throw LocationAccessError.servicesDisabled
        }
    }

    private func requestWhenInUseAuthorization() async throws -> CLAuthorizationStatus {
        try await authorizationWait.wait { [manager] _ in
            manager.requestWhenInUseAuthorization()
        }
    }

    private func requestOneLocation() async throws -> CLLocation {
        try await locationWait.wait { [manager] _ in
            manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = self.manager.authorizationStatus
        guard status != .notDetermined else { return }
        authorizationWait.resume(.success(status))
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            locationWait.resume(.failure(LocationAccessError.failed))
            return
        }
        locationWait.resume(.success(location))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let coreLocationError = error as? CLError, coreLocationError.code == .denied {
            locationWait.resume(.failure(LocationAccessError.denied))
        } else {
            locationWait.resume(.failure(LocationAccessError.failed))
        }
    }
}
