import Foundation

/// The account returned for the current credential.
public struct Account: Codable, Sendable, Identifiable, Equatable {
    public let id: Int64
    public let displayName: String
    public let email: String
    public let avatarURL: URL?
    public let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case email
        case avatarURL = "avatar_url"
        case createdAt = "created_at"
    }

    public init(
        id: Int64,
        displayName: String,
        email: String = "",
        avatarURL: URL? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.avatarURL = avatarURL
        self.createdAt = createdAt
    }

    public init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = try box.decode(Int64.self, forKey: .id)
        displayName = try box.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        email = try box.decodeIfPresent(String.self, forKey: .email) ?? ""
        avatarURL = try box.decodeIfPresent(URL.self, forKey: .avatarURL)
        createdAt = try box.decodeIfPresent(String.self, forKey: .createdAt).map(
            WikiAPI.parseWireDate
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var box = encoder.container(keyedBy: CodingKeys.self)
        try box.encode(id, forKey: .id)
        try box.encode(displayName, forKey: .displayName)
        try box.encode(email, forKey: .email)
        try box.encodeIfPresent(avatarURL, forKey: .avatarURL)
        try box.encodeIfPresent(createdAt.map(WikiAPI.wireString), forKey: .createdAt)
    }
}

/// A bearer token accepted by authenticated Wikilayer requests.
public struct Credential: Codable, Sendable, Equatable {
    public let token: String

    public init(token: String) {
        self.token = token
    }
}

struct TokenGrant: Decodable, Sendable {
    let accessToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }

    func credential() -> Credential {
        Credential(token: accessToken)
    }
}
