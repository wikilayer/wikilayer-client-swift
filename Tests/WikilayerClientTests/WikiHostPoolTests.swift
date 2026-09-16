import Foundation
import Testing

@testable import WikilayerClient

private final class HostProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var askedHosts: [String] = []

    static func reset() {
        lock.withLock { askedHosts = [] }
    }

    static var asked: [String] {
        lock.withLock { askedHosts }
    }

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let host = request.url?.host ?? ""
        Self.lock.withLock { Self.askedHosts.append(host) }
        if host == "blocked.example" {
            client?.urlProtocol(self, didFailWithError: URLError(.timedOut))
            return
        }
        guard let url = request.url,
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: 200,
                  httpVersion: nil,
                  headerFields: ["Content-Type": "application/json"]
              )
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"wikis":[],"has_more":false}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite("Choosing a reachable Wikilayer host", .serialized)
struct WikiHostPoolTests {
    private func api() -> WikiAPI {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [HostProtocol.self]
        let primary = URL(string: "https://blocked.example") ?? URL.temporaryDirectory
        let mirror = URL(string: "https://mirror.example") ?? URL.temporaryDirectory
        return WikiAPI(
            hosts: WikiHostPool(primary: primary, mirrors: [mirror]),
            session: URLSession(configuration: config)
        )
    }

    @Test("a network failure advances to the mirror and remembers it")
    func failover() async throws {
        HostProtocol.reset()
        let api = api()

        _ = try await api.wikis()
        _ = try await api.wikis()

        #expect(HostProtocol.asked == ["blocked.example", "mirror.example", "mirror.example"])
    }

    @Test("when every host is unreachable the caller can offer a VPN")
    func allBlocked() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [HostProtocol.self]
        let blocked = URL(string: "https://blocked.example") ?? URL.temporaryDirectory
        let api = WikiAPI(baseURL: blocked, session: URLSession(configuration: config))

        await #expect(throws: WikiAPIError.self) {
            _ = try await api.wikis()
        }
    }
}
