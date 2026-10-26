import Foundation

public struct VoiceState: Sendable, Equatable, Hashable {
    public var userId: String
    public var channelId: String?
    public var guildId: String?
    public var sessionId: String?
    public var connectionId: String?
    public var selfMute: Bool
    public var selfDeaf: Bool
    public var selfVideo: Bool
    public var selfStream: Bool
    public var mute: Bool
    public var deaf: Bool
    public var suppress: Bool
    public var isMobile: Bool
    public var e2eeCapable: Bool?
    public var p2p: Bool
    public var version: Int?

    public init(
        userId: String,
        channelId: String? = nil,
        guildId: String? = nil,
        sessionId: String? = nil,
        connectionId: String? = nil,
        selfMute: Bool = false,
        selfDeaf: Bool = false,
        selfVideo: Bool = false,
        selfStream: Bool = false,
        mute: Bool = false,
        deaf: Bool = false,
        suppress: Bool = false,
        isMobile: Bool = false,
        e2eeCapable: Bool? = nil,
        p2p: Bool = false,
        version: Int? = nil
    ) {
        self.userId = userId
        self.channelId = channelId
        self.guildId = guildId
        self.sessionId = sessionId
        self.connectionId = connectionId
        self.selfMute = selfMute
        self.selfDeaf = selfDeaf
        self.selfVideo = selfVideo
        self.selfStream = selfStream
        self.mute = mute
        self.deaf = deaf
        self.suppress = suppress
        self.isMobile = isMobile
        self.e2eeCapable = e2eeCapable
        self.p2p = p2p
        self.version = version
    }

    public static func fromJSON(_ json: [String: Any]) -> VoiceState {
        VoiceState(
            userId: json["user_id"] as! String,
            channelId: json["channel_id"] as? String,
            guildId: json["guild_id"] as? String,
            sessionId: json["session_id"] as? String,
            connectionId: json["connection_id"] as? String,
            selfMute: json["self_mute"] as? Bool ?? false,
            selfDeaf: json["self_deaf"] as? Bool ?? false,
            selfVideo: json["self_video"] as? Bool ?? false,
            selfStream: json["self_stream"] as? Bool ?? false,
            mute: json["mute"] as? Bool ?? false,
            deaf: json["deaf"] as? Bool ?? false,
            suppress: json["suppress"] as? Bool ?? false,
            isMobile: json["is_mobile"] as? Bool ?? false,
            e2eeCapable: json["e2ee_capable"] as? Bool,
            p2p: json["p2p"] as? Bool ?? false,
            version: (json["version"] as? NSNumber)?.intValue
        )
    }
}

public struct GatewayVoiceStateUpdate: Sendable {
    public var guildId: String?
    public var channelId: String?
    public var selfMute: Bool
    public var selfDeaf: Bool
    public var selfVideo: Bool
    public var selfStream: Bool
    public var viewerStreamKeys: [String]?
    public var connectionId: String?
    public var voiceE2eePublicKey: String?
    public var voiceE2eePublicKeySignature: String?
    public var isMobile: Bool?
    public var latitude: String?
    public var longitude: String?
    public var p2p: Bool?

    public init(
        guildId: String? = nil,
        channelId: String? = nil,
        selfMute: Bool,
        selfDeaf: Bool,
        selfVideo: Bool,
        selfStream: Bool,
        viewerStreamKeys: [String]? = nil,
        connectionId: String? = nil,
        voiceE2eePublicKey: String? = nil,
        voiceE2eePublicKeySignature: String? = nil,
        isMobile: Bool? = nil,
        latitude: String? = nil,
        longitude: String? = nil,
        p2p: Bool? = nil
    ) {
        self.guildId = guildId
        self.channelId = channelId
        self.selfMute = selfMute
        self.selfDeaf = selfDeaf
        self.selfVideo = selfVideo
        self.selfStream = selfStream
        self.viewerStreamKeys = viewerStreamKeys
        self.connectionId = connectionId
        self.voiceE2eePublicKey = voiceE2eePublicKey
        self.voiceE2eePublicKeySignature = voiceE2eePublicKeySignature
        self.isMobile = isMobile
        self.latitude = latitude
        self.longitude = longitude
        self.p2p = p2p
    }

    public func toJSON() -> [String: Any] {
        var map: [String: Any] = [
            "guild_id": guildId as Any,
            "channel_id": channelId as Any,
            "self_mute": selfMute,
            "self_deaf": selfDeaf,
            "self_video": selfVideo,
            "self_stream": selfStream,
            "connection_id": connectionId as Any,
        ]
        if let viewerStreamKeys { map["viewer_stream_keys"] = viewerStreamKeys }
        if let voiceE2eePublicKey { map["voice_e2ee_public_key"] = voiceE2eePublicKey }
        if let voiceE2eePublicKeySignature {
            map["voice_e2ee_public_key_signature"] = voiceE2eePublicKeySignature
        }
        if let isMobile { map["is_mobile"] = isMobile }
        if let latitude { map["latitude"] = latitude }
        if let longitude { map["longitude"] = longitude }
        if let p2p { map["p2p"] = p2p }
        return map
    }
}

public struct MemberListGroup: Sendable {
    public var id: String
    public var count: Int

    public static func fromJSON(_ json: [String: Any]) -> MemberListGroup {
        MemberListGroup(id: json["id"] as! String, count: json["count"] as! Int)
    }
}

public struct MemberListItem: Sendable {
    public var member: MemberListMember?
    public var group: MemberListGroup?

    public static func fromJSON(_ json: [String: Any]) -> MemberListItem {
        let memberData = json["member"] as? [String: Any]
        let groupData = json["group"] as? [String: Any]
        return MemberListItem(
            member: memberData.flatMap { try? MemberListMember.fromJSON($0) },
            group: groupData.map { MemberListGroup.fromJSON($0) }
        )
    }
}

public struct MemberListMember: Sendable {
    public var member: Components.Schemas.GuildMemberResponse
    public var status: String?
    public var customStatus: String?
    public var mobile: Bool

    public static func fromJSON(_ json: [String: Any]) throws -> MemberListMember {
        let presenceData = json["presence"] as? [String: Any]
        let customStatusMap = presenceData?["custom_status"] as? [String: Any]
        return MemberListMember(
            member: try GatewayDecoding.decode(Components.Schemas.GuildMemberResponse.self, from: json),
            status: presenceData?["status"] as? String,
            customStatus: serializeCustomStatusMap(customStatusMap),
            mobile: presenceData?["mobile"] as? Bool ?? false
        )
    }
}

public struct MemberListOp: Sendable {
    public var op: String
    public var range: [Int]?
    public var items: [MemberListItem]?
    public var index: Int?
    public var item: MemberListItem?

    public static func fromJSON(_ json: [String: Any]) throws -> MemberListOp {
        let range = (json["range"] as? [Any])?.compactMap { ($0 as? NSNumber)?.intValue }
        let items = (json["items"] as? [[String: Any]])?.map { MemberListItem.fromJSON($0) }
        let item = (json["item"] as? [String: Any]).map { MemberListItem.fromJSON($0) }
        return MemberListOp(
            op: json["op"] as! String,
            range: range,
            items: items,
            index: (json["index"] as? NSNumber)?.intValue,
            item: item
        )
    }
}

public struct ForumUnreadEntry: Sendable {
    public var threadId: String
    public var count: Int?
    public var missing: Bool

    public static func fromJSON(_ json: [String: Any]) -> ForumUnreadEntry {
        ForumUnreadEntry(
            threadId: json["thread_id"] as! String,
            count: (json["count"] as? NSNumber)?.intValue,
            missing: json["missing"] as? Bool == true
        )
    }
}

public struct ThreadMemberEntry: @unchecked Sendable {
    public var userId: String
    public var threadId: String?
    public var joinTimestamp: String?
    public var flags: Int
    public var member: Components.Schemas.GuildMemberResponse?
    public var presence: [String: Any]?

    public static func fromJSON(_ json: [String: Any]) throws -> ThreadMemberEntry {
        let member = json["member"]
        let presence = json["presence"] as? [String: Any]
        return ThreadMemberEntry(
            userId: json["user_id"] as! String,
            threadId: json["id"] as? String,
            joinTimestamp: json["join_timestamp"] as? String,
            flags: (json["flags"] as? NSNumber)?.intValue ?? 0,
            member: member is [String: Any]
                ? try GatewayDecoding.decode(Components.Schemas.GuildMemberResponse.self, from: member as! [String: Any])
                : nil,
            presence: presence
        )
    }
}

public struct LazyRequestSubscription: Sendable {
    public var active: Bool?
    public var typing: Bool?
    public var sync: Bool?
    public var members: [String]?
    public var memberListChannels: [String: [[Int]]]?
    public var threads: Bool?
    public var threadMemberLists: [String]?

    public init(
        active: Bool? = nil,
        typing: Bool? = nil,
        sync: Bool? = nil,
        members: [String]? = nil,
        memberListChannels: [String: [[Int]]]? = nil,
        threads: Bool? = nil,
        threadMemberLists: [String]? = nil
    ) {
        self.active = active
        self.typing = typing
        self.sync = sync
        self.members = members
        self.memberListChannels = memberListChannels
        self.threads = threads
        self.threadMemberLists = threadMemberLists
    }

    public func toJSON() -> [String: Any] {
        var json: [String: Any] = [:]
        if let active { json["active"] = active }
        if let typing { json["typing"] = typing }
        if let sync { json["sync"] = sync }
        if let members { json["members"] = members }
        if let memberListChannels { json["member_list_channels"] = memberListChannels }
        if let threads { json["threads"] = threads }
        if let threadMemberLists { json["thread_member_lists"] = threadMemberLists }
        return json
    }
}

public struct GuildReadyData: Sendable {
    public var id: String
    public var name: String?
    public var icon: String?
    public var ownerId: String?
    public var memberCount: Int?
    public var unavailable: Bool?
    public var joinedAt: String?
    public var features: [String]

    public static func fromJSON(_ json: [String: Any]) -> GuildReadyData {
        let props = json["properties"] as? [String: Any] ?? json
        let features = (props["features"] as? [Any])?.compactMap { $0 as? String } ?? []
        return GuildReadyData(
            id: json["id"] as! String,
            name: props["name"] as? String,
            icon: props["icon"] as? String,
            ownerId: props["owner_id"] as? String,
            memberCount: (json["member_count"] as? NSNumber)?.intValue,
            unavailable: json["unavailable"] as? Bool,
            joinedAt: json["joined_at"] as? String,
            features: features
        )
    }
}

public struct GatewayReadState: Sendable {
    public var id: String
    public var lastMessageId: String?
    public var mentionCount: Int
    public var lastPinTimestamp: String?
    public var version: String?
    public var flags: Int?
    public var lastViewed: Int?

    public static func fromJSON(_ json: [String: Any]) -> GatewayReadState {
        GatewayReadState(
            id: json["id"] as! String,
            lastMessageId: json["last_message_id"] as? String,
            mentionCount: (json["mention_count"] as? NSNumber)?.intValue ?? 0,
            lastPinTimestamp: json["last_pin_timestamp"] as? String,
            version: json["version"] as? String,
            flags: (json["flags"] as? NSNumber)?.intValue,
            lastViewed: (json["last_viewed"] as? NSNumber)?.intValue
        )
    }
}

public struct GuildCreateData: @unchecked Sendable {
    public var guild: Components.Schemas.GuildResponse
    public var channels: [Components.Schemas.ChannelResponse]
    public var members: [Components.Schemas.GuildMemberResponse]
    public var roles: [Components.Schemas.GuildRoleResponse]
    public var presences: [[String: Any]]
    public var voiceStates: [VoiceState]
    public var emojis: [Components.Schemas.GuildEmojiResponse]
    public var stickers: [Components.Schemas.GuildStickerResponse]
    public var joinedAt: String?
    public var memberCount: Int?
    public var onlineCount: Int?
    public var unavailable: Bool
    public var hasCompletePayload: Bool
    public var threads: [Components.Schemas.ChannelResponse]?

    public var shouldTreatAsUnavailable: Bool { unavailable || !hasCompletePayload }

    public static func fromJSON(_ json: [String: Any]) throws -> GuildCreateData {
        let threads: [Components.Schemas.ChannelResponse]?
        if json["threads"] is [Any] {
            threads = parseListSafe(json["threads"]) {
                try GatewayDecoding.decode(Components.Schemas.ChannelResponse.self, from: $0 as! [String: Any])
            }
        } else {
            threads = nil
        }

        return GuildCreateData(
            guild: try GatewayDecoding.decode(
                Components.Schemas.GuildResponse.self,
                from: guildData(json)
            ),
            channels: parseListSafe(json["channels"]) {
                try GatewayDecoding.decode(Components.Schemas.ChannelResponse.self, from: $0 as! [String: Any])
            },
            members: parseListSafe(json["members"]) {
                try GatewayDecoding.decode(Components.Schemas.GuildMemberResponse.self, from: $0 as! [String: Any])
            },
            roles: parseListSafe(json["roles"]) {
                try GatewayDecoding.decode(Components.Schemas.GuildRoleResponse.self, from: $0 as! [String: Any])
            },
            presences: (json["presences"] as? [[String: Any]]) ?? [],
            voiceStates: (json["voice_states"] as? [[String: Any]])?.map { VoiceState.fromJSON($0) } ?? [],
            emojis: parseListSafe(json["emojis"]) {
                try GatewayDecoding.decode(Components.Schemas.GuildEmojiResponse.self, from: $0 as! [String: Any])
            },
            stickers: parseListSafe(json["stickers"]) {
                try GatewayDecoding.decode(Components.Schemas.GuildStickerResponse.self, from: $0 as! [String: Any])
            },
            joinedAt: json["joined_at"] as? String,
            memberCount: (json["member_count"] as? NSNumber)?.intValue,
            onlineCount: (json["online_count"] as? NSNumber)?.intValue,
            unavailable: json["unavailable"] as? Bool ?? false,
            hasCompletePayload: hasCompletePayload(json),
            threads: threads
        )
    }

    private static func hasCompletePayload(_ json: [String: Any]) -> Bool {
        for key in ["channels", "members", "roles", "emojis"] {
            if json[key] is [Any] == false { return false }
        }
        return true
    }

    private static let numericGuildFields = [
        "splash_card_alignment",
        "system_channel_flags",
        "afk_timeout",
        "verification_level",
        "mfa_level",
        "nsfw_level",
        "explicit_content_filter",
        "default_message_notifications",
        "disabled_operations",
    ]

    private static func guildData(_ raw: [String: Any]) -> [String: Any] {
        var data: [String: Any]
        if let properties = raw["properties"] as? [String: Any] {
            data = properties
            if let id = raw["id"] ?? properties["id"] {
                data["id"] = id
            }
        } else {
            data = raw
        }
        for key in numericGuildFields {
            if let value = data[key] as? String, let parsed = Int(value) {
                data[key] = parsed
            }
        }
        return data
    }
}

func parseListSafe<T>(_ rawList: Any?, parser: (Any) throws -> T) -> [T] {
    guard let list = rawList as? [Any] else { return [] }
    var result: [T] = []
    for item in list {
        do {
            result.append(try parser(item))
        } catch {}
    }
    return result
}
