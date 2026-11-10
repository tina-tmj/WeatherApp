//
//  APIClientTests.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import XCTest
@testable import WeatherApp

/// 網路層測試全部走 MockURLProtocol，不連外網。
final class APIClientTests: XCTestCase {
    override func tearDown() {
        // 靜態 handler 會跨測試保留，每個用例結束都要清掉。
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testHTTP200DecodesJSON() async throws {
        let payload = Data(#"{"temperature":26.5}"#.utf8)
        MockURLProtocol.handler = { request in
            guard let url = request.url,
                  let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil) else {
                throw URLError(.badURL)
            }
            return (response, payload)
        }

        let decoded: TemperatureStub = try await makeClient().request(try makeEndpoint())

        XCTAssertEqual(decoded, TemperatureStub(temperature: 26.5))
    }

    func testHTTP404ThrowsHTTPError() async throws {
        MockURLProtocol.handler = httpHandler(statusCode: 404, data: Data())

        do {
            let _: TemperatureStub = try await makeClient().request(try makeEndpoint())
            XCTFail("Expected httpError")
        } catch let APIError.httpError(statusCode) {
            XCTAssertEqual(statusCode, 404)
        } catch {
            XCTFail("Expected httpError, got \(error)")
        }
    }

    func testHTTP500ThrowsHTTPError() async throws {
        MockURLProtocol.handler = httpHandler(statusCode: 500, data: Data("unavailable".utf8))

        do {
            let _: TemperatureStub = try await makeClient().request(try makeEndpoint())
            XCTFail("Expected httpError")
        } catch let APIError.httpError(statusCode) {
            XCTAssertEqual(statusCode, 500)
        } catch {
            XCTFail("Expected httpError, got \(error)")
        }
    }

    func testInvalidJSONThrowsDecodingError() async throws {
        MockURLProtocol.handler = httpHandler(statusCode: 200, data: Data("not-json".utf8))

        do {
            let _: TemperatureStub = try await makeClient().request(try makeEndpoint())
            XCTFail("Expected decodingError")
        } catch APIError.decodingError(_) {
        } catch {
            XCTFail("Expected decodingError, got \(error)")
        }
    }

    func testNonHTTPResponseThrowsInvalidResponse() async throws {
        MockURLProtocol.handler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            let response = URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
            return (response, Data())
        }

        do {
            let _: TemperatureStub = try await makeClient().request(try makeEndpoint())
            XCTFail("Expected invalidResponse")
        } catch APIError.invalidResponse {
        } catch {
            XCTFail("Expected invalidResponse, got \(error)")
        }
    }

    func testConnectionFailureThrowsTransportError() async throws {
        MockURLProtocol.handler = { _ in
            throw URLError(.cannotConnectToHost)
        }

        do {
            let _: TemperatureStub = try await makeClient().request(try makeEndpoint())
            XCTFail("Expected transportError")
        } catch let APIError.transportError(underlying) {
            XCTAssertEqual((underlying as? URLError)?.code, .cannotConnectToHost)
        } catch {
            XCTFail("Expected transportError, got \(error)")
        }
    }

    func testTimeoutThrowsTimeout() async throws {
        MockURLProtocol.handler = { _ in
            throw URLError(.timedOut)
        }

        do {
            let _: TemperatureStub = try await makeClient().request(try makeEndpoint())
            XCTFail("Expected timeout")
        } catch APIError.timeout {
        } catch {
            XCTFail("Expected timeout, got \(error)")
        }
    }

    func testCancellationErrorIsNotWrapped() async throws {
        MockURLProtocol.handler = { _ in
            throw CancellationError()
        }

        do {
            let _: TemperatureStub = try await makeClient().request(try makeEndpoint())
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }

    func testEndpointBuildsURLAndQueryItems() throws {
        let endpoint = SampleEndpoint(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.com")),
            path: "v1/search",
            queryItems: [
                URLQueryItem(name: "name", value: "Hong Kong"),
                URLQueryItem(name: "count", value: "5")
            ],
            headers: ["Accept": "application/json"]
        )

        let request = try endpoint.makeURLRequest()
        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))

        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "api.example.com")
        XCTAssertEqual(components.path, "/v1/search")
        XCTAssertEqual(
            components.queryItems,
            [
                URLQueryItem(name: "name", value: "Hong Kong"),
                URLQueryItem(name: "count", value: "5")
            ]
        )
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
    }

    func testEndpointAppendsPathToBasePath() throws {
        let endpoint = SampleEndpoint(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.com/v1/")),
            path: "/forecast"
        )

        let request = try endpoint.makeURLRequest()
        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))

        XCTAssertEqual(components.path, "/v1/forecast")
        XCTAssertNil(components.queryItems)
    }

    private func makeClient() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        configuration.urlCache = nil
        return APIClient(session: URLSession(configuration: configuration))
    }

    private func makeEndpoint() throws -> SampleEndpoint {
        SampleEndpoint(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.com")),
            path: "v1/forecast"
        )
    }

    private func httpHandler(statusCode: Int, data: Data) -> (URLRequest) throws -> (URLResponse, Data) {
        { request in
            guard let url = request.url,
                  let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil) else {
                throw URLError(.badURL)
            }
            return (response, data)
        }
    }
}

private struct SampleEndpoint: Endpoint {
    var baseURL: URL
    var path: String
    var method: HTTPMethod = .get
    var queryItems: [URLQueryItem] = []
    var headers: [String: String] = [:]
}

private struct TemperatureStub: Decodable, Equatable {
    let temperature: Double
}
