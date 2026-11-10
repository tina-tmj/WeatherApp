//
//  CoreLocationCancellationTests.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import CoreLocation
import XCTest
@testable import WeatherApp

@MainActor
final class CoreLocationCancellationTests: XCTestCase {
    func testLocationRequestReturnsCoordinates() async throws {
        let manager = FakeLocationManager(status: .authorizedWhenInUse)
        let service = CoreLocationService(manager: manager, locationServicesEnabled: { true })

        let task = Task { try await service.currentCoordinates() }
        await manager.waitForLocationRequest()
        service.locationManager(
            CLLocationManager(),
            didUpdateLocations: [CLLocation(latitude: 31.23, longitude: 121.47)]
        )

        let coordinates = try await task.value
        XCTAssertEqual(coordinates.latitude, 31.23, accuracy: 0.000_001)
        XCTAssertEqual(coordinates.longitude, 121.47, accuracy: 0.000_001)
    }

    func testCancellingLocationRequestThrowsAndIgnoresTheLateCallback() async throws {
        let manager = FakeLocationManager(status: .authorizedWhenInUse)
        let service = CoreLocationService(manager: manager, locationServicesEnabled: { true })

        let first = Task { try await service.currentCoordinates() }
        await manager.waitForLocationRequest()
        first.cancel()

        do {
            _ = try await first.value
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }

        service.locationManager(
            CLLocationManager(),
            didUpdateLocations: [CLLocation(latitude: 1, longitude: 2)]
        )
        service.locationManager(CLLocationManager(), didFailWithError: CLError(.locationUnknown))

        let second = Task { try await service.currentCoordinates() }
        await manager.waitForLocationRequest(count: 2)
        service.locationManager(
            CLLocationManager(),
            didUpdateLocations: [CLLocation(latitude: 22.3, longitude: 114.1)]
        )
        let coordinates = try await second.value
        XCTAssertEqual(coordinates.latitude, 22.3, accuracy: 0.000_001)
    }

    func testCancellingAuthorizationDoesNotLeaveTheRequestSuspended() async {
        let manager = FakeLocationManager(status: .notDetermined)
        let service = CoreLocationService(manager: manager, locationServicesEnabled: { true })

        let task = Task { try await service.currentCoordinates() }
        await manager.waitForAuthorizationRequest()
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }

        manager.authorizationStatus = .authorizedWhenInUse
        service.locationManagerDidChangeAuthorization(CLLocationManager())
        XCTAssertEqual(manager.locationRequestCount, 0)
    }

    func testDeniedLocationFailureIsNotCancellation() async {
        let manager = FakeLocationManager(status: .authorizedWhenInUse)
        let service = CoreLocationService(manager: manager, locationServicesEnabled: { true })

        let task = Task { try await service.currentCoordinates() }
        await manager.waitForLocationRequest()
        service.locationManager(CLLocationManager(), didFailWithError: CLError(.denied))

        do {
            _ = try await task.value
            XCTFail("Expected denied")
        } catch LocationAccessError.denied {
        } catch {
            XCTFail("Expected denied, got \(error)")
        }
    }

    func testCancellingReverseGeocodeThrowsAndIgnoresTheLateResult() async throws {
        let geocoder = FakeGeocoder()
        let resolver = CoreLocationPlaceResolver(geocoder: geocoder)
        let coordinates = Coordinates(latitude: 31.2, longitude: 121.5)

        let task = Task {
            try await resolver.place(for: coordinates, fallbackName: "目前位置")
        }
        await geocoder.waitForRequest()
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
            XCTAssertEqual(geocoder.cancelCount, 1)
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }

        geocoder.finish(placemarks: [])

        let second = Task {
            try await resolver.place(for: coordinates, fallbackName: "目前位置")
        }
        await geocoder.waitForRequest(count: 2)
        geocoder.finish(placemarks: [])
        let resolved = try await second.value
        XCTAssertEqual(resolved.name, "目前位置")
        XCTAssertEqual(resolved.id, CoreLocationPlaceResolver.currentLocationID)
    }

    func testReverseGeocodeFailureStillReturnsTheFallbackName() async throws {
        let geocoder = FakeGeocoder()
        let resolver = CoreLocationPlaceResolver(geocoder: geocoder)

        let task = Task {
            try await resolver.place(
                for: Coordinates(latitude: 1, longitude: 2),
                fallbackName: "目前位置"
            )
        }
        await geocoder.waitForRequest()
        geocoder.finish(error: CLError(.network))

        let resolved = try await task.value
        XCTAssertEqual(resolved.name, "目前位置")
        XCTAssertEqual(resolved.latitude, 1, accuracy: 0.000_001)
    }
}

@MainActor
private final class FakeLocationManager: OneShotLocationManaging {
    var authorizationStatus: CLAuthorizationStatus
    weak var delegate: CLLocationManagerDelegate?
    private(set) var authorizationRequestCount = 0
    private(set) var locationRequestCount = 0
    private var authorizationWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private var locationWaiters: [(Int, CheckedContinuation<Void, Never>)] = []

    init(status: CLAuthorizationStatus) {
        authorizationStatus = status
    }

    func requestWhenInUseAuthorization() {
        authorizationRequestCount += 1
        resume(&authorizationWaiters, count: authorizationRequestCount)
    }

    func requestLocation() {
        locationRequestCount += 1
        resume(&locationWaiters, count: locationRequestCount)
    }

    func waitForAuthorizationRequest() async {
        if authorizationRequestCount >= 1 { return }
        await withCheckedContinuation { continuation in
            authorizationWaiters.append((1, continuation))
        }
    }

    func waitForLocationRequest(count: Int = 1) async {
        if locationRequestCount >= count { return }
        await withCheckedContinuation { continuation in
            locationWaiters.append((count, continuation))
        }
    }

    private func resume(_ waiters: inout [(Int, CheckedContinuation<Void, Never>)], count: Int) {
        let ready = waiters.filter { count >= $0.0 }
        waiters.removeAll { count >= $0.0 }
        ready.forEach { $0.1.resume() }
    }
}

@MainActor
private final class FakeGeocoder: ReverseGeocoding {
    private(set) var cancelCount = 0
    private var requestCount = 0
    private var completion: CLGeocodeCompletionHandler?
    private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []

    func reverseGeocodeLocation(
        _ location: CLLocation,
        completionHandler: @escaping CLGeocodeCompletionHandler
    ) {
        requestCount += 1
        completion = completionHandler
        let ready = waiters.filter { requestCount >= $0.0 }
        waiters.removeAll { requestCount >= $0.0 }
        ready.forEach { $0.1.resume() }
    }

    func cancelGeocode() {
        cancelCount += 1
    }

    func waitForRequest(count: Int = 1) async {
        if requestCount >= count { return }
        await withCheckedContinuation { continuation in
            waiters.append((count, continuation))
        }
    }

    func finish(placemarks: [CLPlacemark]) {
        let completion = self.completion
        self.completion = nil
        completion?(placemarks, nil)
    }

    func finish(error: Error) {
        let completion = self.completion
        self.completion = nil
        completion?(nil, error)
    }
}
