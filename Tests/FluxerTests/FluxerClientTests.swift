import Fluxer
import XCTest

final class FluxerClientTests: XCTestCase {
    func testDefaultServerURL() {
        XCTAssertEqual(FluxerClient.defaultServerURL.absoluteString, "https://api.fluxer.app/v1")
    }

    func testAuthorizationHeaderHelpers() {
        XCTAssertEqual(FluxerClient.bearerAuthorization(token: "abc"), "Bearer abc")
        XCTAssertEqual(FluxerClient.botAuthorization(token: "xyz"), "Bot xyz")
    }
}
