import Foundation

public func customStatusMapHasEmoji(_ map: [String: Any]) -> Bool {
    let emojiId = map["emoji_id"]
    let emojiName = map["emoji_name"] as? String
    return emojiId != nil || (emojiName != nil && !emojiName!.isEmpty)
}

public func serializeCustomStatusMap(_ map: [String: Any]?) -> String? {
    guard let map, !map.isEmpty else { return nil }
    let text = (map["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    if !customStatusMapHasEmoji(map) {
        guard let text, !text.isEmpty else { return nil }
        return text
    }
    do {
        let status = try GatewayDecoding.decode(Components.Schemas.CustomStatusResponse.self, from: map)
        let data = try GatewayJSON.encoder.encode(status)
        return String(data: data, encoding: .utf8)
    } catch {
        let data = try? JSONSerialization.data(withJSONObject: map)
        guard let data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

public func serializeCustomStatusResponse(_ status: Components.Schemas.CustomStatusResponse?) -> String? {
    guard let status else { return nil }
    let text = status.text?.trimmingCharacters(in: .whitespacesAndNewlines)
    let hasEmoji = status.emojiId != nil
        || (status.emojiName != nil && !status.emojiName!.isEmpty)
    if !hasEmoji {
        guard let text, !text.isEmpty else { return nil }
        return text
    }
    let data = try? GatewayJSON.encoder.encode(status)
    guard let data else { return nil }
    return String(data: data, encoding: .utf8)
}
