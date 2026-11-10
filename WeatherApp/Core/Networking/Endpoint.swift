//
//  Endpoint.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import Foundation

enum HTTPMethod: String {
    case get = "GET"
}

/// 描述一筆請求的最小資訊。具體 API 只要提供自己的欄位，不必再包一層 Request Builder。
protocol Endpoint {
    var baseURL: URL { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var queryItems: [URLQueryItem] { get }
    var headers: [String: String] { get }
}

extension Endpoint {
    var method: HTTPMethod { .get }
    var queryItems: [URLQueryItem] { [] }
    var headers: [String: String] { [:] }

    /// 把 baseURL、path、query 組成 URLRequest。
    /// path 前後的斜線會先去掉，再接到 baseURL 的路徑後面，避免出現重複的「//」，也不會把 baseURL 既有路徑蓋掉。
    func makeURLRequest() throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }

        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !trimmedPath.isEmpty {
            let basePath = components.path
            let normalizedBase: String
            if basePath.isEmpty || basePath == "/" {
                normalizedBase = ""
            } else if basePath.hasSuffix("/") {
                normalizedBase = String(basePath.dropLast())
            } else {
                normalizedBase = basePath
            }
            components.path = normalizedBase + "/" + trimmedPath
        }

        // 空陣列不要寫進 query，否則 URL 會多一個沒有意義的「?」。
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        return request
    }
}
