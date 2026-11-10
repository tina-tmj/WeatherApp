//
//  CancellableWait.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import Foundation

/// 同一時間只保留一個等待。授權、定位、反查地名都用它。
/// 新的等待會先取消舊的。取消和回呼都走 `resume`，只會 resume 一次。
@MainActor
final class CancellableWait<Success> {
    private var generation = 0
    private var continuation: CheckedContinuation<Success, Error>?

    /// `start` 在等待建立後呼叫。任務取消時先執行 `onCancel`，再用 CancellationError 結束這一次。
    func wait(
        onCancel: @escaping @MainActor () -> Void = {},
        start: @escaping @MainActor (_ generation: Int) -> Void
    ) async throws -> Success {
        generation += 1
        let generation = generation
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                resume(.failure(CancellationError()))
                self.continuation = continuation
                if Task.isCancelled {
                    resume(.failure(CancellationError()))
                    return
                }
                start(generation)
            }
        } onCancel: { [weak self] in
            Task { @MainActor in
                guard let self, self.generation == generation else { return }
                onCancel()
                self.resume(.failure(CancellationError()))
            }
        }
    }

    /// `matching` 有值時，只接受同一個序号的回呼，避免舊請求寫進新的等待。
    func resume(_ result: Result<Success, Error>, matching generation: Int? = nil) {
        if let generation, generation != self.generation { return }
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }
}
