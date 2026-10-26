import Foundation

public protocol GatewayEvent: Sendable {}

public struct ReactionEmoji: Sendable {
    public var name: String
    public var id: String?
    public var animated: Bool

    public static func fromJSON(_ json: [String: Any]) -> ReactionEmoji {
        ReactionEmoji(
            name: json["name"] as! String,
            id: json["id"] as? String,
            animated: json["animated"] as? Bool ?? false
        )
    }
}

public struct VoiceIceServer: Sendable {
    public var urls: [String]
}

public struct GuildCountEntry: Sendable {
    public var guildId: String
    public var memberCount: Int
    public var onlineCount: Int
}

public struct ChannelMemberCountEntry: Sendable {
    public var guildId: String
    public var channelId: String
    public var memberCount: Int
    public var onlineCount: Int
}

public struct ReadyEvent: GatewayEvent, @unchecked Sendable {
    public var sessionId: String
    public var user: Components.Schemas.UserPrivateResponse
    public var guilds: [GuildReadyData]
    public var rawGuilds: [[String: Any]]
    public var privateChannels: [Components.Schemas.ChannelResponse]
    public var relationships: [Components.Schemas.RelationshipResponse]
    public var readStates: [GatewayReadState]
    public var presences: [[String: Any]]
    public var userSettings: Components.Schemas.UserSettingsResponse?
    public var userGuildSettings: [Components.Schemas.UserGuildSettingsResponse]?
    public var notes: [String: String]?
    public var countryCode: String?
    public var pinnedDms: [String]?
    public var favoriteMemes: [[String: Any]]?
    public var users: [[String: Any]]?
    public var authSessionIdHash: String?
    public var rtcRegions: [[String: Any]]?
}

public struct ResumedEvent: GatewayEvent, Sendable {}

public struct UserUpdateEvent: GatewayEvent, Sendable {
    public var user: Components.Schemas.UserPrivateResponse
}

public struct UserSettingsUpdateEvent: GatewayEvent, @unchecked Sendable {
    public var settings: Components.Schemas.UserSettingsResponse
    public var data: [String: Any]
}

public struct UserGuildSettingsUpdateEvent: GatewayEvent, @unchecked Sendable {
    public var guildId: String?
    public var data: [String: Any]
}

public struct UserPinnedDmsUpdateEvent: GatewayEvent, Sendable {
    public var pinnedDmChannelIds: [String]
}

public struct UserNoteUpdateEvent: GatewayEvent, Sendable {
    public var userId: String
    public var note: String?
}

public struct UserConnectionsUpdateEvent: GatewayEvent, @unchecked Sendable {
    public var data: [String: Any]
}

public struct WebauthnCredentialsUpdateEvent: GatewayEvent, Sendable {
    public var credentials: [Components.Schemas.WebAuthnCredentialResponse]
}

public struct AuthSessionChangeEvent: GatewayEvent, Sendable {
    public var newToken: String?
    public var newAuthSessionIdHash: String?
}

public struct MessageCreateEvent: GatewayEvent, Sendable {
    public var message: Components.Schemas.MessageResponseSchema
    public var guildId: String?
    public var channelType: Int?
    public var member: Components.Schemas.GuildMemberResponse?
}

public struct MessageUpdateEvent: GatewayEvent, Sendable {
    public var message: Components.Schemas.MessageResponseSchema
    public var guildId: String?
    public var member: Components.Schemas.GuildMemberResponse?
}

public struct MessageDeleteEvent: GatewayEvent, Sendable {
    public var channelId: String
    public var messageId: String
    public var guildId: String?
}

public struct MessageDeleteBulkEvent: GatewayEvent, Sendable {
    public var channelId: String
    public var ids: [String]
    public var guildId: String?
}

public struct MessageAckEvent: GatewayEvent, Sendable {
    public var channelId: String
    public var messageId: String
    public var mentionCount: Int?
    public var manual: Bool?
    public var version: String?
    public var flags: Int?
}

public struct MessageReactionAddEvent: GatewayEvent, Sendable {
    public var channelId: String
    public var messageId: String
    public var userId: String
    public var emoji: ReactionEmoji
    public var guildId: String?
    public var member: Components.Schemas.GuildMemberResponse?
}

public struct MessageReactionRemoveEvent: GatewayEvent, Sendable {
    public var channelId: String
    public var messageId: String
    public var userId: String
    public var emoji: ReactionEmoji
    public var guildId: String?
    public var member: Components.Schemas.GuildMemberResponse?
}

public struct MessageReactionRemoveAllEvent: GatewayEvent, Sendable {
    public var channelId: String
    public var messageId: String
    public var guildId: String?
}

public struct MessageReactionRemoveEmojiEvent: GatewayEvent, Sendable {
    public var channelId: String
    public var messageId: String
    public var emoji: ReactionEmoji
    public var guildId: String?
}

public struct MessageReactionAddManyEvent: GatewayEvent, @unchecked Sendable {
    public var channelId: String
    public var messageId: String
    public var reactions: [[String: Any]]
    public var guildId: String?
}

public struct ChannelCreateEvent: GatewayEvent, Sendable {
    public var channel: Components.Schemas.ChannelResponse
}

public struct ChannelUpdateEvent: GatewayEvent, Sendable {
    public var channel: Components.Schemas.ChannelResponse
}

public struct ChannelDeleteEvent: GatewayEvent, Sendable {
    public var channelId: String
    public var guildId: String?
}

public struct ChannelUpdateBulkEvent: GatewayEvent, Sendable {
    public var channels: [Components.Schemas.ChannelResponse]
}

public struct ChannelPinsUpdateEvent: GatewayEvent, Sendable {
    public var channelId: String
    public var guildId: String?
    public var lastPinTimestamp: String?
}

public struct ChannelPinsAckEvent: GatewayEvent, Sendable {
    public var channelId: String
    public var timestamp: String?
}

public struct ChannelRecipientAddEvent: GatewayEvent, Sendable {
    public var channelId: String
    public var user: Components.Schemas.UserPartialResponse
}

public struct ChannelRecipientRemoveEvent: GatewayEvent, Sendable {
    public var channelId: String
    public var user: Components.Schemas.UserPartialResponse
}

public struct PassiveUpdatesEvent: GatewayEvent, Sendable {
    public var guildId: String
    public var channels: [String: String]
    public var voiceStates: [VoiceState]?
}

public struct ThreadCreateEvent: GatewayEvent, Sendable {
    public var channel: Components.Schemas.ChannelResponse
    public var newlyCreated: Bool
}

public struct ThreadUpdateEvent: GatewayEvent, Sendable {
    public var channel: Components.Schemas.ChannelResponse
}

public struct ThreadDeleteEvent: GatewayEvent, Sendable {
    public var id: String
    public var guildId: String
    public var parentId: String
    public var type: Components.Schemas.ChannelType
}

public struct ThreadListSyncEvent: GatewayEvent, Sendable {
    public var guildId: String
    public var channelIds: [String]?
    public var threads: [Components.Schemas.ChannelResponse]
    public var members: [Components.Schemas.ThreadMemberResponse]
}

public struct ThreadMemberUpdateEvent: GatewayEvent, Sendable {
    public var guildId: String
    public var member: Components.Schemas.ThreadMemberResponse
}

public struct ThreadMembersUpdateEvent: GatewayEvent, Sendable {
    public var id: String
    public var guildId: String
    public var memberCount: Int
    public var addedMembers: [ThreadMemberEntry]?
    public var removedMemberIds: [String]?
}

public struct ThreadMemberListUpdateEvent: GatewayEvent, Sendable {
    public var guildId: String
    public var threadId: String
    public var members: [ThreadMemberEntry]
}

public struct ForumUnreadsEvent: GatewayEvent, Sendable {
    public var guildId: String
    public var channelId: String
    public var threads: [ForumUnreadEntry]
}

public struct GuildCreateEvent: GatewayEvent, Sendable {
    public var guild: GuildCreateData
}

public struct GuildUpdateEvent: GatewayEvent, Sendable {
    public var guild: GuildCreateData
}

public struct GuildDeleteEvent: GatewayEvent, Sendable {
    public var guildId: String
    public var unavailable: Bool
    public var unavailableHidden: Bool
}

public struct GuildRoleCreateEvent: GatewayEvent, Sendable {
    public var guildId: String
    public var role: Components.Schemas.GuildRoleResponse
}

public struct GuildRoleUpdateEvent: GatewayEvent, Sendable {
    public var guildId: String
    public var role: Components.Schemas.GuildRoleResponse
}

public struct GuildRoleDeleteEvent: GatewayEvent, Sendable {
    public var guildId: String
    public var roleId: String
}

public struct GuildRoleUpdateBulkEvent: GatewayEvent, Sendable {
    public var guildId: String
    public var roles: [Components.Schemas.GuildRoleResponse]
}

public struct GuildBanAddEvent: GatewayEvent, Sendable {
    public var guildId: String
    public var userId: String
}

public struct GuildBanRemoveEvent: GatewayEvent, Sendable {
    public var guildId: String
    public var userId: String
}

public struct GuildEmojisUpdateEvent: GatewayEvent, Sendable {
    public var guildId: String
    public var emojis: [Components.Schemas.GuildEmojiResponse]
}

public struct GuildStickersUpdateEvent: GatewayEvent, Sendable {
    public var guildId: String
    public var stickers: [Components.Schemas.GuildStickerResponse]
}

public struct GuildSyncEvent: GatewayEvent, Sendable {
    public var guild: GuildCreateData
}

public struct GuildMembersChunkEvent: GatewayEvent, @unchecked Sendable {
    public var guildId: String
    public var members: [Components.Schemas.GuildMemberResponse]
    public var chunkIndex: Int
    public var chunkCount: Int
    public var presences: [[String: Any]]?
    public var nonce: String?
}

public struct GuildMemberListUpdateEvent: GatewayEvent, Sendable {
    public var guildId: String
    public var id: String
    public var channelId: String?
    public var memberCount: Int
    public var onlineCount: Int
    public var groups: [MemberListGroup]
    public var ops: [MemberListOp]
}

public struct GuildMemberAddEvent: GatewayEvent, Sendable {
    public var guildId: String
    public var member: Components.Schemas.GuildMemberResponse
}

public struct GuildMemberUpdateEvent: GatewayEvent, Sendable {
    public var guildId: String
    public var member: Components.Schemas.GuildMemberResponse
}

public struct GuildMemberRemoveEvent: GatewayEvent, Sendable {
    public var guildId: String
    public var userId: String
}

public struct PresenceUpdateEvent: GatewayEvent, Sendable {
    public var userId: String
    public var status: String
    public var customStatus: String?
    public var mobile: Bool
    public var user: Components.Schemas.UserPartialResponse?
}

public struct PresenceUpdateBulkEvent: GatewayEvent, @unchecked Sendable {
    public var presences: [[String: Any]]
    public var guildId: String?
}

public struct TypingStartEvent: GatewayEvent, Sendable {
    public var channelId: String
    public var userId: String
    public var timestamp: Date
    public var member: Components.Schemas.GuildMemberResponse?
    public var guildId: String?
}

public struct VoiceStateUpdateEvent: GatewayEvent, Sendable {
    public var state: VoiceState
    public var member: Components.Schemas.GuildMemberResponse?
}

public struct VoiceServerUpdateEvent: GatewayEvent, Sendable {
    public var token: String
    public var endpoint: String
    public var connectionId: String
    public var guildId: String?
    public var channelId: String?
    public var e2eeKey: String?
}

public struct VoiceServerP2pUpdateEvent: GatewayEvent, Sendable {
    public var connectionId: String
    public var iceServers: [VoiceIceServer]
    public var guildId: String?
    public var channelId: String?
}

public struct VoiceSignalEvent: GatewayEvent, @unchecked Sendable {
    public var channelId: String
    public var from: String
    public var userId: String
    public var data: [String: Any]
    public var guildId: String?
}

public struct EntranceSoundPlayEvent: GatewayEvent, Sendable {
    public var userId: String
    public var channelId: String
    public var soundId: String
    public var hash: String
    public var url: String
    public var durationMs: Int
    public var contentType: String
    public var guildId: String?
}

public struct GuildCountsUpdateEvent: GatewayEvent, Sendable {
    public var counts: [GuildCountEntry]
}

public struct ChannelMemberCountsUpdateEvent: GatewayEvent, Sendable {
    public var counts: [ChannelMemberCountEntry]
}

public struct CallCreateEvent: GatewayEvent, Sendable {
    public var channelId: String
    public var messageId: String?
    public var region: String?
    public var voiceStates: [VoiceState]?
    public var ringing: [String]?
}

public struct CallUpdateEvent: GatewayEvent, Sendable {
    public var channelId: String
    public var messageId: String?
    public var region: String?
    public var ringing: [String]?
    public var voiceStates: [VoiceState]?
}

public struct CallDeleteEvent: GatewayEvent, Sendable {
    public var channelId: String
}

public struct RelationshipAddEvent: GatewayEvent, Sendable {
    public var relationship: Components.Schemas.RelationshipResponse
}

public struct RelationshipUpdateEvent: GatewayEvent, Sendable {
    public var relationship: Components.Schemas.RelationshipResponse
}

public struct RelationshipRemoveEvent: GatewayEvent, Sendable {
    public var userId: String
}

public struct InviteCreateEvent: GatewayEvent, @unchecked Sendable {
    public var data: [String: Any]
}

public struct InviteDeleteEvent: GatewayEvent, Sendable {
    public var code: String
    public var guildId: String
}

public struct SavedMessageCreateEvent: GatewayEvent, Sendable {
    public var message: Components.Schemas.MessageResponseSchema
}

public struct SavedMessageDeleteEvent: GatewayEvent, Sendable {
    public var messageId: String
}

public struct RecentMentionDeleteEvent: GatewayEvent, Sendable {
    public var messageId: String
}

public struct WebhooksUpdateEvent: GatewayEvent, Sendable {
    public var channelId: String
    public var guildId: String
}

public struct FavoriteMemeCreateEvent: GatewayEvent, @unchecked Sendable {
    public var data: [String: Any]
}

public struct FavoriteMemeUpdateEvent: GatewayEvent, @unchecked Sendable {
    public var data: [String: Any]
}

public struct FavoriteMemeDeleteEvent: GatewayEvent, Sendable {
    public var id: String
}

public struct SessionsReplaceEvent: GatewayEvent, Sendable {}

public struct GatewayErrorEvent: GatewayEvent, Sendable {
    public var code: String
    public var message: String
}

public struct UnknownGatewayEvent: GatewayEvent, @unchecked Sendable {
    public var eventType: String
    public var data: [String: Any]
    public var parseError: Error?
}
