import Foundation
import os

public final class HeartbeatManager: @unchecked Sendable {
    private static let ackTimeout: Duration = .seconds(15)

    private let onSendHeartbeat: @Sendable () -> Void
    private let onTimeout: @Sendable () -> Void
    private let state = OSAllocatedUnfairLock(initialState: State())

    private struct State {
        var interval: Duration?
        var heartbeatTask: Task<Void, Never>?
        var ackTask: Task<Void, Never>?
        var waitingForAck = false
    }

    public init(
        onSendHeartbeat: @escaping @Sendable () -> Void,
        onTimeout: @escaping @Sendable () -> Void
    ) {
        self.onSendHeartbeat = onSendHeartbeat
        self.onTimeout = onTimeout
    }

    public func start(interval: Duration) {
        stop()
        state.withLock { $0.interval = interval }
        scheduleHeartbeat()
    }

    public func sendRequested() {
        state.withLock { $0.waitingForAck = true }
        onSendHeartbeat()
        startAckTimer()
        scheduleHeartbeat()
    }

    public func ackReceived() {
        state.withLock {
            $0.waitingForAck = false
            $0.ackTask?.cancel()
            $0.ackTask = nil
        }
    }

    public func stop() {
        state.withLock { current in
            current.heartbeatTask?.cancel()
            current.heartbeatTask = nil
            current.ackTask?.cancel()
            current.ackTask = nil
            current.interval = nil
            current.waitingForAck = false
        }
    }

    private func scheduleHeartbeat() {
        let interval = state.withLock { $0.interval }
        guard let interval else { return }

        state.withLock { $0.heartbeatTask?.cancel() }
        let delay = applyJitter(interval)
        let task = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.sendHeartbeatIfNeeded()
            self?.scheduleHeartbeat()
        }
        state.withLock { $0.heartbeatTask = task }
    }

    private func sendHeartbeatIfNeeded() {
        let waiting = state.withLock { $0.waitingForAck }
        if waiting {
            onTimeout()
            return
        }
        state.withLock { $0.waitingForAck = true }
        onSendHeartbeat()
        startAckTimer()
    }

    private func startAckTimer() {
        state.withLock { $0.ackTask?.cancel() }
        let task = Task { [weak self] in
            try? await Task.sleep(for: HeartbeatManager.ackTimeout)
            guard !Task.isCancelled else { return }
            let waiting = self?.state.withLock { $0.waitingForAck } ?? false
            if waiting {
                self?.onTimeout()
            }
        }
        state.withLock { $0.ackTask = task }
    }

    private func applyJitter(_ interval: Duration) -> Duration {
        let ms = Double(interval.components.seconds) * 1000
            + Double(interval.components.attoseconds) / 1e15
        let baseFraction = 0.80 + Double.random(in: 0...0.05)
        let jitterFraction = Double.random(in: 0...0.05)
        let total = ms * (baseFraction + jitterFraction)
        return .milliseconds(Int(total.rounded()))
    }
}
