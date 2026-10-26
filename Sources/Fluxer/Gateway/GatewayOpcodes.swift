public enum GatewayOpcodes {
    public static let dispatch = 0
    public static let heartbeat = 1
    public static let identify = 2
    public static let presenceUpdate = 3
    public static let voiceStateUpdate = 4
    public static let voiceServerPing = 5
    public static let resume = 6
    public static let reconnect = 7
    public static let requestGuildMembers = 8
    public static let invalidSession = 9
    public static let hello = 10
    public static let heartbeatAck = 11
    public static let gatewayError = 12
    public static let voiceSignal = 13
    public static let lazyRequest = 14
    public static let requestGuildCounts = 15
    public static let requestChannelMemberCounts = 16
    public static let requestForumUnreads = 28
}
