import Foundation

/// The visibility reported for a wiki owned by the current account.
public enum WikiVisibility: String, Codable, Sendable {
    case `public`
    case `private`
}

/// One wiki in the authenticated account's cursor-based listing.
public struct MyWiki: Decodable, Sendable, Equatable {
    public let id: Int64
    public let title: String
    public let urlPath: String
    public let updatedAt: Date?
    public let visibility: WikiVisibility?
    public let mine: Bool

    public let removed: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case urlPath = "url_path"
        case updatedAt = "updated_at"
        case visibility
        case mine
        case removed
    }

    public init(
        id: Int64,
        title: String = "",
        urlPath: String = "",
        updatedAt: Date? = nil,
        visibility: WikiVisibility? = nil,
        mine: Bool = false,
        removed: Bool = false
    ) {
        self.id = id
        self.title = title
        self.urlPath = urlPath
        self.updatedAt = updatedAt
        self.visibility = visibility
        self.mine = mine
        self.removed = removed
    }

    public init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = try box.decode(Int64.self, forKey: .id)
        title = try box.decodeIfPresent(String.self, forKey: .title) ?? ""
        urlPath = try box.decodeIfPresent(String.self, forKey: .urlPath) ?? ""
        updatedAt = try box.decodeIfPresent(Date.self, forKey: .updatedAt)
        visibility = try box.decodeIfPresent(WikiVisibility.self, forKey: .visibility)
        mine = try box.decodeIfPresent(Bool.self, forKey: .mine) ?? false
        removed = try box.decodeIfPresent(Bool.self, forKey: .removed) ?? false
    }
}

/// A page of wikis belonging to the authenticated account.
public struct MyWikiPage: Decodable, Sendable {
    public let wikis: [MyWiki]
    public let hasMore: Bool
    public let cursor: String?

    enum CodingKeys: String, CodingKey {
        case wikis
        case hasMore = "has_more"
        case cursor = "next_cursor"
    }

    public init(wikis: [MyWiki], hasMore: Bool, cursor: String? = nil) {
        self.wikis = wikis
        self.hasMore = hasMore
        self.cursor = cursor
    }

    public init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        wikis = try box.decode([MyWiki].self, forKey: .wikis)
        hasMore = try box.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
        cursor = try box.decodeIfPresent(String.self, forKey: .cursor)
    }
}
