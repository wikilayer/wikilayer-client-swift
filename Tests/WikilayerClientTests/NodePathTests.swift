import Foundation
import Testing

@testable import WikilayerClient

@Suite("Where a node sits in its wiki")
struct NodePathTests {
    @Test("the ids run from the wiki down, joined by dots")
    func theFormat() {
        let block = NodePath("2982.4401.3903")

        #expect(block.wiki == 2982)
        #expect(block.page == 4401)
        #expect(block.parent == 4401)
        #expect(block.depth == 2)
    }

    @Test("a wiki answers with itself and sits on no page")
    func theRoot() {
        let root = NodePath("2982")

        #expect(root.wiki == 2982)
        #expect(root.page == NodePath.none)
        #expect(root.parent == NodePath.none)
        #expect(root.depth == 0)
    }

    @Test("a page is its own page and hangs from its wiki")
    func aPage() {
        let page = NodePath("2982.4401")

        #expect(page.page == 4401)
        #expect(page.parent == 2982)
        #expect(page.depth == 1)
    }

    @Test("a path that names no wiki answers with nothing rather than guessing")
    func nothingToRead() {
        #expect(NodePath("").wiki == NodePath.none)
        #expect(NodePath("wiki.page").wiki == NodePath.none)
        #expect(NodePath("").depth == 0)
    }

    @Test("a node descends from every id above it, and from no id beside it")
    func ancestry() {
        let block = NodePath("1.10.11.12")

        #expect(block.descends(from: 1))
        #expect(block.descends(from: 10))
        #expect(block.descends(from: 11))
        #expect(block.descends(from: 12) == false)
        #expect(block.descends(from: 2) == false)
    }

    @Test("a node sits inside itself and inside every page above it")
    func containment() {
        let page = NodePath("1.10")

        #expect(NodePath("1.10.11").sitsInside(page))
        #expect(page.sitsInside(page))
        #expect(NodePath("1.100").sitsInside(page) == false)
        #expect(NodePath("1.20.21").sitsInside(page) == false)
    }
}
