import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

/// Fluxer REST API client (`https://fluxer.com/api/v1` by default)
public struct FluxerClient: Sendable {
    /// API base URL used by ``client``
    public let serverURL: URL

    /// Generated OpenAPI client for all HTTP operations
    public let client: Client

    /// Creates a client for the Fluxer API
    ///
    /// - Parameters:
    ///   - serverURL: API base URL including the version prefix (default production `/v1`).
    ///   - authorizationHeaderValue: Full `Authorization` header value, e.g. `Bearer <token>` or `Bot <token>`.
    ///   - transport: HTTP transport (defaults to `URLSessionTransport()`).
    ///   - middlewares: Additional client middleware applied after authorization.
    public init(
        serverURL: URL = FluxerClient.defaultServerURL,
        authorizationHeaderValue: String? = nil,
        transport: any ClientTransport = URLSessionTransport(),
        middlewares: [any ClientMiddleware] = []
    ) {
        var middlewares = middlewares
        if let authorizationHeaderValue {
            middlewares.insert(AuthorizationMiddleware(authorizationHeaderValue: authorizationHeaderValue), at: 0)
        }
        self.serverURL = serverURL
        self.client = Client(
            serverURL: serverURL,
            transport: transport,
            middlewares: middlewares
        )
    }

    public static let defaultServerURL = URL(string: "https://fluxer.com/api/v1")!

    public static func bearerAuthorization(token: String) -> String {
        "Bearer \(token)"
    }

    public static func botAuthorization(token: String) -> String {
        "Bot \(token)"
    }
}
