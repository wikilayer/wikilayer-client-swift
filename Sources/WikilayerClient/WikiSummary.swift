import Foundation

/// One entry in the public wiki directory.
public struct WikiSummary: Codable, Sendable, Identifiable, Equatable {
    public let id: Int64
    public let title: String
    public let urlPath: String
    public let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case urlPath = "url_path"
        case updatedAt = "updated_at"
    }

    public init(id: Int64, title: String, urlPath: String, updatedAt: Date) {
        self.id = id
        self.title = title
        self.urlPath = urlPath
        self.updatedAt = updatedAt
    }
}

/// The wiki and node identified by a Wikilayer URL.
public struct ResolvedAddress: Codable, Sendable, Equatable {
    public let wikiID: Int64
    public let nodeID: Int64
    public let language: String
    public let wikiTitle: String
    public let wikiURLPath: String

    enum CodingKeys: String, CodingKey {
        case wikiID = "wiki_id"
        case nodeID = "node_id"
        case language
        case wikiTitle = "wiki_title"
        case wikiURLPath = "wiki_url_path"
    }

    public init(
        wikiID: Int64,
        nodeID: Int64,
        language: String = "",
        wikiTitle: String = "",
        wikiURLPath: String = ""
    ) {
        self.wikiID = wikiID
        self.nodeID = nodeID
        self.language = language
        self.wikiTitle = wikiTitle
        self.wikiURLPath = wikiURLPath
    }

    public init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        wikiID = try box.decode(Int64.self, forKey: .wikiID)
        nodeID = try box.decode(Int64.self, forKey: .nodeID)
        language = try box.decodeIfPresent(String.self, forKey: .language) ?? ""
        wikiTitle = try box.decodeIfPresent(String.self, forKey: .wikiTitle) ?? ""
        wikiURLPath = try box.decodeIfPresent(String.self, forKey: .wikiURLPath) ?? ""
    }
}

/// An offset-based page of public directory entries.
public struct WikiPage: Codable, Sendable {
    public let wikis: [WikiSummary]
    public let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case wikis
        case hasMore = "has_more"
    }

    public init(wikis: [WikiSummary], hasMore: Bool) {
        self.wikis = wikis
        self.hasMore = hasMore
    }
}
