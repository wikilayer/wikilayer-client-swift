import Foundation

/// The structural role of a synchronized node.
public enum NodeKind: String, Codable, Sendable {
    case wiki
    case page
    case block
}

/// The complete synchronized representation of one wiki node.
public struct SyncNode: Codable, Sendable, Equatable {
    public let id: Int64
    public let path: String
    public let kind: NodeKind
    public let specialRole: String
    public let title: String
    public let markdown: String
    public let language: String

    public let sortKey: String

    public let pageID: Int64

    public let translationGroup: Int64
    public let changedAt: Date
    public let deleted: Bool

    public init(
        id: Int64,
        path: String,
        kind: NodeKind,
        changedAt: Date,
        specialRole: String = "",
        title: String = "",
        markdown: String = "",
        language: String = "",
        sortKey: String = "",
        pageID: Int64 = 0,
        translationGroup: Int64 = 0,
        deleted: Bool = false
    ) {
        self.id = id
        self.path = path
        self.kind = kind
        self.specialRole = specialRole
        self.title = title
        self.markdown = markdown
        self.language = language
        self.sortKey = sortKey
        self.pageID = pageID
        self.translationGroup = translationGroup
        self.changedAt = changedAt
        self.deleted = deleted
    }

    enum CodingKeys: String, CodingKey {
        case id, path, kind, title, markdown, language, deleted
        case specialRole = "special_role"
        case sortKey = "sort_key"
        case pageID = "page_id"
        case translationGroup = "translation_group"
        case changedAt = "changed_at"
    }

    public init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = try box.decode(Int64.self, forKey: .id)
        path = try box.decodeIfPresent(String.self, forKey: .path) ?? ""
        kind = try box.decodeIfPresent(NodeKind.self, forKey: .kind) ?? .block
        specialRole = try box.decodeIfPresent(String.self, forKey: .specialRole) ?? ""
        title = try box.decodeIfPresent(String.self, forKey: .title) ?? ""
        markdown = try box.decodeIfPresent(String.self, forKey: .markdown) ?? ""
        language = try box.decodeIfPresent(String.self, forKey: .language) ?? ""
        sortKey = try box.decodeIfPresent(String.self, forKey: .sortKey) ?? ""
        pageID = try box.decodeIfPresent(Int64.self, forKey: .pageID) ?? 0
        translationGroup = try box.decodeIfPresent(Int64.self, forKey: .translationGroup) ?? 0
        changedAt = try box.decode(Date.self, forKey: .changedAt)
        deleted = try box.decodeIfPresent(Bool.self, forKey: .deleted) ?? false
    }

    public var nodePath: NodePath { NodePath(path) }

    public var parentID: Int64 { nodePath.parent }

    public var depth: Int { nodePath.depth }
}

/// An ordered page of synchronized nodes and the cursor that follows it.
public struct SyncBatch: Decodable, Sendable {
    public let nodes: [SyncNode]
    public let hasMore: Bool
    public let cursor: String?

    enum CodingKeys: String, CodingKey {
        case nodes
        case hasMore = "has_more"
        case cursor = "next_cursor"
    }

    public init(nodes: [SyncNode], hasMore: Bool, cursor: String? = nil) {
        self.nodes = nodes
        self.hasMore = hasMore
        self.cursor = cursor
    }

    public init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        nodes = try box.decode([SyncNode].self, forKey: .nodes)
        hasMore = try box.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
        cursor = try box.decodeIfPresent(String.self, forKey: .cursor)
    }
}
