import Foundation
import Testing

@testable import WikilayerClient

private func stubbedAPI() -> (WikiAPI, StubbedSession) {
    let stub = StubServer.open()
    let api = WikiAPI(
        baseURL: URL(string: "https://wikilayer.org") ?? URL.temporaryDirectory,
        session: stub.session
    )
    return (api, stub)
}

@Suite("Reading a wiki off the server")
struct WikiAPITests {
    @Test("a first sync asks for the whole wiki and reads nodes out of the answer")
    func firstSync() async throws {
        let (api, stub) = stubbedAPI()
        stub.answers(
            """
            {"nodes":[
              {"id":2982,"path":"2982","kind":"wiki","title":"Guide","language":"en",
               "changed_at":"2026-08-25T10:00:00.5Z"},
              {"id":4401,"path":"2982.4401","kind":"page","title":"Agent rules","sort_key":"10",
               "changed_at":"2026-08-25T10:00:01Z"}
            ],"has_more":true}
            """
        )

        let batch = try await api.sync(wikiID: 2982, after: nil)

        #expect(batch.nodes.count == 2)
        #expect(batch.hasMore)
        #expect(batch.nodes[0].kind == .wiki)
        #expect(batch.nodes[1].parentID == 2982)
        #expect(batch.nodes[1].depth == 1)

        let asked = try #require(stub.lastAsked?.url?.absoluteString)
        #expect(asked.contains("/api/wikis/2982/sync"))
        #expect(!asked.contains("since="), "a first sync must not carry a cursor")
    }

    @Test("every node says which page it belongs to, and the server is the one that knows")
    func thePageANodeBelongsTo() async throws {
        let (api, stub) = stubbedAPI()
        stub.answers(
            """
            {"nodes":[
              {"id":2982,"path":"2982","kind":"wiki","title":"Guide",
               "changed_at":"2026-08-25T10:00:00Z"},
              {"id":4401,"path":"2982.4401","kind":"page","title":"Agent rules","page_id":4401,
               "changed_at":"2026-08-25T10:00:01Z"},
              {"id":4402,"path":"2982.4401.4402","kind":"page","title":"Nested","page_id":4402,
               "changed_at":"2026-08-25T10:00:02Z"},
              {"id":4403,"path":"2982.4401.4402.4403","kind":"block","title":"Under the nested page",
               "page_id":4402,"changed_at":"2026-08-25T10:00:03Z"}
            ],"has_more":false}
            """
        )

        let batch = try await api.sync(wikiID: 2982, after: nil)

        let pages = Dictionary(uniqueKeysWithValues: batch.nodes.map { ($0.id, $0.pageID) })
        #expect(
            pages[4403] == 4402,
            "a path carries ids and no kinds, so a reader that worked this out itself would stitch the block into the page above"
        )
        #expect(pages[4402] == 4402, "a page belongs to its own document")
        #expect(pages[4401] == 4401)
        #expect(pages[2982] == 0, "the wiki belongs to no page")
    }

    @Test("a wiki in the directory carries its icon and whether it keeps pages under pages")
    func directoryRowDescribesTheWiki() async throws {
        let (api, stub) = stubbedAPI()
        stub.answers(
            """
            {"wikis":[
              {"id":2982,"title":"Guide","url_path":"/smee-again/guide",
               "icon_url":"https://wikilayer.org/s/icons/2982/abcdefgh.png","pages_tree":true,
               "updated_at":"2026-08-25T10:00:00Z"},
              {"id":1025,"title":"Flat","url_path":"/smee-again/flat",
               "updated_at":"2026-08-25T10:00:00Z"}
            ],"has_more":false}
            """
        )

        let page = try await api.wikis(matching: "guide")

        #expect(page.wikis[0].iconURL?.lastPathComponent == "abcdefgh.png")
        #expect(page.wikis[0].pagesTree)
        #expect(page.wikis[1].iconURL == nil, "a wiki with no icon says nothing about one")
        #expect(!page.wikis[1].pagesTree)
    }

    @Test("the directory answers with wikis to follow, and says whether there are more")
    func directory() async throws {
        let (api, stub) = stubbedAPI()
        stub.answers(
            """
            {"wikis":[
              {"id":2982,"title":"Wikilayer authoring guide","url_path":"/smee-again/wikilayer-howto",
               "updated_at":"2026-08-25T10:00:00.5Z"}
            ],"has_more":true}
            """
        )

        let page = try await api.wikis(matching: "guide")

        #expect(page.wikis.count == 1)
        #expect(page.wikis[0].id == 2982)
        #expect(page.wikis[0].title == "Wikilayer authoring guide")
        #expect(page.hasMore)

        let asked = try #require(stub.lastAsked?.url?.absoluteString)
        #expect(asked.contains("/api/wikis"))
        #expect(asked.contains("q=guide"))
    }

    @Test("a link from outside is handed to the server, which says what it points at")
    func resolvingALink() async throws {
        let (api, stub) = stubbedAPI()
        stub.answers(#"{"wiki_id":2982,"node_id":39340,"language":"en"}"#)
        let link = try #require(
            URL(string: "https://wikilayer.org/smee-again/howto/4401#block-39340")
        )

        let found = try await api.resolve(link)

        #expect(found.wikiID == 2982)
        #expect(found.nodeID == 39340)
        #expect(found.language == "en")

        let asked = try #require(stub.lastAsked?.url?.absoluteString)
        #expect(asked.contains("/api/resolve"))
        #expect(
            asked.contains("block-39340"),
            "the anchor is part of the address and has to travel"
        )
    }

    @Test("resolving a link describes the wiki behind it the way the directory does")
    func resolvingDescribesTheWiki() async throws {
        let (api, stub) = stubbedAPI()
        stub.answers(
            """
            {"wiki_id":2982,"node_id":4401,"language":"en","wiki_title":"Guide",
             "wiki_url_path":"/smee-again/guide",
             "wiki_icon_url":"https://wikilayer.org/s/icons/2982/abcdefgh.png",
             "wiki_pages_tree":true}
            """
        )
        let link = try #require(URL(string: "https://wikilayer.org/smee-again/guide/4401"))

        let found = try await api.resolve(link)

        #expect(
            found.wikiIconURL?.lastPathComponent == "abcdefgh.png",
            "a wiki followed from a link is stored from this answer alone, so what it leaves out the reader never gets"
        )
        #expect(found.wikiPagesTree)
    }

    @Test("an empty query asks for the directory whole, without an empty filter")
    func directoryWithoutAQuery() async throws {
        let (api, stub) = stubbedAPI()
        stub.answers(#"{"wikis":[],"has_more":false}"#)

        _ = try await api.wikis()

        let asked = try #require(stub.lastAsked?.url?.absoluteString)
        #expect(!asked.contains("q="), "an empty q would ask the server to match nothing")
    }

    @Test("a plus in a search reaches the server as a plus, not as two spaces")
    func plusInASearch() async throws {
        let (api, stub) = stubbedAPI()
        stub.answers(#"{"wikis":[],"has_more":false}"#)

        _ = try await api.wikis(matching: "C++")

        let asked = try #require(stub.lastAsked?.url?.absoluteString)
        #expect(
            asked.contains("q=C%2B%2B"),
            "the server reads a bare + in a query as a space, so «C++» arrives as «C  »: \(asked)"
        )
    }

    @Test("a plus in a cursor survives the trip back to the server")
    func plusInACursor() async throws {
        let (api, stub) = stubbedAPI()
        stub.answers(#"{"nodes":[],"has_more":false}"#)

        _ = try await api.sync(wikiID: 2982, after: "MjAyNi0wOS0xNVQ+Mg")

        let asked = try #require(stub.lastAsked?.url?.absoluteString)
        #expect(
            asked.contains("cursor=MjAyNi0wOS0xNVQ%2BMg"),
            "a cursor whose plus became a space asks the server to start somewhere else: \(asked)"
        )
    }

    @Test("a plus in an address we ask the server to resolve is not turned into a space")
    func plusInAnAddressToResolve() async throws {
        let (api, stub) = stubbedAPI()
        stub.answers(#"{"wiki_id":2982,"node_id":4401,"language":"en"}"#)
        let link = try #require(URL(string: "https://wikilayer.org/smee-again/c++/4401"))

        _ = try await api.resolve(link)

        let asked = try #require(stub.lastAsked?.url?.absoluteString)
        #expect(
            !asked.contains("c++"),
            "the address reached the server with its plus read as a space: \(asked)"
        )
    }

    @Test("the cursor the server handed over goes back to it as it came")
    func cursorRoundTrip() async throws {
        let (api, stub) = stubbedAPI()
        stub.answers(
            """
            {"nodes":[{"id":39340,"path":"2982.39339.39340","kind":"block","title":"Rules",
                       "changed_at":"2026-08-25T10:00:02.25Z"}],
             "has_more":false,"next_cursor":"MTc3ODI1Mzc4NTMzMzkxOTAwMC4zMDA3"}
            """
        )
        let first = try await api.sync(wikiID: 2982, after: nil)
        let cursor = try #require(first.cursor)

        stub.answers(#"{"nodes":[],"has_more":false}"#)
        _ = try await api.sync(wikiID: 2982, after: cursor)

        let asked = try #require(stub.lastAsked?.url)
        let items = try #require(
            URLComponents(url: asked, resolvingAgainstBaseURL: false)?.queryItems
        )
        #expect(items.first { $0.name == "cursor" }?.value == "MTc3ODI1Mzc4NTMzMzkxOTAwMC4zMDA3")
    }

    @Test("an answer that carried nothing leaves the cursor where it was")
    func anEmptyPageMovesNothing() async throws {
        let (api, stub) = stubbedAPI()
        stub.answers(#"{"nodes":[],"has_more":false}"#)

        let batch = try await api.sync(wikiID: 2982, after: "where-it-got-to")

        #expect(batch.cursor == nil, "an empty page named a cursor of its own")
    }

    @Test("a deleted node arrives as an id and a flag, with no fields to speak of")
    func deletion() async throws {
        let (api, stub) = stubbedAPI()
        stub.answers(
            """
            {"nodes":[{"id":4036,"changed_at":"2026-08-25T11:00:00Z","deleted":true}],"has_more":false}
            """
        )

        let batch = try await api.sync(wikiID: 2982, after: nil)
        let gone = try #require(batch.nodes.first)

        #expect(gone.deleted)
        #expect(gone.id == 4036)
        #expect(gone.title.isEmpty)
    }

    @Test("a refusal is reported as a refusal, not as an empty wiki")
    func refusal() async throws {
        let (api, stub) = stubbedAPI()
        stub.answers("not found", status: 404)

        await #expect(throws: WikiAPIError.status(404)) {
            _ = try await api.sync(wikiID: 1, after: nil)
        }
    }
}
