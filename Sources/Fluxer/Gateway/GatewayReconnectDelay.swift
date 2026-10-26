import Foundation

public let gatewayMinReconnect: Duration = .milliseconds(1000)
public let gatewayMaxReconnect: Duration = .seconds(10)
public let gatewayReconnectSpreadMs = 2000
public let gatewayReconnectJitterFactor = 0.25
public let gatewayLivenessTimeout: Duration = .seconds(3)

public func gatewayReconnectDelay(attempt: Int, jitterUnit: Double) -> Duration {
    let step = attempt < 0 ? 0 : attempt
    let exponent = min(step, 16)
    let baseMs = min(1000 * (1 << exponent), Int(gatewayMaxReconnect.components.seconds * 1000))
    let unit = min(max(jitterUnit, 0), 1)
    let jitter = (unit * 2 - 1) * Double(baseMs) * gatewayReconnectJitterFactor
    let millis = Int((Double(baseMs) + jitter).rounded())
    let clamped = min(max(millis, Int(gatewayMinReconnect.components.seconds * 1000)), Int(gatewayMaxReconnect.components.seconds * 1000))
    return .milliseconds(clamped)
}

public func gatewayReconnectSpreadDelay(spreadUnit: Double) -> Duration {
    let unit = min(max(spreadUnit, 0), 1)
    let spread = Int((unit * Double(gatewayReconnectSpreadMs)).rounded(.down))
    return gatewayMinReconnect + .milliseconds(spread)
}

public func gatewayServerReconnectDelay(spreadUnit: Double) -> Duration {
    let unit = min(max(spreadUnit, 0), 1)
    let spread = Int((unit * Double(gatewayReconnectSpreadMs)).rounded(.down))
    return .milliseconds(spread)
}
