import Fluxer
import XCTest

final class GatewayReconnectDelayTests: XCTestCase {
    func testServerReconnectDelaySpreadsOverZeroToTwoSeconds() {
        XCTAssertEqual(gatewayServerReconnectDelay(spreadUnit: 0), .milliseconds(0))
        XCTAssertEqual(gatewayServerReconnectDelay(spreadUnit: 0.25), .milliseconds(500))
        XCTAssertEqual(gatewayServerReconnectDelay(spreadUnit: 1), .milliseconds(2000))
    }

    func testReconnectDelayClampsToMax() {
        let delay = gatewayReconnectDelay(attempt: 20, jitterUnit: 0.5)
        let delayMs = Int(delay.components.seconds) * 1000
        let maxMs = Int(gatewayMaxReconnect.components.seconds) * 1000
        XCTAssertLessThanOrEqual(delayMs, maxMs)
    }

    func testReconnectSpreadDelayIncludesMinReconnect() {
        let delay = gatewayReconnectSpreadDelay(spreadUnit: 0)
        XCTAssertEqual(delay, gatewayMinReconnect)
    }
}
