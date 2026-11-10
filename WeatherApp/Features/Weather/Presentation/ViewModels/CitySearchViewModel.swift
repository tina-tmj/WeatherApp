//
//  CitySearchViewModel.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import Foundation
import os

/// 搜尋頁狀態。Empty 是「有回應但沒城市」，Error 才是請求失敗。
enum CitySearchViewState: Equatable {
    /// 還沒輸入，或使用者把關鍵字清空。
    case idle
    /// 正在等這一次搜尋回來。舊的列表會先清掉。
    case loading
    /// 搜尋成功，而且至少有一筆城市。
    case results([Location])
    /// 搜尋成功，但沒有符合的城市。這不是網路錯誤。
    case empty
    /// 搜尋請求失敗，可以重試。
    case error(String)
}

/// 城市搜尋的狀態。空字串不打 API；連續輸入時只留下最後一個關鍵字的結果。
@MainActor
final class CitySearchViewModel {
    private let repository: GeocodingRepositoryProtocol
    private let debounceNanoseconds: UInt64
    private let log = Logger(subsystem: "com.weatherapp.WeatherApp", category: "CitySearch")

    private var requestID = 0
    private var activeTask: Task<Void, Never>?
    private var lastKeyword = ""

    private(set) var state: CitySearchViewState = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: (@MainActor (CitySearchViewState) -> Void)?

    init(repository: GeocodingRepositoryProtocol, debounceNanoseconds: UInt64 = 300_000_000) {
        self.repository = repository
        self.debounceNanoseconds = debounceNanoseconds
    }

    func updateQuery(_ query: String) async {
        await schedule(query, debounceNanoseconds: debounceNanoseconds)
    }

    func retry() async {
        guard !lastKeyword.isEmpty else { return }
        await schedule(lastKeyword, debounceNanoseconds: 0)
    }

    /// 頁面離開時呼叫。進行中的搜尋結果不再寫回畫面。
    func cancel() {
        requestID += 1
        activeTask?.cancel()
    }

    private func schedule(_ query: String, debounceNanoseconds: UInt64) async {
        activeTask?.cancel()
        requestID += 1
        let currentID = requestID
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !keyword.isEmpty else {
            lastKeyword = ""
            state = .idle
            return
        }

        lastKeyword = keyword
        state = .loading

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                if debounceNanoseconds > 0 {
                    try await Task.sleep(nanoseconds: debounceNanoseconds)
                }
                try Task.checkCancellation()
                guard currentID == self.requestID else { return }
                let locations = try await self.repository.searchLocations(query: keyword)
                try Task.checkCancellation()
                guard currentID == self.requestID else { return }
                self.state = locations.isEmpty ? .empty : .results(locations)
            } catch is CancellationError {
                return
            } catch {
                guard currentID == self.requestID else { return }
                self.log.error("City search failed: \(String(describing: error), privacy: .public)")
                self.state = .error(userFacingRequestMessage(for: error))
            }
        }
        activeTask = task
        await task.value
    }
}
