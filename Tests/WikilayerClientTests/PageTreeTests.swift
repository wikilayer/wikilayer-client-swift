import Foundation
import SwiftEmbed
import Testing

@testable import WikilayerClient

@Suite("The pages of a wiki, as their author nested them")
struct PageTreeTests {
    private struct Cases: Codable {
        let trees: [Tree]
        let shape: [Shape]
        let outline: [Outline]
        let neighbours: [Neighbours]
        let noNeighbours: [Nowhere]
        let ancestors: [Ancestors]
    }

    private struct Tree: Codable {
        let name: String
        let pages: [Page]
    }

    private struct Page: Codable {
        let id: Int64
        let parent: Int64
        let title: String
        let sort: String
        let home: Bool

        init(from decoder: Decoder) throws {
            let fields = try decoder.container(keyedBy: CodingKeys.self)
            id = try fields.decode(Int64.self, forKey: .id)
            parent = try fields.decode(Int64.self, forKey: .parent)
            title = try fields.decode(String.self, forKey: .title)
            sort = try fields.decodeIfPresent(String.self, forKey: .sort) ?? "10"
            home = try fields.decodeIfPresent(Bool.self, forKey: .home) ?? false
        }
    }

    private struct Shape: Codable, CustomTestStringConvertible {
        let `case`: String
        let tree: String
        let roots: [Int64]
        let children: [Children]

        var testDescription: String { `case` }
    }

    private struct Children: Codable {
        let page: Int64
        let pages: [Int64]
    }

    private struct Outline: Codable, CustomTestStringConvertible {
        let `case`: String
        let tree: String
        let expanded: [Int64]
        let rows: [Row]

        var testDescription: String { `case` }
    }

    private struct Row: Codable {
        let page: Int64
        let depth: Int
        let branches: Bool
    }

    private struct Neighbours: Codable, CustomTestStringConvertible {
        let `case`: String
        let tree: String
        let page: Int64
        let previous: Int64
        let next: Int64

        var testDescription: String { `case` }
    }

    private struct Nowhere: Codable, CustomTestStringConvertible {
        let `case`: String
        let tree: String
        let page: Int64

        var testDescription: String { `case` }
    }

    private struct Ancestors: Codable, CustomTestStringConvertible {
        let `case`: String
        let tree: String
        let page: Int64
        let above: [Int64]

        var testDescription: String { `case` }
    }

    private static let cases: Cases = Embedded.getYAML(
        Bundle.module,
        path: "page_tree_tests.yaml"
    )

    private static func tree(_ name: String) -> [PageBranch] {
        guard let held = cases.trees.first(where: { $0.name == name }) else {
            fatalError("page_tree_tests.yaml has no tree named \(name)")
        }
        return held.pages.map {
            PageInTree(
                id: $0.id,
                parentID: $0.parent,
                title: $0.title,
                sortKey: $0.sort,
                isHome: $0.home
            )
        }.pageTree
    }

    private static func branch(_ id: Int64, in tree: [PageBranch]) -> PageBranch? {
        for branch in tree {
            if branch.id == id { return branch }
            if let deeper = self.branch(id, in: branch.children) { return deeper }
        }
        return nil
    }

    @Test("pages nest by their parents", arguments: cases.shape)
    private func shape(_ expected: Shape) throws {
        let tree = Self.tree(expected.tree)

        #expect(tree.map(\.id) == expected.roots)
        for held in expected.children {
            let branch = try #require(Self.branch(held.page, in: tree), "page \(held.page)")
            #expect(branch.children.map(\.id) == held.pages, "under \(held.page)")
        }
    }

    @Test("the tree reads as a list of rows", arguments: cases.outline)
    private func outline(_ expected: Outline) {
        let rows = Self.tree(expected.tree).outline(expanded: Set(expected.expanded))

        #expect(rows.map(\.id) == expected.rows.map(\.page))
        #expect(rows.map(\.depth) == expected.rows.map(\.depth))
        #expect(rows.map(\.hasChildren) == expected.rows.map(\.branches))
    }

    @Test("a page has the page before it and the page after it", arguments: cases.neighbours)
    private func neighbours(_ expected: Neighbours) throws {
        let found = try #require(Self.tree(expected.tree).neighbours(of: expected.page))

        #expect(found.previous.id == expected.previous)
        #expect(found.next.id == expected.next)
    }

    @Test("a page with nowhere to step says so", arguments: cases.noNeighbours)
    private func noNeighbours(_ expected: Nowhere) {
        #expect(Self.tree(expected.tree).neighbours(of: expected.page) == nil)
    }

    @Test("a page names the pages above it", arguments: cases.ancestors)
    private func ancestors(_ expected: Ancestors) {
        #expect(Self.tree(expected.tree).ancestors(of: expected.page) == expected.above)
    }

    @Test("a repeated id is not drawn twice")
    private func duplicatesAreKeptOnce() {
        let rows = Self.tree("twice over").outline(expanded: [10])

        #expect(rows.map(\.id) == [10, 11], "a duplicate would show as two rows sharing an id")
    }
}
