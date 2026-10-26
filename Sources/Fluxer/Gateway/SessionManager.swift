import Foundation

public final class SessionManager: @unchecked Sendable {
    public static let resumeWindow: Duration = .seconds(55)

    private let now: @Sendable () -> Date
    private let lock = NSLock()
    private var sessionId: String?
    private var lastSequence: Int?
    private var lastAckAt: Date?
    private var lastActivityAt: Date?

    public init(now: (@Sendable () -> Date)? = nil) {
        self.now = now ?? { Date() }
    }

    public var currentSessionId: String? {
        lock.lock()
        defer { lock.unlock() }
        return sessionId
    }

    public var currentLastSequence: Int? {
        lock.lock()
        defer { lock.unlock() }
        return lastSequence
    }

    public var currentLastAckAt: Date? {
        lock.lock()
        defer { lock.unlock() }
        return lastAckAt
    }

    public var canResume: Bool {
        lock.lock()
        defer { lock.unlock() }
        guard sessionId != nil, lastSequence != nil, let lastActivityAt else { return false }
        return now().timeIntervalSince(lastActivityAt) < SessionManager.resumeWindow.gatewayTimeInterval
    }

    public func updateSequence(_ sequence: Int?) {
        guard let sequence else { return }
        lock.lock()
        lastSequence = sequence
        lock.unlock()
    }

    public func setSession(_ sessionId: String) {
        lock.lock()
        self.sessionId = sessionId
        lock.unlock()
    }

    public func updateLastAck() {
        lock.lock()
        lastAckAt = now()
        lock.unlock()
    }

    public func noteActivity() {
        lock.lock()
        lastActivityAt = now()
        lock.unlock()
    }

    public func clear() {
        lock.lock()
        sessionId = nil
        lastSequence = nil
        lastAckAt = nil
        lastActivityAt = nil
        lock.unlock()
    }
}
