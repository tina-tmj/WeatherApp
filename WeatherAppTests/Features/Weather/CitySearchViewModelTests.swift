//
//  CitySearchViewModelTests.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import XCTest
@testable import WeatherApp

@MainActor
final class CitySearchViewModelTests: XCTestCase {
    func testSearchReturnsMatchingCities() async {
        let viewModel = CitySearchViewModel(repository: MockGeocodingRepository(), debounceNanoseconds: 0)

        await viewModel.updateQuery("tok")

        guard case let .results(locations) = viewModel.state else {
            XCTFail("Expected results, got \(viewModel.state)")
            return
        }
        XCTAssertEqual(locations.map(\.name), ["Tokyo"])
        XCTAssertEqual(locations.map(\.country), ["Japan"])
    }

    func testEmptyQueryShowsIdleAndDoesNotSearch() async {
        let repository = RecordingGeocodingRepository(locations: [MockGeocodingRepository.tokyo])
        let viewModel = CitySearchViewModel(repository: repository, debounceNanoseconds: 0)

        await viewModel.updateQuery("tokyo")
        await viewModel.updateQuery("   ")

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(repository.queries, ["tokyo"])
    }

    func testUnmatchedQueryShowsEmpty() async {
        let viewModel = CitySearchViewModel(repository: MockGeocodingRepository(), debounceNanoseconds: 0)

        await viewModel.updateQuery("zzzz")

        XCTAssertEqual(viewModel.state, .empty)
    }

    func testSearchFailureShowsError() async {
        let repository = PausableGeocodingRepository()
        let viewModel = CitySearchViewModel(repository: repository, debounceNanoseconds: 0)

        async let search: Void = viewModel.updateQuery("tokyo")
        await repository.waitUntilCallCount(1)
        repository.finish(0, throwing: APIError.transportError(URLError(.cannotConnectToHost)))
        await search

        XCTAssertEqual(viewModel.state, .error(L10n.text(.networkFailed)))
    }

    func testRetryAfterSearchFailure() async {
        let repository = PausableGeocodingRepository()
        let viewModel = CitySearchViewModel(repository: repository, debounceNanoseconds: 0)

        async let search: Void = viewModel.updateQuery("tokyo")
        await repository.waitUntilCallCount(1)
        repository.finish(0, throwing: APIError.timeout)
        await search

        async let retry: Void = viewModel.retry()
        await repository.waitUntilCallCount(2)
        repository.finish(1, returning: [MockGeocodingRepository.tokyo])
        await retry

        guard case let .results(locations) = viewModel.state else {
            XCTFail("Expected results, got \(viewModel.state)")
            return
        }
        XCTAssertEqual(locations, [MockGeocodingRepository.tokyo])
    }

    func testOlderSearchCannotReplaceTheNewestQuery() async {
        let repository = PausableGeocodingRepository()
        let viewModel = CitySearchViewModel(repository: repository, debounceNanoseconds: 0)

        async let shanghai: Void = viewModel.updateQuery("sh")
        await repository.waitUntilCallCount(1)
        async let tokyo: Void = viewModel.updateQuery("tok")
        await repository.waitUntilCallCount(2)

        repository.finish(1, returning: [MockGeocodingRepository.tokyo])
        await tokyo
        repository.finish(0, returning: [MockGeocodingRepository.shanghai])
        await shanghai

        guard case let .results(locations) = viewModel.state else {
            XCTFail("Expected Tokyo results, got \(viewModel.state)")
            return
        }
        XCTAssertEqual(locations, [MockGeocodingRepository.tokyo])
    }

    func testClearingTheQueryDropsAnInFlightResult() async {
        let repository = PausableGeocodingRepository()
        let viewModel = CitySearchViewModel(repository: repository, debounceNanoseconds: 0)

        async let search: Void = viewModel.updateQuery("tokyo")
        await repository.waitUntilCallCount(1)
        async let cleared: Void = viewModel.updateQuery(" ")
        await cleared

        XCTAssertEqual(viewModel.state, .idle)
        repository.finish(0, returning: [MockGeocodingRepository.tokyo])
        await search

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(repository.queries, ["tokyo"])
    }

    func testCancelledSearchDoesNotShowAnError() async {
        let repository = PausableGeocodingRepository()
        let viewModel = CitySearchViewModel(repository: repository, debounceNanoseconds: 0)

        async let search: Void = viewModel.updateQuery("tokyo")
        await repository.waitUntilCallCount(1)
        viewModel.cancel()
        repository.finish(0, throwing: CancellationError())
        await search

        if case .error = viewModel.state {
            XCTFail("Cancellation was shown as a search failure")
        }
    }
}

private final class RecordingGeocodingRepository: GeocodingRepositoryProtocol {
    let locations: [Location]
    private(set) var queries: [String] = []

    init(locations: [Location]) {
        self.locations = locations
    }

    func searchLocations(query: String) async throws -> [Location] {
        queries.append(query)
        return locations
    }
}

@MainActor
private final class PausableGeocodingRepository: GeocodingRepositoryProtocol {
    private(set) var queries: [String] = []
    private var continuations: [CheckedContinuation<[Location], Error>] = []
    private var waiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    func searchLocations(query: String) async throws -> [Location] {
        try await withCheckedThrowingContinuation { continuation in
            self.queries.append(query)
            self.continuations.append(continuation)
            let ready = self.waiters.filter { self.queries.count >= $0.count }
            self.waiters.removeAll { self.queries.count >= $0.count }
            if !ready.isEmpty {
                Task { @MainActor in
                    ready.forEach { $0.continuation.resume() }
                }
            }
        }
    }

    func waitUntilCallCount(_ count: Int) async {
        if queries.count >= count { return }
        await withCheckedContinuation { continuation in
            if self.queries.count >= count {
                continuation.resume()
            } else {
                self.waiters.append((count, continuation))
            }
        }
    }

    func finish(_ index: Int, returning locations: [Location]) {
        continuations[index].resume(returning: locations)
    }

    func finish(_ index: Int, throwing error: Error) {
        continuations[index].resume(throwing: error)
    }
}
