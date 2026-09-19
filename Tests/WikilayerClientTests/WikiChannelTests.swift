import Foundation
import Testing

@testable import WikilayerClient

final class EventStreamProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var chunks: [String] = []
    nonisolated(unsafe) static var status = 200

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
            let response = HTTPURLResponse(
                url: url,
                statusCode: Self.status,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/event-stream"]
            )
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        for chunk in Self.chunks {
            client?.urlProtocol(self, didLoad: Data(chunk.utf8))
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite("The wiki's live channel", .serialized)
struct WikiChannelTests {
    private func channel() -> WikiChannel {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [EventStreamProtocol.self]
        return WikiChannel(
            baseURL: URL(string: "https://wikilayer.org") ?? URL.temporaryDirectory,
            session: URLSession(configuration: config),
            firstRetry: .milliseconds(10),
            longestRetry: .milliseconds(20)
        )
    }

    @Test("each announced change arrives once")
    func changesArrive() async {
        EventStreamProtocol.status = 200
        EventStreamProtocol.chunks = [
            ":ok\n\n",
            "event: ping\ndata: {}\n\n",
            "event: changed\ndata: {\"wiki_id\":1}\n\n",
            "event: changed\ndata: {\"wiki_id\":1}\n\n"
        ]

        var seen = 0
        for await _ in channel().changes(inWiki: 1) {
            seen += 1
            if seen == 2 { break }
        }
        #expect(seen == 2)
    }

    @Test("a heartbeat on a quiet wiki is not a change")
    func heartbeatsAreNotChanges() async throws {
        EventStreamProtocol.status = 200
        EventStreamProtocol.chunks = [":ok\n\n", "event: ping\ndata: {}\n\n"]

        let listening = Task { () -> Bool in
            for await _ in channel().changes(inWiki: 1) { return true }
            return false
        }
        try await Task.sleep(for: .milliseconds(200))
        listening.cancel()
        #expect(await listening.value == false)
    }

    @Test("a connection that fails is dialled again rather than ending the stream")
    func aDroppedConnectionIsRetried() async throws {
        EventStreamProtocol.status = 503
        EventStreamProtocol.chunks = []

        let listening = Task { () -> Bool in
            for await _ in channel().changes(inWiki: 1) { return true }
            return false
        }
        try await Task.sleep(for: .milliseconds(100))
        EventStreamProtocol.status = 200
        EventStreamProtocol.chunks = [":ok\n\n", "event: changed\ndata: {\"wiki_id\":1}\n\n"]
        #expect(await listening.value == true)
    }
}
