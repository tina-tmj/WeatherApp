//
//  MockURLProtocol.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import Foundation

/// 測試用的 URLProtocol。handler 回傳假的回應或丟出錯誤，請求不會真的送出網路。
/// URLSession 會在背景執行緒建立這個物件，所以 handler 用鎖保護。
final class MockURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var storedHandler: ((URLRequest) throws -> (URLResponse, Data))?

    /// 每個測試開始前指定，tearDown 時要清成 nil，避免下一個測試沿用舊回應。
    static var handler: ((URLRequest) throws -> (URLResponse, Data))? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedHandler
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            storedHandler = newValue
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            // 丟出的錯誤會回到 URLSession.data(for:)，再由 APIClient 分類。
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
