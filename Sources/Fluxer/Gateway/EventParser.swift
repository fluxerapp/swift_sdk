import Foundation

public struct EventParser: Sendable {
    public init() {}

    public func parse(eventType: String, data: [String: Any]) -> any GatewayEvent {
        do {
            return try parseThrowing(eventType: eventType, data: data)
        } catch {
            return UnknownGatewayEvent(eventType: eventType, data: data, parseError: error)
        }
    }

    public func parseList(eventType: String, data: [Any]) -> (any GatewayEvent)? {
        switch eventType {
        case "WEBAUTHN_CREDENTIALS_UPDATE":
            let credentials = data.compactMap { item -> Components.Schemas.WebAuthnCredentialResponse? in
                guard let map = item as? [String: Any] else { return nil }
                return try? GatewayDecoding.decode(Components.Schemas.WebAuthnCredentialResponse.self, from: map)
            }
            return WebauthnCredentialsUpdateEvent(credentials: credentials)
        case "USER_PINNED_DMS_UPDATE":
            return UserPinnedDmsUpdateEvent(pinnedDmChannelIds: data.map { String(describing: $0) })
        default:
            return nil
        }
    }

    private func parseThrowing(eventType: String, data: [String: Any]) throws -> any GatewayEvent {
        switch eventType {


        case "READY":
            return try parseReady(data)
        case "RESUMED":
            return ResumedEvent()
        case "MESSAGE_CREATE":
            return MessageCreateEvent(
                message: try GatewayDecoding.decode(Components.Schemas.MessageResponseSchema.self, from: data),
                guildId: data["guild_id"] as? String,
                channelType: (data["channel_type"] as? NSNumber)?.intValue,
                member: parseEmbeddedMember(data["member"], user: data["author"])
            )
        case "MESSAGE_UPDATE":
            return MessageUpdateEvent(
                message: try GatewayDecoding.decode(Components.Schemas.MessageResponseSchema.self, from: data),
                guildId: data["guild_id"] as? String,
                member: parseEmbeddedMember(data["member"], user: data["author"])
            )
        case "MESSAGE_DELETE":
            return MessageDeleteEvent(
                channelId: data["channel_id"] as! String,
                messageId: data["id"] as! String,
                guildId: data["guild_id"] as? String
            )
        case "MESSAGE_REACTION_ADD":
            return MessageReactionAddEvent(
                channelId: data["channel_id"] as! String,
                messageId: data["message_id"] as! String,
                userId: data["user_id"] as! String,
                emoji: ReactionEmoji.fromJSON(data["emoji"] as! [String: Any]),
                guildId: data["guild_id"] as? String,
                member: parseEmbeddedMember(data["member"])
            )
        case "MESSAGE_REACTION_REMOVE":
            return MessageReactionRemoveEvent(
                channelId: data["channel_id"] as! String,
                messageId: data["message_id"] as! String,
                userId: data["user_id"] as! String,
                emoji: ReactionEmoji.fromJSON(data["emoji"] as! [String: Any]),
                guildId: data["guild_id"] as? String,
                member: parseEmbeddedMember(data["member"])
            )
        case "MESSAGE_REACTION_REMOVE_ALL":
            return MessageReactionRemoveAllEvent(
                channelId: data["channel_id"] as! String,
                messageId: data["message_id"] as! String,
                guildId: data["guild_id"] as? String
            )
        case "MESSAGE_REACTION_REMOVE_EMOJI":
            return MessageReactionRemoveEmojiEvent(
                channelId: data["channel_id"] as! String,
                messageId: data["message_id"] as! String,
                emoji: ReactionEmoji.fromJSON(data["emoji"] as! [String: Any]),
                guildId: data["guild_id"] as? String
            )
        case "CHANNEL_CREATE":
            return ChannelCreateEvent(channel: try GatewayDecoding.decode(Components.Schemas.ChannelResponse.self, from: data))
        case "CHANNEL_UPDATE":
            return ChannelUpdateEvent(channel: try GatewayDecoding.decode(Components.Schemas.ChannelResponse.self, from: data))
        case "CHANNEL_DELETE":
            return ChannelDeleteEvent(channelId: data["id"] as! String, guildId: data["guild_id"] as? String)
        case "GUILD_CREATE":
            return GuildCreateEvent(guild: try GuildCreateData.fromJSON(data))
        case "GUILD_UPDATE":
            return GuildUpdateEvent(guild: try GuildCreateData.fromJSON(data))
        case "GUILD_DELETE":
            return GuildDeleteEvent(
                guildId: data["id"] as! String,
                unavailable: data["unavailable"] as? Bool ?? false,
                unavailableHidden: data["unavailable_hidden"] as? Bool ?? false
            )
        case "GUILD_MEMBER_ADD":
            return GuildMemberAddEvent(
                guildId: data["guild_id"] as! String,
                member: try GatewayDecoding.decode(Components.Schemas.GuildMemberResponse.self, from: data)
            )
        case "GUILD_MEMBER_UPDATE":
            return GuildMemberUpdateEvent(
                guildId: data["guild_id"] as! String,
                member: try GatewayDecoding.decode(Components.Schemas.GuildMemberResponse.self, from: data)
            )
        case "GUILD_MEMBER_REMOVE":
            let userId = data["user_id"] as? String ?? (data["user"] as! [String: Any])["id"] as! String
            return GuildMemberRemoveEvent(guildId: data["guild_id"] as! String, userId: userId)
        case "PRESENCE_UPDATE":
            return parsePresenceUpdate(data)
        case "TYPING_START":
            let member: Components.Schemas.GuildMemberResponse?
            if let memberMap = data["member"] as? [String: Any] {
                member = try GatewayDecoding.decode(Components.Schemas.GuildMemberResponse.self, from: memberMap)
            } else { member = nil }
            return TypingStartEvent(
                channelId: data["channel_id"] as! String,
                userId: data["user_id"] as! String,
                timestamp: Date(timeIntervalSince1970: (data["timestamp"] as! NSNumber).doubleValue),
                member: member,
                guildId: data["guild_id"] as? String
            )
        case "RELATIONSHIP_ADD":
            return RelationshipAddEvent(relationship: try parseRelationship(data))
        case "RELATIONSHIP_UPDATE":
            return RelationshipUpdateEvent(relationship: try parseRelationship(data))
        case "RELATIONSHIP_REMOVE":
            return RelationshipRemoveEvent(userId: data["id"] as! String)
        case "USER_UPDATE":
            return UserUpdateEvent(user: try GatewayDecoding.decode(Components.Schemas.UserPrivateResponse.self, from: data))
        case "USER_SETTINGS_UPDATE":
            return UserSettingsUpdateEvent(
                settings: try GatewayDecoding.decode(Components.Schemas.UserSettingsResponse.self, from: data),
                data: data
            )
        case "USER_GUILD_SETTINGS_UPDATE":
            return UserGuildSettingsUpdateEvent(guildId: data["guild_id"] as? String, data: data)
        case "USER_NOTE_UPDATE":
            return UserNoteUpdateEvent(userId: data["id"] as! String, note: data["note"] as? String)
        case "USER_CONNECTIONS_UPDATE":
            return UserConnectionsUpdateEvent(data: data)
        case "AUTH_SESSION_CHANGE":
            return AuthSessionChangeEvent(
                newToken: data["new_token"] as? String,
                newAuthSessionIdHash: data["new_auth_session_id_hash"] as? String
            )
        case "MESSAGE_DELETE_BULK":
            return MessageDeleteBulkEvent(
                channelId: data["channel_id"] as! String,
                ids: data["ids"] as! [String],
                guildId: data["guild_id"] as? String
            )
        case "MESSAGE_ACK":
            return MessageAckEvent(
                channelId: data["channel_id"] as! String,
                messageId: data["message_id"] as! String,
                mentionCount: (data["mention_count"] as? NSNumber)?.intValue,
                manual: data["manual"] as? Bool,
                version: data["version"] as? String,
                flags: (data["flags"] as? NSNumber)?.intValue
            )
        case "MESSAGE_REACTION_ADD_MANY":
            return MessageReactionAddManyEvent(
                channelId: data["channel_id"] as! String,
                messageId: data["message_id"] as! String,
                reactions: data["reactions"] as! [[String: Any]],
                guildId: data["guild_id"] as? String
            )
        case "CHANNEL_UPDATE_BULK":
            let channels = (data["channels"] as! [Any]).compactMap { item -> Components.Schemas.ChannelResponse? in
                guard let map = item as? [String: Any] else { return nil }
                return try? GatewayDecoding.decode(Components.Schemas.ChannelResponse.self, from: map)
            }
            return ChannelUpdateBulkEvent(channels: channels)
        case "CHANNEL_PINS_UPDATE":
            return ChannelPinsUpdateEvent(
                channelId: data["channel_id"] as! String,
                guildId: data["guild_id"] as? String,
                lastPinTimestamp: data["last_pin_timestamp"] as? String
            )
        case "CHANNEL_PINS_ACK":
            return ChannelPinsAckEvent(channelId: data["channel_id"] as! String, timestamp: data["timestamp"] as? String)
        case "CHANNEL_RECIPIENT_ADD":
            return ChannelRecipientAddEvent(
                channelId: data["channel_id"] as! String,
                user: try GatewayDecoding.decode(Components.Schemas.UserPartialResponse.self, from: data["user"] as! [String: Any])
            )
        case "CHANNEL_RECIPIENT_REMOVE":
            return ChannelRecipientRemoveEvent(
                channelId: data["channel_id"] as! String,
                user: try GatewayDecoding.decode(Components.Schemas.UserPartialResponse.self, from: data["user"] as! [String: Any])
            )
        case "PASSIVE_UPDATES":
            return parsePassiveUpdates(data)
        case "THREAD_CREATE":
            return ThreadCreateEvent(
                channel: try GatewayDecoding.decode(Components.Schemas.ChannelResponse.self, from: data),
                newlyCreated: data["newly_created"] as? Bool ?? false
            )
        case "THREAD_UPDATE":
            return ThreadUpdateEvent(channel: try GatewayDecoding.decode(Components.Schemas.ChannelResponse.self, from: data))
        case "THREAD_DELETE":
            let typeValue = (data["type"] as! NSNumber).intValue
            guard let channelType = Components.Schemas.ChannelType(rawValue: typeValue) else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid channel type"))
            }
            return ThreadDeleteEvent(
                id: data["id"] as! String,
                guildId: data["guild_id"] as! String,
                parentId: data["parent_id"] as! String,
                type: channelType
            )
        case "THREAD_LIST_SYNC":
            return ThreadListSyncEvent(
                guildId: data["guild_id"] as! String,
                channelIds: data["channel_ids"] as? [String],
                threads: parseListSafe(data["threads"]) {
                    try GatewayDecoding.decode(Components.Schemas.ChannelResponse.self, from: $0 as! [String: Any])
                },
                members: parseListSafe(data["members"]) {
                    try GatewayDecoding.decode(Components.Schemas.ThreadMemberResponse.self, from: $0 as! [String: Any])
                }
            )
        case "THREAD_MEMBER_UPDATE":
            return ThreadMemberUpdateEvent(
                guildId: data["guild_id"] as! String,
                member: try GatewayDecoding.decode(Components.Schemas.ThreadMemberResponse.self, from: data)
            )
        case "THREAD_MEMBERS_UPDATE":
            let added: [ThreadMemberEntry]?
            if data["added_members"] is [Any] {
                added = parseListSafe(data["added_members"]) { try ThreadMemberEntry.fromJSON($0 as! [String: Any]) }
            } else { added = nil }
            return ThreadMembersUpdateEvent(
                id: data["id"] as! String,
                guildId: data["guild_id"] as! String,
                memberCount: (data["member_count"] as! NSNumber).intValue,
                addedMembers: added,
                removedMemberIds: data["removed_member_ids"] as? [String]
            )
        case "THREAD_MEMBER_LIST_UPDATE":
            return ThreadMemberListUpdateEvent(
                guildId: data["guild_id"] as! String,
                threadId: data["thread_id"] as! String,
                members: parseListSafe(data["members"]) { try ThreadMemberEntry.fromJSON($0 as! [String: Any]) }
            )
        case "FORUM_UNREADS":
            return ForumUnreadsEvent(
                guildId: data["guild_id"] as! String,
                channelId: data["channel_id"] as! String,
                threads: parseListSafe(data["threads"]) { ForumUnreadEntry.fromJSON($0 as! [String: Any]) }
            )
        case "GUILD_ROLE_CREATE":
            return GuildRoleCreateEvent(
                guildId: data["guild_id"] as! String,
                role: try GatewayDecoding.decode(Components.Schemas.GuildRoleResponse.self, from: data["role"] as! [String: Any])
            )
        case "GUILD_ROLE_UPDATE":
            return GuildRoleUpdateEvent(
                guildId: data["guild_id"] as! String,
                role: try GatewayDecoding.decode(Components.Schemas.GuildRoleResponse.self, from: data["role"] as! [String: Any])
            )
        case "GUILD_ROLE_DELETE":
            return GuildRoleDeleteEvent(guildId: data["guild_id"] as! String, roleId: data["role_id"] as! String)
        case "GUILD_ROLE_UPDATE_BULK":
            let roles = (data["roles"] as! [Any]).compactMap { item -> Components.Schemas.GuildRoleResponse? in
                guard let map = item as? [String: Any] else { return nil }
                return try? GatewayDecoding.decode(Components.Schemas.GuildRoleResponse.self, from: map)
            }
            return GuildRoleUpdateBulkEvent(guildId: data["guild_id"] as! String, roles: roles)
        case "GUILD_BAN_ADD":
            return GuildBanAddEvent(
                guildId: data["guild_id"] as! String,
                userId: (data["user"] as! [String: Any])["id"] as! String
            )
        case "GUILD_BAN_REMOVE":
            return GuildBanRemoveEvent(
                guildId: data["guild_id"] as! String,
                userId: (data["user"] as! [String: Any])["id"] as! String
            )
        case "GUILD_EMOJIS_UPDATE":
            let emojis = (data["emojis"] as! [Any]).compactMap { item -> Components.Schemas.GuildEmojiResponse? in
                guard let map = item as? [String: Any] else { return nil }
                return try? GatewayDecoding.decode(Components.Schemas.GuildEmojiResponse.self, from: map)
            }
            return GuildEmojisUpdateEvent(guildId: data["guild_id"] as! String, emojis: emojis)
        case "GUILD_STICKERS_UPDATE":
            let stickers = (data["stickers"] as! [Any]).compactMap { item -> Components.Schemas.GuildStickerResponse? in
                guard let map = item as? [String: Any] else { return nil }
                return try? GatewayDecoding.decode(Components.Schemas.GuildStickerResponse.self, from: map)
            }
            return GuildStickersUpdateEvent(guildId: data["guild_id"] as! String, stickers: stickers)
        case "GUILD_SYNC":
            return GuildSyncEvent(guild: try GuildCreateData.fromJSON(data))
        case "GUILD_MEMBERS_CHUNK":
            let members = (data["members"] as! [Any]).compactMap { item -> Components.Schemas.GuildMemberResponse? in
                guard let map = item as? [String: Any] else { return nil }
                return try? GatewayDecoding.decode(Components.Schemas.GuildMemberResponse.self, from: map)
            }
            return GuildMembersChunkEvent(
                guildId: data["guild_id"] as! String,
                members: members,
                chunkIndex: (data["chunk_index"] as! NSNumber).intValue,
                chunkCount: (data["chunk_count"] as! NSNumber).intValue,
                presences: data["presences"] as? [[String: Any]],
                nonce: data["nonce"] as? String
            )
        case "GUILD_MEMBER_LIST_UPDATE":
            return try parseMemberListUpdate(data)
        case "PRESENCE_UPDATE_BULK":
            return PresenceUpdateBulkEvent(
                presences: data["presences"] as! [[String: Any]],
                guildId: data["guild_id"] as? String
            )
        case "VOICE_STATE_UPDATE":
            return VoiceStateUpdateEvent(
                state: VoiceState.fromJSON(data),
                member: parseEmbeddedMember(data["member"])
            )
        case "VOICE_SERVER_UPDATE":
            if data["p2p"] as? Bool == true {
                let iceServers = (data["ice_servers"] as! [Any]).compactMap { server -> VoiceIceServer? in
                    guard let map = server as? [String: Any], let urls = map["urls"] as? [String] else { return nil }
                    return VoiceIceServer(urls: urls)
                }
                return VoiceServerP2pUpdateEvent(
                    connectionId: data["connection_id"] as! String,
                    iceServers: iceServers,
                    guildId: data["guild_id"] as? String,
                    channelId: data["channel_id"] as? String
                )
            }
            return VoiceServerUpdateEvent(
                token: data["token"] as! String,
                endpoint: data["endpoint"] as! String,
                connectionId: data["connection_id"] as! String,
                guildId: data["guild_id"] as? String,
                channelId: data["channel_id"] as? String,
                e2eeKey: data["e2ee_key"] as? String
            )
        case "VOICE_SIGNAL":
            return VoiceSignalEvent(
                channelId: data["channel_id"] as! String,
                from: data["from"] as! String,
                userId: data["user_id"] as! String,
                data: data["data"] as! [String: Any],
                guildId: data["guild_id"] as? String
            )
        case "CALL_CREATE":
            return parseCallCreate(data)
        case "CALL_UPDATE":
            return parseCallUpdate(data)
        case "CALL_DELETE":
            return CallDeleteEvent(channelId: data["channel_id"] as! String)
        case "ENTRANCE_SOUND_PLAY":
            return EntranceSoundPlayEvent(
                userId: data["user_id"] as! String,
                channelId: data["channel_id"] as! String,
                soundId: data["sound_id"] as! String,
                hash: data["hash"] as! String,
                url: data["url"] as! String,
                durationMs: (data["duration_ms"] as! NSNumber).intValue,
                contentType: data["content_type"] as! String,
                guildId: data["guild_id"] as? String
            )
        case "GUILD_COUNTS_UPDATE":
            return GuildCountsUpdateEvent(counts: parseGuildCountEntries(data["counts"]))
        case "CHANNEL_MEMBER_COUNTS_UPDATE":
            return ChannelMemberCountsUpdateEvent(counts: parseChannelMemberCountEntries(data["counts"]))
        case "INVITE_CREATE":
            return InviteCreateEvent(data: data)
        case "INVITE_DELETE":
            return InviteDeleteEvent(code: data["code"] as! String, guildId: data["guild_id"] as! String)
        case "SAVED_MESSAGE_CREATE":
            return SavedMessageCreateEvent(
                message: try GatewayDecoding.decode(Components.Schemas.MessageResponseSchema.self, from: data)
            )
        case "SAVED_MESSAGE_DELETE":
            return SavedMessageDeleteEvent(messageId: data["message_id"] as! String)
        case "RECENT_MENTION_DELETE":
            return RecentMentionDeleteEvent(messageId: data["message_id"] as! String)
        case "WEBHOOKS_UPDATE":
            return WebhooksUpdateEvent(channelId: data["channel_id"] as! String, guildId: data["guild_id"] as! String)
        case "FAVORITE_MEME_CREATE":
            return FavoriteMemeCreateEvent(data: data)
        case "FAVORITE_MEME_UPDATE":
            return FavoriteMemeUpdateEvent(data: data)
        case "FAVORITE_MEME_DELETE":
            return FavoriteMemeDeleteEvent(id: snowflakeId(data["id"] ?? data["meme_id"]) ?? "")
        case "SESSIONS_REPLACE":
            return SessionsReplaceEvent()
        default:
            return UnknownGatewayEvent(eventType: eventType, data: data)
        }

    }

    private func parseEmbeddedMember(_ member: Any?, user: Any? = nil) -> Components.Schemas.GuildMemberResponse? {
        guard var map = member as? [String: Any] else { return nil }
        if let user { map["user"] = user }
        return try? GatewayDecoding.decode(Components.Schemas.GuildMemberResponse.self, from: map)
    }

    private func parseReady(_ data: [String: Any]) throws -> ReadyEvent {
        let rawGuildsList = data["guilds"] as? [Any] ?? []
        let rawGuilds = rawGuildsList.compactMap { $0 as? [String: Any] }
        let guilds = parseListSafe(data["guilds"]) { GuildReadyData.fromJSON($0 as! [String: Any]) }
        let privateChannels = parseListSafe(data["private_channels"]) {
            try GatewayDecoding.decode(Components.Schemas.ChannelResponse.self, from: $0 as! [String: Any])
        }
        var usersById: [String: Any] = [:]
        for user in data["users"] as? [Any] ?? [] {
            guard let map = user as? [String: Any], let id = map["id"] as? String else { continue }
            usersById[id] = map
        }
        let relationships = parseListSafe(data["relationships"]) { raw in
            var map = raw as! [String: Any]
            if map["user"] == nil, let id = map["id"] as? String, let user = usersById[id] {
                map["user"] = user
            }
            return try parseRelationship(map)
        }
        let readStates = parseListSafe(data["read_states"]) { GatewayReadState.fromJSON($0 as! [String: Any]) }
        let presences = (data["presences"] as? [[String: Any]]) ?? []
        let userSettings = (data["user_settings"] as? [String: Any]).flatMap {
            try? GatewayDecoding.decode(Components.Schemas.UserSettingsResponse.self, from: $0)
        }
        let userGuildSettings = (data["user_guild_settings"] as? [Any])?.compactMap { item -> Components.Schemas.UserGuildSettingsResponse? in
            guard let map = item as? [String: Any] else { return nil }
            return try? GatewayDecoding.decode(Components.Schemas.UserGuildSettingsResponse.self, from: map)
        }
        let notes = data["notes"] as? [String: String]
        let pinnedDms = data["pinned_dms"] as? [String]
        let favoriteMemes = data["favorite_memes"] as? [[String: Any]]
        let users = data["users"] as? [[String: Any]]
        let rtcRegions = data["rtc_regions"] as? [[String: Any]]
        return ReadyEvent(
            sessionId: data["session_id"] as! String,
            user: try GatewayDecoding.decode(Components.Schemas.UserPrivateResponse.self, from: data["user"] as! [String: Any]),
            guilds: guilds,
            rawGuilds: rawGuilds,
            privateChannels: privateChannels,
            relationships: relationships,
            readStates: readStates,
            presences: presences,
            userSettings: userSettings,
            userGuildSettings: userGuildSettings,
            notes: notes,
            countryCode: data["country_code"] as? String,
            pinnedDms: pinnedDms,
            favoriteMemes: favoriteMemes,
            users: users,
            authSessionIdHash: data["auth_session_id_hash"] as? String,
            rtcRegions: rtcRegions
        )
    }

    private func parseRelationship(_ raw: Any) throws -> Components.Schemas.RelationshipResponse {
        var json = raw as! [String: Any]
        if json["share_voice_activity"] == nil { json["share_voice_activity"] = true }
        if json["friend_shares_voice_activity"] == nil { json["friend_shares_voice_activity"] = true }
        return try GatewayDecoding.decode(Components.Schemas.RelationshipResponse.self, from: json)
    }

    private func parseGuildCountEntries(_ raw: Any?) -> [GuildCountEntry] {
        guard let list = raw as? [Any] else { return [] }
        var counts: [GuildCountEntry] = []
        for item in list {
            guard let map = item as? [String: Any],
                  let guildId = map["guild_id"] as? String,
                  let memberCount = (map["member_count"] as? NSNumber)?.intValue,
                  let onlineCount = (map["online_count"] as? NSNumber)?.intValue else { continue }
            counts.append(GuildCountEntry(guildId: guildId, memberCount: memberCount, onlineCount: onlineCount))
        }
        return counts
    }

    private func parseChannelMemberCountEntries(_ raw: Any?) -> [ChannelMemberCountEntry] {
        guard let list = raw as? [Any] else { return [] }
        var counts: [ChannelMemberCountEntry] = []
        for item in list {
            guard let map = item as? [String: Any],
                  let guildId = map["guild_id"] as? String,
                  let channelId = map["channel_id"] as? String,
                  let memberCount = (map["member_count"] as? NSNumber)?.intValue,
                  let onlineCount = (map["online_count"] as? NSNumber)?.intValue else { continue }
            counts.append(ChannelMemberCountEntry(
                guildId: guildId, channelId: channelId, memberCount: memberCount, onlineCount: onlineCount
            ))
        }
        return counts
    }

    private func parsePresenceUpdate(_ data: [String: Any]) -> PresenceUpdateEvent {
        let user = data["user"] as? [String: Any]
        let userId = (user?["id"] as? String) ?? (data["user_id"] as! String)
        let customStatusMap = data["custom_status"] as? [String: Any]
        return PresenceUpdateEvent(
            userId: userId,
            status: data["status"] as! String,
            customStatus: serializeCustomStatusMap(customStatusMap),
            mobile: data["mobile"] as? Bool ?? false,
            user: parsePresenceUser(user)
        )
    }

    private func parsePresenceUser(_ user: [String: Any]?) -> Components.Schemas.UserPartialResponse? {
        guard let user, user["username"] != nil else { return nil }
        return try? GatewayDecoding.decode(Components.Schemas.UserPartialResponse.self, from: user)
    }

    private func parseMemberListUpdate(_ data: [String: Any]) throws -> GuildMemberListUpdateEvent {
        let groups = (data["groups"] as! [Any]).map { MemberListGroup.fromJSON($0 as! [String: Any]) }
        let ops = try (data["ops"] as! [Any]).map { try MemberListOp.fromJSON($0 as! [String: Any]) }
        return GuildMemberListUpdateEvent(
            guildId: data["guild_id"] as! String,
            id: data["id"] as! String,
            channelId: data["channel_id"] as? String,
            memberCount: data["member_count"] as! Int,
            onlineCount: data["online_count"] as! Int,
            groups: groups,
            ops: ops
        )
    }

    private func parseCallCreate(_ data: [String: Any]) -> CallCreateEvent {
        CallCreateEvent(
            channelId: data["channel_id"] as! String,
            messageId: data["message_id"] as? String,
            region: data["region"] as? String,
            voiceStates: (data["voice_states"] as? [[String: Any]])?.map { VoiceState.fromJSON($0) },
            ringing: data["ringing"] as? [String]
        )
    }

    private func parseCallUpdate(_ data: [String: Any]) -> CallUpdateEvent {
        CallUpdateEvent(
            channelId: data["channel_id"] as! String,
            messageId: data["message_id"] as? String,
            region: data["region"] as? String,
            ringing: data["ringing"] as? [String],
            voiceStates: (data["voice_states"] as? [[String: Any]])?.map { VoiceState.fromJSON($0) }
        )
    }

    private func parsePassiveUpdates(_ data: [String: Any]) -> PassiveUpdatesEvent {
        let channelsRaw = data["channels"] as? [String: Any] ?? [:]
        var channels: [String: String] = [:]
        for (key, value) in channelsRaw {
            channels[key] = value as? String ?? String(describing: value)
        }
        return PassiveUpdatesEvent(
            guildId: data["guild_id"] as! String,
            channels: channels,
            voiceStates: (data["voice_states"] as? [[String: Any]])?.map { VoiceState.fromJSON($0) }
        )
    }
}

private func snowflakeId(_ value: Any?) -> String? {
    if let string = value as? String {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    if let int = value as? NSNumber { return int.stringValue }
    return nil
}

