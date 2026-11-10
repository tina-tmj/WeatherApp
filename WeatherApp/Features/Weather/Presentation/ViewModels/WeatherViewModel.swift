//
//  WeatherViewModel.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import Foundation
import os

/// 首頁正在顯示目前位置，還是使用者剛搜尋的城市。兩者的重新整理方式不同。
enum WeatherContext: Equatable {
    case currentLocation
    case searchedCity
}

enum LocationProblem: Equatable {
    case denied
    case servicesDisabled
    case failed
}

/// 首頁狀態：載入、成功、天氣失敗、定位失敗。用一個 enum。
enum WeatherViewState: Equatable {
    /// 還沒開始載入。
    case idle
    /// 正在定位或正在請求天氣。畫面只留載入指示器。
    case loading
    /// 天氣已經拿到，可以畫內容。
    case loaded(WeatherResult)
    /// 天氣 API 失敗。定位問題不走這個 case。
    case error(String)
    /// 拿不到目前位置。使用者仍可改走城市搜尋。
    case locationUnavailable(LocationProblem)
}

/// 首頁的狀態與請求。定位、城市天氣、重試都從這裡出去。
/// 同一時間只認最新一筆請求，舊請求回來不會改畫面。
@MainActor
final class WeatherViewModel {
    private let repository: WeatherRepositoryProtocol
    private let locationService: LocationServiceProtocol
    private let placeResolver: PlaceResolving
    private let log = Logger(subsystem: "com.weatherapp.WeatherApp", category: "Weather")

    /// 每次新請求加一。舊請求回來時對不上這個數字，就不能改畫面。
    private var requestID = 0
    private var activeTask: Task<Void, Never>?

    private(set) var context: WeatherContext = .currentLocation
    /// 搜尋城市或已經解析出的目前位置。定位尚未成功時為 nil。
    private(set) var location: Location?
    private(set) var state: WeatherViewState = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: (@MainActor (WeatherViewState) -> Void)?

    var displayName: String {
        location?.name ?? L10n.text(.currentLocation)
    }

    var canReturnToCurrentLocation: Bool {
        context == .searchedCity
    }

    init(
        repository: WeatherRepositoryProtocol,
        locationService: LocationServiceProtocol,
        placeResolver: PlaceResolving
    ) {
        self.repository = repository
        self.locationService = locationService
        self.placeResolver = placeResolver
    }

    /// 冷啟動一律回到目前位置。
    func loadInitialContent() async {
        await loadCurrentLocation()
    }

    func loadCurrentLocation() async {
        context = .currentLocation
        await runRequest { id in
            let coordinates = try await self.locationService.currentCoordinates()
            try Task.checkCancellation()
            guard id == self.requestID else { return nil }
            // 地名失敗時 placeResolver 仍回傳呼叫端給的名稱，這裡繼續請求天氣。
            // 取消會以 CancellationError 拋出，不會被當成定位失敗。
            let place = try await self.placeResolver.place(
                for: coordinates,
                fallbackName: L10n.text(.currentLocation)
            )
            try Task.checkCancellation()
            guard id == self.requestID else { return nil }
            self.location = place
            return try await self.repository.fetchWeather(at: coordinates)
        }
    }

    func retry() async {
        switch context {
        case .currentLocation:
            await loadCurrentLocation()
        case .searchedCity:
            guard let location else {
                await loadCurrentLocation()
                return
            }
            await runRequest { _ in
                try await self.repository.fetchWeather(for: location)
            }
        }
    }

    func select(_ location: Location) async {
        context = .searchedCity
        self.location = location
        await runRequest { _ in
            try await self.repository.fetchWeather(for: location)
        }
    }

    func returnToCurrentLocation() async {
        await loadCurrentLocation()
    }

    /// 取消上一筆請求，只讓這一次的結果寫進 state。取消本身不會變成 Error。
    private func runRequest(
        _ work: @escaping @MainActor (_ requestID: Int) async throws -> WeatherResult?
    ) async {
        activeTask?.cancel()
        requestID += 1
        let currentID = requestID
        state = .loading

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                guard let result = try await work(currentID) else { return }
                guard currentID == self.requestID else { return }
                self.state = .loaded(result)
            } catch is CancellationError {
                return
            } catch let error as LocationAccessError {
                guard currentID == self.requestID else { return }
                self.state = .locationUnavailable(Self.problem(for: error))
            } catch {
                guard currentID == self.requestID else { return }
                self.log.error("Weather request failed: \(String(describing: error), privacy: .public)")
                self.state = .error(userFacingRequestMessage(for: error))
            }
        }
        activeTask = task
        await task.value
    }

    private static func problem(for error: LocationAccessError) -> LocationProblem {
        switch error {
        case .denied:
            return .denied
        case .servicesDisabled:
            return .servicesDisabled
        case .failed:
            return .failed
        }
    }
}

/// 給畫面看的短句。狀態碼和底層錯誤留在 APIError，並另外寫進日誌。
func userFacingRequestMessage(for error: Error) -> String {
    switch error {
        case APIError.timeout:
            return L10n.text(.requestTimeout)
        case APIError.transportError:
            return L10n.text(.networkFailed)
        case APIError.httpError:
            return L10n.text(.serverFailed)
        case APIError.decodingError:
            return L10n.text(.unreadableData)
        default:
            return L10n.text(.requestFailed)
    }
}
