import Foundation

public enum GatewayJSON {
    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom(GatewayDateCoding.encode)
        return encoder
    }()

    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(GatewayDateCoding.decode)
        return decoder
    }()
}

public enum GatewayDecoding {
    public static func decode<T: Decodable>(_ type: T.Type, from json: [String: Any]) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: json)
        return try GatewayJSON.decoder.decode(type, from: data)
    }

    public static func decode<T: Decodable>(_ type: T.Type, from json: Any) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: json)
        return try GatewayJSON.decoder.decode(type, from: data)
    }

    static func int(_ json: [String: Any], key: String) -> Int? {
        if let value = json[key] as? Int { return value }
        if let number = json[key] as? NSNumber { return number.intValue }
        return nil
    }

    static func string(_ json: [String: Any], key: String) -> String? {
        json[key] as? String
    }
}

enum GatewayDateCoding {
    nonisolated(unsafe) private static let formatters: [ISO8601DateFormatter] = {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return [withFraction, plain]
    }()

    static func decode(_ decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        if let timestamp = try? container.decode(Double.self) {
            return Date(timeIntervalSince1970: timestamp)
        }
        let string = try container.decode(String.self)
        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
    }

    static func encode(_ date: Date, encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let formatter = formatters[0]
        try container.encode(formatter.string(from: date))
    }
}
