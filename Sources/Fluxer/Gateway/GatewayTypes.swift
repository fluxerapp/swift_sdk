import Foundation

public enum GatewayState: Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case failed
}

public struct GatewayIdentifyProperties: Sendable {
    public var os: String
    public var browser: String
    public var device: String
    public var osVersion: String?
    public var locale: String?
    public var systemLocale: String?
    public var browserVersion: String?
    public var buildTimestamp: String?
    public var buildVersion: String?
    public var buildNumber: Int?
    public var betaNumber: Int?
    public var userAgent: String?
    public var releaseChannel: String?
    public var clientPlatform: String?
    public var clientRuntime: String?
    public var desktopAppVersion: String?
    public var desktopAppChannel: String?
    public var desktopArch: String?
    public var desktopOs: String?
    public var e2eeCapable: Bool?
    public var mobile: Bool?

    public init(
        os: String,
        browser: String,
        device: String,
        osVersion: String? = nil,
        locale: String? = nil,
        systemLocale: String? = nil,
        browserVersion: String? = nil,
        buildTimestamp: String? = nil,
        buildVersion: String? = nil,
        buildNumber: Int? = nil,
        betaNumber: Int? = nil,
        userAgent: String? = nil,
        releaseChannel: String? = nil,
        clientPlatform: String? = nil,
        clientRuntime: String? = nil,
        desktopAppVersion: String? = nil,
        desktopAppChannel: String? = nil,
        desktopArch: String? = nil,
        desktopOs: String? = nil,
        e2eeCapable: Bool? = nil,
        mobile: Bool? = nil
    ) {
        self.os = os
        self.browser = browser
        self.device = device
        self.osVersion = osVersion
        self.locale = locale
        self.systemLocale = systemLocale
        self.browserVersion = browserVersion
        self.buildTimestamp = buildTimestamp
        self.buildVersion = buildVersion
        self.buildNumber = buildNumber
        self.betaNumber = betaNumber
        self.userAgent = userAgent
        self.releaseChannel = releaseChannel
        self.clientPlatform = clientPlatform
        self.clientRuntime = clientRuntime
        self.desktopAppVersion = desktopAppVersion
        self.desktopAppChannel = desktopAppChannel
        self.desktopArch = desktopArch
        self.desktopOs = desktopOs
        self.e2eeCapable = e2eeCapable
        self.mobile = mobile
    }

    public func toJSON() -> [String: Any] {
        var json: [String: Any] = [
            "os": os,
            "browser": browser,
            "device": device,
        ]
        if let osVersion { json["os_version"] = osVersion }
        if let locale { json["locale"] = locale }
        if let systemLocale { json["system_locale"] = systemLocale }
        if let browserVersion { json["browser_version"] = browserVersion }
        if let buildTimestamp { json["build_timestamp"] = buildTimestamp }
        if let buildVersion { json["build_version"] = buildVersion }
        if let buildNumber { json["build_number"] = buildNumber }
        if let betaNumber { json["beta_number"] = betaNumber }
        if let userAgent { json["user_agent"] = userAgent }
        if let releaseChannel { json["release_channel"] = releaseChannel }
        if let clientPlatform { json["client_platform"] = clientPlatform }
        if let clientRuntime { json["client_runtime"] = clientRuntime }
        if let desktopAppVersion { json["desktop_app_version"] = desktopAppVersion }
        if let desktopAppChannel { json["desktop_app_channel"] = desktopAppChannel }
        if let desktopArch { json["desktop_arch"] = desktopArch }
        if let desktopOs { json["desktop_os"] = desktopOs }
        if let e2eeCapable { json["e2ee_capable"] = e2eeCapable }
        if let mobile { json["mobile"] = mobile }
        return json
    }
}

public struct GatewayCustomStatus: Sendable {
    public var text: String?
    public var expiresAt: String?
    public var emojiId: String?
    public var emojiName: String?
    public var emojiAnimated: Bool?

    public init(
        text: String? = nil,
        expiresAt: String? = nil,
        emojiId: String? = nil,
        emojiName: String? = nil,
        emojiAnimated: Bool? = nil
    ) {
        self.text = text
        self.expiresAt = expiresAt
        self.emojiId = emojiId
        self.emojiName = emojiName
        self.emojiAnimated = emojiAnimated
    }

    public func toJSON() -> [String: Any] {
        var json: [String: Any] = [:]
        if let text { json["text"] = text }
        if let expiresAt { json["expires_at"] = expiresAt }
        if let emojiId { json["emoji_id"] = emojiId }
        if let emojiName { json["emoji_name"] = emojiName }
        if let emojiAnimated { json["emoji_animated"] = emojiAnimated }
        return json
    }
}

public struct GatewayPresence: Sendable {
    public var status: String
    public var afk: Bool
    public var mobile: Bool?
    public var customStatus: GatewayCustomStatus?

    public init(
        status: String,
        afk: Bool = false,
        mobile: Bool? = nil,
        customStatus: GatewayCustomStatus? = nil
    ) {
        self.status = status
        self.afk = afk
        self.mobile = mobile
        self.customStatus = customStatus
    }

    public func toJSON() -> [String: Any] {
        var json: [String: Any] = [
            "status": status,
            "afk": afk,
        ]
        if let mobile { json["mobile"] = mobile }
        if let customStatus { json["custom_status"] = customStatus.toJSON() }
        return json
    }
}
