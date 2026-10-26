public enum GatewayCloseCode: Int, Sendable {
    case unknownError = 4000
    case unknownOpcode = 4001
    case decodeError = 4002
    case notAuthenticated = 4003
    case authenticationFailed = 4004
    case alreadyAuthenticated = 4005
    case invalidSequence = 4007
    case rateLimited = 4008
    case sessionTimedOut = 4009
    case invalidShard = 4010
    case shardingRequired = 4011
    case invalidApiVersion = 4012

    public var isFatal: Bool {
        switch self {
        case .authenticationFailed, .invalidShard, .shardingRequired, .invalidApiVersion:
            return true
        default:
            return false
        }
    }

    public static func fromCode(_ code: Int) -> GatewayCloseCode? {
        GatewayCloseCode(rawValue: code)
    }
}
