import Foundation
import os

public enum GatewayWebSocketMessage: Sendable {
    case text(String)
    case data(Data)
}

public protocol GatewayWebSocketTask: Sendable {
    var messages: AsyncStream<GatewayWebSocketMessage> { get async }
    var closeCode: Int? { get async }
    func send(text: String) async throws
    func send(data: Data) async throws
    func close(code: Int) async
}

public typealias GatewaySocketConnect = @Sendable (URL, [String: String]?) async throws -> any GatewayWebSocketTask

public enum GatewayWebSocketError: Error, CustomStringConvertible {
    case handshakeTimedOut(Duration)

    public var description: String {
        switch self {
        case .handshakeTimedOut(let timeout):
            return "Gateway WebSocket handshake timed out after \(timeout)"
        }
    }
}

public struct URLSessionGatewayWebSocket: Sendable {
    public static let defaultReadyTimeout: Duration = .seconds(20)

    public let session: URLSession
    public let readyTimeout: Duration

    public init(session: URLSession = .shared, readyTimeout: Duration = URLSessionGatewayWebSocket.defaultReadyTimeout) {
        self.session = session
        self.readyTimeout = readyTimeout
    }

    public func open(url: URL, headers: [String: String]?) async throws -> any GatewayWebSocketTask {
        var request = URLRequest(url: url)
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        let task = session.webSocketTask(with: request)
        task.resume()
        try await waitUntilReady(task: task)
        return URLSessionGatewayWebSocketTask(task: task)
    }

    private func waitUntilReady(task: URLSessionWebSocketTask) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await Task.sleep(for: readyTimeout)
                throw GatewayWebSocketError.handshakeTimedOut(readyTimeout)
            }
            group.addTask {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    task.sendPing { error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }
            }
            try await group.next()
            group.cancelAll()
        }
    }
}

public func openGatewayWebSocket(url: URL, headers: [String: String]?) async throws -> any GatewayWebSocketTask {
    try await URLSessionGatewayWebSocket().open(url: url, headers: headers)
}

final class URLSessionGatewayWebSocketTask: GatewayWebSocketTask, @unchecked Sendable {
    private let task: URLSessionWebSocketTask
    private let stream: AsyncStream<GatewayWebSocketMessage>
    private let continuation: AsyncStream<GatewayWebSocketMessage>.Continuation
    private let closeCodeState = OSAllocatedUnfairLock<Int?>(initialState: nil)
    private let receiveTask: Task<Void, Never>

    init(task: URLSessionWebSocketTask) {
        self.task = task
        var streamContinuation: AsyncStream<GatewayWebSocketMessage>.Continuation!
        self.stream = AsyncStream { streamContinuation = $0 }
        self.continuation = streamContinuation
        let closeCodeState = self.closeCodeState
        self.receiveTask = Task {
            while !Task.isCancelled {
                do {
                    let message = try await task.receive()
                    switch message {
                    case .string(let text):
                        streamContinuation.yield(.text(text))
                    case .data(let data):
                        streamContinuation.yield(.data(data))
                    @unknown default:
                        break
                    }
                } catch {
                    let code = task.closeCode.rawValue
                    closeCodeState.withLock { $0 = code }
                    streamContinuation.finish()
                    break
                }
            }
        }
    }

    var messages: AsyncStream<GatewayWebSocketMessage> {
        get async { stream }
    }

    var closeCode: Int? {
        get async {
            if let stored = closeCodeState.withLock({ $0 }) { return stored }
            let code = task.closeCode.rawValue
            return code == 0 ? nil : code
        }
    }

    func send(text: String) async throws {
        try await task.send(.string(text))
    }

    func send(data: Data) async throws {
        try await task.send(.data(data))
    }

    func close(code: Int) async {
        let closeCode = URLSessionWebSocketTask.CloseCode(rawValue: code) ?? .goingAway
        task.cancel(with: closeCode, reason: nil)
        receiveTask.cancel()
        continuation.finish()
    }
}
