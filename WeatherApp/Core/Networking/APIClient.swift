//
//  APIClient.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import Foundation

/// 通用請求入口。只負責送出請求、檢查 HTTP 與解碼 JSON，不包含任何天氣欄位。
protocol APIClientProtocol: AnyObject {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
}

final class APIClient: APIClientProtocol {
    private let session: URLSession
    private let decoder: JSONDecoder

    /// decoder 保持呼叫端傳入的設定。這裡不開啟 convertFromSnakeCase，欄位對應交給各個 DTO 的 CodingKeys。
    init(session: URLSession = .shared, decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.decoder = decoder
    }

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let urlRequest = try endpoint.makeURLRequest()
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let error as APIError {
            throw error
        } catch {
            // 取消必須先判斷，避免被包成 transportError，讓上層的 Task 取消失效。
            try rethrowCancellation(error)
            if let urlError = error as? URLError, urlError.code == .timedOut {
                throw APIError.timeout
            }
            throw APIError.transportError(error)
        }

        // 狀態碼不成功時直接失敗，不再嘗試解碼錯誤頁面。
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw APIError.decodingError(error)
        }
    }

    /// URLSession 有時會把 CancellationError 橋接成 NSError，Swift 的 `as? CancellationError` 會失敗。
    /// 這裡同時辨認橋接後的 domain，以及 URLError.cancelled，再把原始取消語意丟回去。
    private func rethrowCancellation(_ error: Error) throws {
        if error is CancellationError {
            throw CancellationError()
        }
        let nsError = error as NSError
        let cancellationDomain = (CancellationError() as NSError).domain
        if nsError.domain == cancellationDomain || (nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled) {
            throw CancellationError()
        }
    }
}
