<p align="center">
  <img src="./media/logo-graphic.png" alt="Fluxer graphic logo" width="400">
</p>

<p align="center">
  <a href="https://fluxer.app/donate">
    <img src="https://img.shields.io/badge/Donate-fluxer.app%2Fdonate-brightgreen" alt="Donate" /></a>
  <a href="https://docs.fluxer.app">
    <img src="https://img.shields.io/badge/Docs-docs.fluxer.app-blue" alt="Documentation" /></a>
  <a href="./LICENSE">
    <img src="https://img.shields.io/badge/License-AGPLv3-purple" alt="AGPLv3 License" /></a>
</p>

# Fluxer Swift SDK

Swift package for the [Fluxer](https://fluxer.com) HTTP API. API types and the HTTP client are generated at build time from the Fluxer OpenAPI document using [Swift OpenAPI Generator](https://github.com/apple/swift-openapi-generator).

## Requirements

- Swift 6.0+
- macOS 13+, iOS 13+, or other [supported platforms](https://github.com/apple/swift-openapi-generator#supported-platforms-and-minimum-versions)

## Installation

Add the package dependency in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/fluxerapp/swift_sdk.git", from: "0.1.0"),
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "Fluxer", package: "swift_sdk"),
        ]
    ),
]
```

For local development, use a path dependency:

```swift
.package(path: "/path/to/swift_sdk"),
```

## Getting started

```swift
import Fluxer

let fluxer = FluxerClient(
    authorizationHeaderValue: FluxerClient.bearerAuthorization(token: sessionToken)
)

let response = try await fluxer.client.getCurrentUser()
let user = try response.ok.body.json
```

Self-hosted instances:

```swift
let fluxer = FluxerClient(
    serverURL: URL(string: "https://api.your-domain.com/v1")!,
    authorizationHeaderValue: FluxerClient.botAuthorization(token: botToken)
)
```

The default base URL is `https://fluxer.com/api/v1` (include the `/v1` prefix).

### Authentication

Pass the full `Authorization` header value. The SDK does not manage auth state.

```swift
FluxerClient.bearerAuthorization(token: sessionToken) // user session
FluxerClient.botAuthorization(token: botToken)          // bot
```

You can also construct `FluxerClient` without `authorizationHeaderValue` and add your own `ClientMiddleware`.

### Generated API

`FluxerClient.client` is the generated `Client` type. It exposes one `async` method per OpenAPI operation (for example `getCurrentUser()`, `listGuilds()`). Request and response models live under `Components.Schemas` in the `Fluxer` module.

## Gateway (WebSocket)

`GatewayConnection` connects to the Fluxer gateway with zstd-stream compression, heartbeat/resume, and typed dispatch events (`Components.Schemas` models via `EventParser`).

```swift
import Fluxer

let fluxer = FluxerClient(authorizationHeaderValue: FluxerClient.bearerAuthorization(token: token))
let gateway = GatewayConnection(token: token, fluxer: fluxer)

Task {
    for try await event in gateway.events() {
        // handle GatewayEvent
    }
}

await gateway.connect()
```

## License

AGPL-3.0 — see [LICENSE](./LICENSE).
