import Foundation
import HTTPTypes
import OpenAPIRuntime

public struct AuthorizationMiddleware: ClientMiddleware {
    private let value: String

    public init(authorizationHeaderValue value: String) {
        self.value = value
    }

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[.authorization] = value
        return try await next(request, body, baseURL)
    }
}
