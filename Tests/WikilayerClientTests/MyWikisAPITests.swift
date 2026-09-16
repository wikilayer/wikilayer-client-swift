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

private let credential = Credential(token: "tok-en")

@Suite("Reading the set of wikis a reader has")
struct MyWikisAPITests {
    @Test("a first ask carries the credential and no cursor, and reads the rows out of the answer")
    func firstAsk() async throws {
        let (api, stub) = stubbedAPI()
        stub.answers("""
        {"wikis":[
          {"id":2982,"title":"Guide","url_path":"https://wikilayer.org/smee/guide",
           "updated_at":"2026-08-25T10:00:00.5Z","visibility":"public","mine":true,
           "changed_at":"2026-08-25T10:00:00.5Z","removed":false},
          {"id":1025,"title":"Codestyle","url_path":"https://wikilayer.org/smee/codestyle",
           "updated_at":"2026-08-25T11:00:00Z","visibility":"private","mine":false,
           "changed_at":"2026-08-25T11:00:00Z","removed":false}
        ],"has_more":false}
        """)

        let page = try await api.myWikis(after: nil, as: credential)

        #expect(page.wikis.count == 2)
        #expect(!page.hasMore)
        #expect(page.wikis[0].visibility == .public)
        #expect(page.wikis[0].mine)
        #expect(page.wikis[1].visibility == .private)
        #expect(!page.wikis[1].mine)
        #expect(!page.wikis[0].removed)

        let asked = try #require(stub.lastAsked)
        #expect(asked.url?.path == "/api/me/wikis")
        #expect(asked.url?.query?.contains("since=") != true, "a first ask must not carry a cursor")
        #expect(asked.headers["Authorization"] == "Bearer tok-en")
    }

    @Test("a wiki that is no longer the reader's arrives with its id and nothing else")
    func removedRow() async throws {
        let (api, stub) = stubbedAPI()
        stub.answers("""
        {"wikis":[{"id":1025,"changed_at":"2026-08-25T11:00:00Z","removed":true}],"has_more":false}
        """)

        let page = try await api.myWikis(after: nil, as: credential)

        let row = try #require(page.wikis.first)
        #expect(row.removed)
        #expect(row.id == 1025)
        #expect(row.title.isEmpty)
        #expect(row.visibility == nil, "a wiki that left says nothing about what it was")
    }

    @Test("the cursor the server handed over goes back to it as it came")
    func cursorRoundTrip() async throws {
        let (api, stub) = stubbedAPI()
        stub.answers("""
        {"wikis":[{"id":1025,"title":"Codestyle","url_path":"/x","updated_at":"2026-08-25T11:00:00.257843Z",
          "visibility":"private","mine":true,"removed":false}],
         "has_more":true,"next_cursor":"where-the-set-got-to"}
        """)

        let page = try await api.myWikis(after: nil, as: credential)
        _ = try await api.myWikis(after: page.cursor, as: credential)

        let asked = try #require(stub.lastAsked?.url?.query)
        #expect(asked.contains("cursor=where-the-set-got-to"), "the cursor came back as: \(asked)")
    }

    @Test("a refusal is the server's answer about the credential, not something to hide")
    func refusal() async throws {
        let (api, stub) = stubbedAPI()
        stub.answers(#"{"error":"not signed in"}"#, status: 401)

        await #expect(throws: WikiAPIError.status(401)) {
            _ = try await api.myWikis(after: nil, as: credential)
        }
    }
}
