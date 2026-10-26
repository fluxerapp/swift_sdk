import Foundation
import OpenAPIRuntime

public struct GatewayCompressionStats: Sendable {
    public var frames: Int
    public var wireBytes: Int
    public var decompressedBytes: Int
    public var compressionNegotiated: Bool
}

public actor GatewayConnection {
    public static let webSocketReadyTimeout: Duration = .seconds(20)

    private var token: String
    private let fluxer: FluxerClient
    private let gatewayURLOverride: String?
    private let initialGuildId: String?
    private let flags: Int
    private let traceAsync: (@Sendable (String, @Sendable () async throws -> Void) async throws -> Void)?
    private let traceSync: (@Sendable (String, @Sendable () -> Void) -> Void)?
    private let compress: String
    private let maxDecompressedMessageSize: Int
    private var properties: GatewayIdentifyProperties
    private var presence: GatewayPresence?
    private let nextJitter: @Sendable () -> Double
    private let openSocket: GatewaySocketConnect
    private let resumeResponseTimeout: Duration
    private let now: @Sendable () -> Date

    private let eventParser = EventParser()
    private let session = SessionManager()
    private var heartbeat: HeartbeatManager?

    private var socket: (any GatewayWebSocketTask)?
    private var receiveTask: Task<Void, Never>?
    private var zstdDecoder: ZstdStreamDecoder?
    private var zstdEncoder: ZstdStreamEncoder?
    private var handlingDecodeFailure = false

    private var eventContinuations: [UUID: AsyncThrowingStream<any GatewayEvent, Error>.Continuation] = [:]
    private var stateContinuations: [UUID: AsyncStream<GatewayState>.Continuation] = [:]

    private var state: GatewayState = .disconnected
    private var reconnectAttempts = 0
    private var disposed = false
    private var reconnectSuspended = false
    private var reconnectThrottledByServer = false
    private var gatewayURL: String?
    private var reconnectTask: Task<Void, Never>?
    private var invalidSessionTask: Task<Void, Never>?
    private var resumeTask: Task<Void, Never>?
    private var livenessAck: CheckedContinuation<Void, Never>?
    private var connectInFlight: (id: UUID, task: Task<Void, Never>)?
    private var lastReconnectScheduledAt: Date?
    private var connectGeneration = 0
    private var lastHeartbeatInterval: Duration?
    private var connectedAt: Date?
    private var readyLatitude: String?
    private var readyLongitude: String?
    private var consecutiveDecodeFailureReconnects = 0
    private var disableCompressionForNextConnection = false
    private var activeCompress: String = "zstd-stream"
    private var compressedFrames = 0
    private var compressedWireBytes = 0
    private var decompressedBytes = 0
    private var firstFrameSeen = false
    private var compressionNegotiated = false

    public init(
        token: String,
        fluxer: FluxerClient,
        gatewayURL: String? = nil,
        properties: GatewayIdentifyProperties? = nil,
        presence: GatewayPresence? = nil,
        compress: String = "zstd-stream",
        maxDecompressedMessageSize: Int = ZstdStreamDecoder.defaultMaxDecompressedMessageSize,
        initialGuildId: String? = nil,
        flags: Int = 0,
        traceAsync: (@Sendable (String, @Sendable () async throws -> Void) async throws -> Void)? = nil,
        traceSync: (@Sendable (String, @Sendable () -> Void) -> Void)? = nil,
        nextJitter: (@Sendable () -> Double)? = nil,
        openSocket: GatewaySocketConnect? = nil,
        resumeResponseTimeout: Duration = .seconds(15),
        now: (@Sendable () -> Date)? = nil
    ) {
        self.token = token
        self.fluxer = fluxer
        self.gatewayURLOverride = gatewayURL
        self.initialGuildId = initialGuildId
        self.flags = flags
        self.traceAsync = traceAsync
        self.traceSync = traceSync
        self.compress = compress
        self.maxDecompressedMessageSize = maxDecompressedMessageSize
        self.properties = properties ?? GatewayIdentifyProperties(
            os: "linux",
            browser: "fluxeron",
            device: "fluxer_swift"
        )
        self.presence = presence
        self.nextJitter = nextJitter ?? { Double.random(in: 0..<1) }
        self.openSocket = openSocket ?? { url, headers in
            try await openGatewayWebSocket(url: url, headers: headers)
        }
        self.resumeResponseTimeout = resumeResponseTimeout
        self.now = now ?? { Date() }
    }

    public var currentState: GatewayState { state }
    public var isReconnectSuspended: Bool { reconnectSuspended }
    public var lastAckAt: Date? { session.currentLastAckAt }
    public var sessionId: String? { session.currentSessionId }

    public var compressionStats: GatewayCompressionStats {
        GatewayCompressionStats(
            frames: compressedFrames,
            wireBytes: compressedWireBytes,
            decompressedBytes: decompressedBytes,
            compressionNegotiated: compressionNegotiated
        )
    }

    public var isLikelyStale: Bool {
        Self.computeIsLikelyStale(
            lastAckAt: session.currentLastAckAt,
            heartbeatInterval: lastHeartbeatInterval,
            connectedAt: connectedAt,
            now: now()
        )
    }

    public static func computeIsLikelyStale(
        lastAckAt: Date?,
        heartbeatInterval: Duration?,
        connectedAt: Date?,
        now: Date
    ) -> Bool {
        guard let heartbeatInterval else { return false }
        let staleAfter = heartbeatInterval + .seconds(15)
        if let lastAckAt {
            return now.timeIntervalSince(lastAckAt) > staleAfter.gatewayTimeInterval
        }
        guard let connectedAt else { return false }
        return now.timeIntervalSince(connectedAt) > staleAfter.gatewayTimeInterval
    }

    public func events() -> AsyncThrowingStream<any GatewayEvent, Error> {
        AsyncThrowingStream { continuation in
            let id = UUID()
            eventContinuations[id] = continuation
            continuation.onTermination = { @Sendable _ in
                Task { await self.removeEventContinuation(id) }
            }
        }
    }

    public func stateChanges() -> AsyncStream<GatewayState> {
        AsyncStream { continuation in
            let id = UUID()
            stateContinuations[id] = continuation
            continuation.yield(state)
            continuation.onTermination = { @Sendable _ in
                Task { await self.removeStateContinuation(id) }
            }
        }
    }

    private func removeEventContinuation(_ id: UUID) {
        eventContinuations[id] = nil
    }

    private func removeStateContinuation(_ id: UUID) {
        stateContinuations[id] = nil
    }

    public func connect() async {
        if disposed || reconnectSuspended { return }
        if let inFlight = connectInFlight {
            await inFlight.task.value
            return
        }
        let flightID = UUID()
        let task = Task { await openConnection() }
        connectInFlight = (flightID, task)
        await task.value
        if connectInFlight?.id == flightID {
            connectInFlight = nil
        }
    }

    private func openConnection() async {
        connectGeneration += 1
        let generation = connectGeneration
        cancelReconnectTimer()
        await tearDownSocket()
        if disposed || generation != connectGeneration { return }
        setState(.connecting)
        if heartbeat == nil {
            heartbeat = HeartbeatManager(
                onSendHeartbeat: { Task { await self.sendHeartbeat() } },
                onTimeout: { Task { await self.closeAndReconnect() } }
            )
        }
        do {
            if let traceAsync {
                try await traceAsync("gateway.ws.open") {}
            }
            try await performWebSocketOpen(generation: generation)
        } catch {
            if generation != connectGeneration { return }
            setState(.disconnected)
            scheduleReconnect()
        }
    }

    public func reconnectNow() async {
        if disposed { return }
        if let inFlight = connectInFlight {
            await inFlight.task.value
            return
        }
        if reconnectThrottledByServer && reconnectTask != nil { return }
        reconnectAttempts = 0
        connectGeneration += 1
        cancelReconnectTimer()
        await tearDownSocket()
        if state == .failed {
            setState(.disconnected)
        }
        if disposed { return }
        await connect()
    }

    public func disconnect() async {
        cancelReconnectTimer()
        reconnectAttempts = 0
        await closeTransport()
        setState(.disconnected)
    }

    public func suspend() async {
        if disposed { return }
        reconnectSuspended = true
        cancelReconnectTimer()
        reconnectAttempts = 0
        await closeTransport()
        setState(.disconnected)
    }

    public func unsuspendAndReconnect() async {
        if disposed { return }
        reconnectSuspended = false
        await reconnectNow()
    }

    public func dispose() async {
        disposed = true
        cancelReconnectTimer()
        await disconnect()
        for continuation in eventContinuations.values {
            continuation.finish()
        }
        eventContinuations.removeAll()
        for continuation in stateContinuations.values {
            continuation.finish()
        }
        stateContinuations.removeAll()
    }

    public func verifyLiveness(timeout: Duration = gatewayLivenessTimeout) async -> Bool {
        guard !disposed, state == .connected, socket != nil, heartbeat != nil else { return false }
        let lived = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                try? await Task.sleep(for: timeout)
                return false
            }
            group.addTask {
                await self.waitForLivenessAck()
                return true
            }
            let result = await group.next() ?? false
            group.cancelAll()
            return result
        }
        if !lived {
            livenessAck?.resume()
            livenessAck = nil
            if state == .connected {
                await reconnectNow()
            }
        }
        return lived
    }

    private func waitForLivenessAck() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            livenessAck = continuation
            heartbeat?.sendRequested()
        }
    }

    private func performWebSocketOpen(generation: Int) async throws {
        if let gatewayURLOverride {
            gatewayURL = gatewayURLOverride
        } else {
            gatewayURL = try await fetchGatewayURL()
        }
        if generation != connectGeneration { return }
        try await openWebSocket(url: gatewayURL!, generation: generation)
    }

    public func updatePresence(_ presence: GatewayPresence) {
        self.presence = presence
        guard state == .connected, socket != nil else { return }
        send(["op": GatewayOpcodes.presenceUpdate, "d": presence.toJSON()])
    }

    public func sendLazyRequest(subscriptions: [String: LazyRequestSubscription]) {
        guard state == .connected, socket != nil else { return }
        var mapped: [String: Any] = [:]
        for (key, value) in subscriptions {
            mapped[key] = value.toJSON()
        }
        send(["op": GatewayOpcodes.lazyRequest, "d": ["subscriptions": mapped]])
    }

    public func requestGuildMembers(
        guildId: String? = nil,
        guildIds: [String]? = nil,
        query: String? = nil,
        limit: Int? = nil,
        userIds: [String]? = nil,
        presences: Bool? = nil,
        nonce: String? = nil
    ) {
        guard state == .connected, socket != nil else { return }
        let resolved = guildIds?.filter { !$0.isEmpty } ?? []
        var d: [String: Any] = [:]
        if !resolved.isEmpty {
            d["guild_ids"] = Array(Set(resolved))
        } else if let guildId, !guildId.isEmpty {
            d["guild_id"] = guildId
        } else {
            return
        }
        if let query { d["query"] = query }
        if let limit { d["limit"] = limit }
        if let userIds, !userIds.isEmpty { d["user_ids"] = Array(Set(userIds)) }
        if let presences { d["presences"] = presences }
        if let nonce { d["nonce"] = nonce }
        send(["op": GatewayOpcodes.requestGuildMembers, "d": d])
    }

    public func setToken(_ token: String) {
        if token.isEmpty { return }
        self.token = token
    }

    public func requestGuildCounts(guildIds: [String]) {
        guard state == .connected, socket != nil else { return }
        let unique = Array(Set(guildIds.filter { !$0.isEmpty }))
        if unique.isEmpty { return }
        send(["op": GatewayOpcodes.requestGuildCounts, "d": ["guild_ids": unique]])
    }

    public func requestChannelMemberCounts(guildId: String, channelIds: [String], nonce: String? = nil) {
        guard state == .connected, socket != nil, !guildId.isEmpty else { return }
        let unique = Array(Set(channelIds.filter { !$0.isEmpty }))
        if unique.isEmpty { return }
        var d: [String: Any] = ["guild_id": guildId, "channel_ids": unique]
        if let nonce { d["nonce"] = nonce }
        send(["op": GatewayOpcodes.requestChannelMemberCounts, "d": d])
    }

    public func requestForumUnreads(guildId: String, channelId: String, ackMessageIds: [String: String]) {
        guard state == .connected, socket != nil else { return }
        if guildId.isEmpty || channelId.isEmpty || ackMessageIds.isEmpty { return }
        let threads: [[String: String]] = ackMessageIds.map { threadId, ack in
            ["thread_id": threadId, "ack_message_id": ack]
        }
        send([
            "op": GatewayOpcodes.requestForumUnreads,
            "d": ["guild_id": guildId, "channel_id": channelId, "threads": threads],
        ])
    }

    public func updateVoiceState(_ update: GatewayVoiceStateUpdate) -> Bool {
        guard state == .connected, socket != nil else { return false }
        var data = update.toJSON()
        if let readyLatitude, data["latitude"] == nil { data["latitude"] = readyLatitude }
        if let readyLongitude, data["longitude"] == nil { data["longitude"] = readyLongitude }
        send(["op": GatewayOpcodes.voiceStateUpdate, "d": data])
        return true
    }

    public func sendVoiceSignal(
        guildId: String?,
        channelId: String,
        to: String,
        data: [String: Any]
    ) -> Bool {
        guard state == .connected, socket != nil else { return false }
        send([
            "op": GatewayOpcodes.voiceSignal,
            "d": [
                "guild_id": guildId as Any,
                "channel_id": channelId,
                "to": to,
                "data": data,
            ],
        ])
        return true
    }

    public func handleSocketClosedForTest(closeCode: Int?) {
        onSocketClosed(closeCode: closeCode)
    }

    private func fetchGatewayURL() async throws -> String {
        let base = fluxer.serverURL
        if let host = base.host, !host.isEmpty {
            let gatewayHost = host.replacingOccurrences(of: "api.", with: "gateway.")
            return "wss://\(gatewayHost)"
        }
        let response = try await fluxer.client.getGatewayBot()
        switch response {
        case .ok(let ok):
            return try ok.body.json.url
        default:
            throw GatewayConnectionError.gatewayBotFailed(-1)
        }
    }

    private func openWebSocket(url: String, generation: Int) async throws {
        let disableCompression = disableCompressionForNextConnection
        disableCompressionForNextConnection = false
        activeCompress = disableCompression ? "none" : compress
        handlingDecodeFailure = false
        compressedFrames = 0
        compressedWireBytes = 0
        decompressedBytes = 0
        firstFrameSeen = false
        compressionNegotiated = false
        zstdDecoder?.dispose()
        zstdDecoder = activeCompress == "zstd-stream"
            ? ZstdStreamDecoder(maxDecompressedMessageSize: maxDecompressedMessageSize)
            : nil
        zstdEncoder?.dispose()
        zstdEncoder = activeCompress == "zstd-stream" ? ZstdStreamEncoder() : nil

        let streamQuery = activeCompress == "zstd-stream" ? "&stream=1" : ""
        let wsURL = URL(string: "\(url)?v=1&encoding=json&compress=\(activeCompress)\(streamQuery)")!
        let socket = try await openSocket(wsURL, webSocketHeaders())
        if generation != connectGeneration {
            await tearDownSocket()
            return
        }
        self.socket = socket
        receiveTask = Task {
            let messages = await socket.messages
            for await message in messages {
                await self.onMessage(message)
            }
            let closeCode = await socket.closeCode
            self.onSocketClosed(closeCode: closeCode)
        }
    }

    private func onMessage(_ raw: GatewayWebSocketMessage) async {
        let payload: [String: Any]
        do {
            switch raw {
            case .data(let data):
                recordFirstFrameType(compressed: true)
                compressedFrames += 1
                compressedWireBytes += data.count
                guard let decoder = zstdDecoder else {
                    await handleDecodeFailure(ZstdStreamException("Received compressed data without a streaming decoder"))
                    return
                }
                let decompressed = try decoder.feed(data)
                decompressedBytes += decompressed.count
                guard let jsonString = String(data: decompressed, encoding: .utf8),
                      let object = try JSONSerialization.jsonObject(with: Data(jsonString.utf8)) as? [String: Any]
                else { return }
                payload = object
            case .text(let string):
                recordFirstFrameType(compressed: false)
                guard let object = try JSONSerialization.jsonObject(with: Data(string.utf8)) as? [String: Any] else {
                    return
                }
                payload = object
            }
        } catch let error as ZstdException {
            await handleDecodeFailure(error)
            return
        } catch {
            reportError(error)
            return
        }

        guard let op = payload["op"] as? Int else { return }
        let d = payload["d"]
        let s = payload["s"] as? Int
        let t = payload["t"] as? String

        if op != GatewayOpcodes.hello {
            session.noteActivity()
        }
        session.updateSequence(s)

        switch op {
        case GatewayOpcodes.hello:
            if let hello = d as? [String: Any] { handleHello(hello) }
        case GatewayOpcodes.heartbeatAck:
            heartbeat?.ackReceived()
            session.updateLastAck()
            livenessAck?.resume()
            livenessAck = nil
        case GatewayOpcodes.dispatch:
            if let t {
                if let map = d as? [String: Any] {
                    handleDispatch(eventType: t, data: map)
                } else if let list = d as? [Any] {
                    handleListDispatch(eventType: t, data: list)
                }
            }
        case GatewayOpcodes.heartbeat:
            heartbeat?.sendRequested()
        case GatewayOpcodes.reconnect:
            handleReconnect()
        case GatewayOpcodes.invalidSession:
            let resumable = d as? Bool ?? false
            handleInvalidSession(resumable: resumable)
        case GatewayOpcodes.gatewayError:
            if let map = d as? [String: Any] { handleGatewayError(map) }
        default:
            break
        }
    }

    private func recordFirstFrameType(compressed: Bool) {
        if firstFrameSeen { return }
        firstFrameSeen = true
        compressionNegotiated = compressed
    }

    private func handleDecodeFailure(_ error: Error) async {
        if handlingDecodeFailure || disposed { return }
        handlingDecodeFailure = true
        reportError(error)
        consecutiveDecodeFailureReconnects += 1
        if consecutiveDecodeFailureReconnects >= 2 {
            disableCompressionForNextConnection = true
            consecutiveDecodeFailureReconnects = 0
        }
        await tearDownSocket()
        scheduleReconnect()
    }

    private func reportError(_ error: Error) {
        for continuation in eventContinuations.values {
            continuation.yield(with: .failure(error))
        }
    }

    private func onSocketClosed(closeCode: Int?) {
        let resumeWasPending = resumeTask != nil
        cancelResumeTimer()
        heartbeat?.stop()
        if resumeWasPending {
            session.clear()
        }
        reconnectThrottledByServer = closeCode == GatewayCloseCode.rateLimited.rawValue
        if let closeCode {
            if let code = GatewayCloseCode.fromCode(closeCode), code.isFatal {
                session.clear()
                cancelReconnectTimer()
                setState(.failed)
                return
            }
            if closeCode == GatewayCloseCode.invalidSequence.rawValue {
                session.clear()
            }
        }
        if !disposed {
            scheduleReconnect()
        }
    }

    private func handleHello(_ data: [String: Any]) {
        guard let intervalMs = GatewayDecoding.int(data, key: "heartbeat_interval") else { return }
        lastHeartbeatInterval = .milliseconds(intervalMs)
        heartbeat?.start(interval: .milliseconds(intervalMs))
        if session.canResume {
            sendResume()
        } else {
            session.clear()
            sendIdentify()
        }
    }

    private func handleDispatch(eventType: String, data: [String: Any]) {
        if eventType == "READY" || eventType == "RESUMED" {
            consecutiveDecodeFailureReconnects = 0
        }
        if eventType == "READY" {
            if let sessionId = data["session_id"] as? String {
                session.setSession(sessionId)
            }
            readyLatitude = data["latitude"] as? String
            readyLongitude = data["longitude"] as? String
            reconnectAttempts = 0
            connectedAt = now()
            setState(.connected)
        } else if eventType == "RESUMED" {
            cancelResumeTimer()
            reconnectAttempts = 0
            connectedAt = now()
            setState(.connected)
        }
        let event = eventParser.parse(eventType: eventType, data: data)
        for continuation in eventContinuations.values {
            continuation.yield(event)
        }
    }

    private func handleListDispatch(eventType: String, data: [Any]) {
        guard let event = eventParser.parseList(eventType: eventType, data: data) else { return }
        for continuation in eventContinuations.values {
            continuation.yield(event)
        }
    }

    private func handleReconnect() {
        Task { await closeAndReconnect(serverRequested: true) }
    }

    private func handleInvalidSession(resumable: Bool) {
        cancelResumeTimer()
        if !resumable {
            session.clear()
        }
        invalidSessionTask?.cancel()
        let jitterMs = Int((nextJitter() * 1000).rounded())
        let delay = Duration.milliseconds(2500 + jitterMs)
        invalidSessionTask = Task {
            try? await Task.sleep(for: delay)
            if disposed { return }
            await closeAndReconnect(serverRequested: true)
        }
    }

    private func handleGatewayError(_ data: [String: Any]) {
        let rawCode = data["code"]
        let code: String
        if let stringCode = rawCode as? String {
            code = stringCode
        } else if let rawCode {
            code = String(describing: rawCode)
        } else {
            code = "unknown"
        }
        let message = GatewayDecoding.string(data, key: "message") ?? ""
        let event = GatewayErrorEvent(code: code, message: message)
        for continuation in eventContinuations.values {
            continuation.yield(event)
        }
    }

    private func sendIdentify() {
        var payload: [String: Any] = [
            "token": token,
            "properties": properties.toJSON(),
            "compress": activeCompress,
        ]
        if let presence { payload["presence"] = presence.toJSON() }
        if flags != 0 { payload["flags"] = flags }
        if let initialGuildId, !initialGuildId.isEmpty {
            payload["initial_guild_id"] = initialGuildId
        }
        if let traceSync {
            traceSync("gateway.identify") {}
        }
        send(["op": GatewayOpcodes.identify, "d": payload])
    }

    private func sendResume() {
        send([
            "op": GatewayOpcodes.resume,
            "d": [
                "token": token,
                "session_id": session.currentSessionId as Any,
                "seq": session.currentLastSequence as Any,
            ],
        ])
        cancelResumeTimer()
        resumeTask = Task {
            try? await Task.sleep(for: resumeResponseTimeout)
            onResumeTimeout()
        }
    }

    private func onResumeTimeout() {
        resumeTask = nil
        if disposed { return }
        session.clear()
        Task { await closeAndReconnect() }
    }

    private func cancelResumeTimer() {
        resumeTask?.cancel()
        resumeTask = nil
    }

    private func sendHeartbeat() {
        send(["op": GatewayOpcodes.heartbeat, "d": session.currentLastSequence as Any])
    }

    private func send(_ payload: [String: Any]) {
        guard let socket else { return }
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: jsonData, encoding: .utf8)
        else { return }

        Task {
            do {
                if activeCompress == "zstd-stream" {
                    guard let encoder = zstdEncoder else { return }
                    let bytes = Data(jsonString.utf8)
                    let compressed = try encoder.compress(bytes)
                    try await socket.send(data: compressed)
                } else {
                    try await socket.send(text: jsonString)
                }
            } catch {}
        }
    }

    private func closeAndReconnect(serverRequested: Bool = false) async {
        await tearDownSocket()
        scheduleReconnect(serverRequested: serverRequested)
    }

    private func closeTransport() async {
        cancelResumeTimer()
        heartbeat?.stop()
        receiveTask?.cancel()
        receiveTask = nil
        if let socket {
            await socket.close(code: 1000)
        }
        socket = nil
        zstdDecoder?.dispose()
        zstdDecoder = nil
        zstdEncoder?.dispose()
        zstdEncoder = nil
        session.clear()
        connectedAt = nil
    }

    private func tearDownSocket() async {
        cancelResumeTimer()
        heartbeat?.stop()
        receiveTask?.cancel()
        receiveTask = nil
        zstdDecoder?.dispose()
        zstdDecoder = nil
        zstdEncoder?.dispose()
        zstdEncoder = nil
        let currentSocket = socket
        socket = nil
        guard let currentSocket else { return }
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await currentSocket.close(code: 4000)
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(3))
            }
            await group.next()
            group.cancelAll()
        }
    }

    private func cancelReconnectTimer() {
        reconnectTask?.cancel()
        reconnectTask = nil
        invalidSessionTask?.cancel()
        invalidSessionTask = nil
    }

    private func scheduleReconnect(serverRequested: Bool = false) {
        if disposed || reconnectSuspended { return }
        if reconnectTask != nil { return }
        invalidSessionTask?.cancel()
        invalidSessionTask = nil
        setState(.reconnecting)
        let currentTime = now()
        let delay: Duration
        if serverRequested {
            delay = gatewayServerReconnectDelay(spreadUnit: nextJitter())
        } else if let last = lastReconnectScheduledAt,
                  currentTime.timeIntervalSince(last) < gatewayMinReconnect.gatewayTimeInterval
        {
            delay = gatewayReconnectSpreadDelay(spreadUnit: nextJitter())
        } else {
            lastReconnectScheduledAt = currentTime
            delay = gatewayReconnectDelay(attempt: reconnectAttempts, jitterUnit: nextJitter())
            reconnectAttempts += 1
        }
        reconnectTask = Task {
            try? await Task.sleep(for: delay)
            reconnectTask = nil
            reconnectThrottledByServer = false
            if !disposed && !reconnectSuspended {
                await connect()
            }
        }
    }

    private func setState(_ newState: GatewayState) {
        if state == newState { return }
        state = newState
        for continuation in stateContinuations.values {
            continuation.yield(newState)
        }
    }

    private func webSocketHeaders() -> [String: String]? {
        if let userAgent = trimmedHeader(properties.userAgent) {
            return ["User-Agent": userAgent]
        }
        return nil
    }

    private func trimmedHeader(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

}

public enum GatewayConnectionError: Error {
    case gatewayBotFailed(Int)
}
