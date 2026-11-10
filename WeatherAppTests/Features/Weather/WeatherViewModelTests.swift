//
//  WeatherViewModelTests.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import XCTest
@testable import WeatherApp

@MainActor
final class WeatherViewModelTests: XCTestCase {
    func testCurrentLocationSuccessLoadsWeatherForThoseCoordinates() async {
        let repository = RecordingWeatherRepository()
        let viewModel = WeatherViewModel(
            repository: repository,
            locationService: MockLocationService(result: .success(Coordinates(latitude: 31.2, longitude: 121.5))),
            placeResolver: FixedPlaceResolver(name: "上海")
        )

        await viewModel.loadCurrentLocation()

        XCTAssertEqual(repository.requestedCoordinates?.latitude ?? 0, 31.2, accuracy: 0.000_001)
        XCTAssertEqual(repository.requestedCoordinates?.longitude ?? 0, 121.5, accuracy: 0.000_001)
        XCTAssertEqual(viewModel.location?.name, "上海")
        XCTAssertFalse(viewModel.canReturnToCurrentLocation)
        guard case let .loaded(result) = viewModel.state else {
            XCTFail("Expected loaded state, got \(viewModel.state)")
            return
        }
        XCTAssertEqual(result.currentWeather.temperature, 18)
    }

    func testLocationFailureDoesNotLoadWeather() async {
        let repository = RecordingWeatherRepository()
        let viewModel = makeViewModel(locationResult: .failure(.failed), repository: repository)

        await viewModel.loadCurrentLocation()

        XCTAssertNil(repository.requestedCoordinates)
        XCTAssertEqual(viewModel.state, .locationUnavailable(.failed))
    }

    func testDeniedAuthorizationDoesNotRequestAgainThroughWeather() async {
        let repository = RecordingWeatherRepository()
        let viewModel = makeViewModel(locationResult: .failure(.denied), repository: repository)

        await viewModel.loadCurrentLocation()

        XCTAssertNil(repository.requestedCoordinates)
        XCTAssertEqual(viewModel.state, .locationUnavailable(.denied))
    }

    func testLocationServicesDisabled() async {
        let viewModel = makeViewModel(locationResult: .failure(.servicesDisabled), repository: RecordingWeatherRepository())

        await viewModel.loadCurrentLocation()

        XCTAssertEqual(viewModel.state, .locationUnavailable(.servicesDisabled))
    }

    func testSelectingCityUsesThatCityAndCanReturn() async {
        let repository = RecordingWeatherRepository()
        let viewModel = makeViewModel(locationResult: .success(Coordinates(latitude: 1, longitude: 2)), repository: repository)
        await viewModel.loadCurrentLocation()

        await viewModel.select(MockGeocodingRepository.tokyo)

        XCTAssertEqual(viewModel.location, MockGeocodingRepository.tokyo)
        XCTAssertTrue(viewModel.canReturnToCurrentLocation)
        XCTAssertEqual(repository.requestedLocation?.id, MockGeocodingRepository.tokyo.id)
        guard case let .loaded(result) = viewModel.state else {
            XCTFail("Expected loaded state, got \(viewModel.state)")
            return
        }
        XCTAssertEqual(result.currentWeather.temperature, 16)
    }

    func testWeatherFailureIsPresentedSeparatelyFromLocationFailure() async {
        let repository = RecordingWeatherRepository()
        repository.error = SampleForecastError()
        let viewModel = makeViewModel(
            locationResult: .success(Coordinates(latitude: 22.3, longitude: 114.2)),
            repository: repository
        )

        await viewModel.loadCurrentLocation()

        guard case let .error(message) = viewModel.state else {
            XCTFail("Expected error state, got \(viewModel.state)")
            return
        }
        XCTAssertEqual(message, L10n.text(.requestFailed))
    }

    func testLaterCityResponseDoesNotReplaceTheNewestCity() async {
        let repository = PausableWeatherRepository()
        let viewModel = makeViewModel(locationResult: .success(Coordinates(latitude: 0, longitude: 0)), repository: repository)

        async let shenzhen: Void = viewModel.select(MockGeocodingRepository.shenzhen)
        await repository.waitUntilCallCount(1)
        async let shanghai: Void = viewModel.select(MockGeocodingRepository.shanghai)
        await repository.waitUntilCallCount(2)
        async let tokyo: Void = viewModel.select(MockGeocodingRepository.tokyo)
        await repository.waitUntilCallCount(3)

        repository.finish(2, returning: sampleWeather(temperature: 16))
        await tokyo
        repository.finish(1, returning: sampleWeather(temperature: 18))
        await shanghai
        repository.finish(0, returning: sampleWeather(temperature: 24))
        await shenzhen

        XCTAssertEqual(viewModel.location, MockGeocodingRepository.tokyo)
        guard case let .loaded(result) = viewModel.state else {
            XCTFail("Expected Tokyo weather, got \(viewModel.state)")
            return
        }
        XCTAssertEqual(result.currentWeather.temperature, 16)
    }

    func testOldRequestFailureDoesNotReplaceANewerSuccess() async {
        let repository = PausableWeatherRepository()
        let viewModel = makeViewModel(locationResult: .success(Coordinates(latitude: 0, longitude: 0)), repository: repository)

        async let shanghai: Void = viewModel.select(MockGeocodingRepository.shanghai)
        await repository.waitUntilCallCount(1)
        async let tokyo: Void = viewModel.select(MockGeocodingRepository.tokyo)
        await repository.waitUntilCallCount(2)

        repository.finish(1, returning: sampleWeather(temperature: 16))
        await tokyo
        repository.finish(0, throwing: APIError.transportError(URLError(.cannotConnectToHost)))
        await shanghai

        guard case let .loaded(result) = viewModel.state else {
            XCTFail("Expected Tokyo weather, got \(viewModel.state)")
            return
        }
        XCTAssertEqual(result.currentWeather.temperature, 16)
        XCTAssertEqual(viewModel.location, MockGeocodingRepository.tokyo)
    }

    func testCancelledRequestDoesNotBecomeAnError() async {
        let repository = PausableWeatherRepository()
        let viewModel = makeViewModel(locationResult: .success(Coordinates(latitude: 0, longitude: 0)), repository: repository)

        async let shanghai: Void = viewModel.select(MockGeocodingRepository.shanghai)
        await repository.waitUntilCallCount(1)
        async let tokyo: Void = viewModel.select(MockGeocodingRepository.tokyo)
        await repository.waitUntilCallCount(2)

        repository.finish(0, throwing: CancellationError())
        await shanghai

        XCTAssertEqual(viewModel.state, .loading)
        repository.finish(1, returning: sampleWeather(temperature: 16))
        await tokyo

        guard case let .loaded(result) = viewModel.state else {
            XCTFail("Expected Tokyo weather, got \(viewModel.state)")
            return
        }
        XCTAssertEqual(result.currentWeather.temperature, 16)
    }

    func testRetryAfterFailureLoadsWeather() async {
        let repository = PausableWeatherRepository()
        let viewModel = makeViewModel(locationResult: .success(Coordinates(latitude: 0, longitude: 0)), repository: repository)

        async let first: Void = viewModel.select(MockGeocodingRepository.tokyo)
        await repository.waitUntilCallCount(1)
        repository.finish(0, throwing: APIError.timeout)
        await first

        XCTAssertEqual(viewModel.state, .error(L10n.text(.requestTimeout)))

        async let second: Void = viewModel.retry()
        await repository.waitUntilCallCount(2)
        repository.finish(1, returning: sampleWeather(temperature: 16))
        await second

        guard case let .loaded(result) = viewModel.state else {
            XCTFail("Expected loaded weather, got \(viewModel.state)")
            return
        }
        XCTAssertEqual(result.currentWeather.temperature, 16)
        XCTAssertEqual(viewModel.location, MockGeocodingRepository.tokyo)
    }

    func testLocationFailureStillAllowsSelectingACity() async {
        let repository = RecordingWeatherRepository()
        let viewModel = makeViewModel(locationResult: .failure(.denied), repository: repository)

        await viewModel.loadCurrentLocation()
        XCTAssertEqual(viewModel.state, .locationUnavailable(.denied))

        await viewModel.select(MockGeocodingRepository.hongKong)

        XCTAssertEqual(viewModel.location, MockGeocodingRepository.hongKong)
        guard case let .loaded(result) = viewModel.state else {
            XCTFail("Expected Hong Kong weather, got \(viewModel.state)")
            return
        }
        XCTAssertEqual(result.currentWeather.temperature, 26)
    }

    func testLateCurrentLocationDoesNotReplaceTheSelectedCity() async {
        let locationService = PausableLocationService()
        let repository = PausableWeatherRepository()
        let viewModel = WeatherViewModel(
            repository: repository,
            locationService: locationService,
            placeResolver: FixedPlaceResolver(name: "上海")
        )

        async let current: Void = viewModel.loadCurrentLocation()
        await locationService.waitUntilStarted()
        async let selected: Void = viewModel.select(MockGeocodingRepository.tokyo)
        await repository.waitUntilCallCount(1)
        repository.finish(0, returning: sampleWeather(temperature: 16))
        await selected
        locationService.resume(Coordinates(latitude: 31.2, longitude: 121.5))
        await current

        XCTAssertEqual(viewModel.location, MockGeocodingRepository.tokyo)
        XCTAssertEqual(repository.calls.count, 1)
        guard case let .loaded(result) = viewModel.state else {
            XCTFail("Expected Tokyo weather, got \(viewModel.state)")
            return
        }
        XCTAssertEqual(result.currentWeather.temperature, 16)
    }

    func testReturningToCurrentLocationShowsCurrentLocationAgain() async {
        let viewModel = WeatherViewModel(
            repository: RecordingWeatherRepository(),
            locationService: MockLocationService(result: .success(Coordinates(latitude: 31.2, longitude: 121.5))),
            placeResolver: FixedPlaceResolver(name: "上海")
        )
        await viewModel.select(MockGeocodingRepository.tokyo)

        await viewModel.returnToCurrentLocation()

        XCTAssertEqual(viewModel.location?.name, "上海")
        XCTAssertFalse(viewModel.canReturnToCurrentLocation)
    }

    private func makeViewModel(
        locationResult: Result<Coordinates, LocationAccessError>,
        repository: WeatherRepositoryProtocol
    ) -> WeatherViewModel {
        WeatherViewModel(
            repository: repository,
            locationService: MockLocationService(result: locationResult),
            placeResolver: FixedPlaceResolver(name: "上海")
        )
    }
}

@MainActor
private final class MockLocationService: LocationServiceProtocol {
    let result: Result<Coordinates, LocationAccessError>

    init(result: Result<Coordinates, LocationAccessError>) {
        self.result = result
    }

    func currentCoordinates() async throws -> Coordinates {
        try result.get()
    }
}

@MainActor
private final class FixedPlaceResolver: PlaceResolving {
    let name: String

    init(name: String) {
        self.name = name
    }

    func place(for coordinates: Coordinates, fallbackName: String) async throws -> Location {
        Location(
            id: -1,
            name: name,
            country: "中国",
            admin1: nil,
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
            timezone: "Asia/Shanghai"
        )
    }
}

private final class RecordingWeatherRepository: WeatherRepositoryProtocol {
    var requestedCoordinates: Coordinates?
    var requestedLocation: Location?
    var error: Error?

    func fetchWeather(for location: Location) async throws -> WeatherResult {
        requestedLocation = location
        return try await fetchWeather(at: Coordinates(latitude: location.latitude, longitude: location.longitude))
    }

    func fetchWeather(at coordinates: Coordinates) async throws -> WeatherResult {
        requestedCoordinates = coordinates
        if let error {
            throw error
        }
        let sample = MockWeatherRepository()
        return try await sample.fetchWeather(at: coordinates)
    }
}

private struct SampleForecastError: LocalizedError {
    var errorDescription: String? { "Unable to load the sample forecast." }
}

private func sampleWeather(temperature: Double) -> WeatherResult {
    WeatherResult(
        currentWeather: CurrentWeather(
            temperature: temperature,
            apparentTemperature: temperature,
            humidity: 50,
            windSpeed: 10,
            precipitation: 0,
            weatherCondition: .clear,
            isDay: true
        ),
        dailyForecasts: [],
        timeZone: TimeZone(secondsFromGMT: 0)!
    )
}

@MainActor
private final class PausableLocationService: LocationServiceProtocol {
    private var continuation: CheckedContinuation<Coordinates, Error>?
    private var startedContinuation: CheckedContinuation<Void, Never>?

    func currentCoordinates() async throws -> Coordinates {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let started = self.startedContinuation
            self.startedContinuation = nil
            if let started {
                Task { @MainActor in
                    started.resume()
                }
            }
        }
    }

    func waitUntilStarted() async {
        if continuation != nil { return }
        await withCheckedContinuation { continuation in
            if self.continuation != nil {
                continuation.resume()
            } else {
                self.startedContinuation = continuation
            }
        }
    }

    func resume(_ coordinates: Coordinates) {
        continuation?.resume(returning: coordinates)
        continuation = nil
    }
}

@MainActor
private final class PausableWeatherRepository: WeatherRepositoryProtocol {
    private(set) var calls: [Coordinates] = []
    private var continuations: [CheckedContinuation<WeatherResult, Error>] = []
    private var waiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    func fetchWeather(for location: Location) async throws -> WeatherResult {
        try await fetchWeather(at: Coordinates(latitude: location.latitude, longitude: location.longitude))
    }

    func fetchWeather(at coordinates: Coordinates) async throws -> WeatherResult {
        try await withCheckedThrowingContinuation { continuation in
            self.calls.append(coordinates)
            self.continuations.append(continuation)
            let ready = self.waiters.filter { self.calls.count >= $0.count }
            self.waiters.removeAll { self.calls.count >= $0.count }
            if !ready.isEmpty {
                Task { @MainActor in
                    ready.forEach { $0.continuation.resume() }
                }
            }
        }
    }

    func waitUntilCallCount(_ count: Int) async {
        if calls.count >= count { return }
        await withCheckedContinuation { continuation in
            if self.calls.count >= count {
                continuation.resume()
            } else {
                self.waiters.append((count, continuation))
            }
        }
    }

    func finish(_ index: Int, returning result: WeatherResult) {
        continuations[index].resume(returning: result)
    }

    func finish(_ index: Int, throwing error: Error) {
        continuations[index].resume(throwing: error)
    }
}
