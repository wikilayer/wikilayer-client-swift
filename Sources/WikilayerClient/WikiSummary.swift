import Foundation

/// One entry in the public wiki directory.
public struct WikiSummary: Codable, Sendable, Identifiable, Equatable {
    public let id: Int64
    public let title: String
    public let urlPath: String
    public let iconURL: URL?
    public let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case urlPath = "url_path"
        case iconURL = "icon_url"
        case updatedAt = "updated_at"
    }

    public init(
        id: Int64,
        title: String,
        urlPath: String,
        updatedAt: Date,
        iconURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.urlPath = urlPath
        self.iconURL = iconURL
        self.updatedAt = updatedAt
    }

    public init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = try box.decode(Int64.self, forKey: .id)
        title = try box.decodeIfPresent(String.self, forKey: .title) ?? ""
        urlPath = try box.decodeIfPresent(String.self, forKey: .urlPath) ?? ""
        iconURL = try box.decodeIfPresent(URL.self, forKey: .iconURL)
        updatedAt = try box.decode(Date.self, forKey: .updatedAt)
    }
}

/// The wiki and node identified by a Wikilayer URL.
public struct ResolvedAddress: Codable, Sendable, Equatable {
    public let wikiID: Int64
    public let nodeID: Int64
    public let language: String
    public let wikiTitle: String
    public let wikiURLPath: String
    public let wikiIconURL: URL?

    enum CodingKeys: String, CodingKey {
        case wikiID = "wiki_id"
        case nodeID = "node_id"
        case language
        case wikiTitle = "wiki_title"
        case wikiURLPath = "wiki_url_path"
        case wikiIconURL = "wiki_icon_url"
    }

    public init(
        wikiID: Int64,
        nodeID: Int64,
        language: String = "",
        wikiTitle: String = "",
        wikiURLPath: String = "",
        wikiIconURL: URL? = nil
    ) {
        self.wikiID = wikiID
        self.nodeID = nodeID
        self.language = language
        self.wikiTitle = wikiTitle
        self.wikiURLPath = wikiURLPath
        self.wikiIconURL = wikiIconURL
    }

    public init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        wikiID = try box.decode(Int64.self, forKey: .wikiID)
        nodeID = try box.decode(Int64.self, forKey: .nodeID)
        language = try box.decodeIfPresent(String.self, forKey: .language) ?? ""
        wikiTitle = try box.decodeIfPresent(String.self, forKey: .wikiTitle) ?? ""
        wikiURLPath = try box.decodeIfPresent(String.self, forKey: .wikiURLPath) ?? ""
        wikiIconURL = try box.decodeIfPresent(URL.self, forKey: .wikiIconURL)
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
