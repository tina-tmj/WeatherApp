//
//  APIError.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import Foundation

/// 網路層對外拋出的錯誤。每種 case 對應一種失敗原因，方便上層分別處理。
enum APIError: Error {
    /// baseURL 與 path 無法組成合法 URL。
    case invalidURL
    /// 回應不是 HTTP 回應，例如收到一般的 URLResponse。
    case invalidResponse
    /// HTTP 狀態碼不是 2xx。statusCode 保留實際狀態碼，例如 404、500。
    case httpError(statusCode: Int)
    /// HTTP 成功，但 JSON 無法解成目標型別。
    case decodingError(Error)
    /// 連線失敗、DNS 失敗等傳輸錯誤。不包含取消與逾時。
    case transportError(Error)
    /// 請求逾時，對應 URLError.timedOut。
    case timeout
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The request URL is invalid."
        case .invalidResponse:
            return "The server response was not a valid HTTP response."
        case let .httpError(statusCode):
            return "The server returned HTTP \(statusCode)."
        case .decodingError:
            return "The response could not be decoded."
        case .transportError:
            return "The network connection failed."
        case .timeout:
            return "The request timed out."
        }
    }
}
