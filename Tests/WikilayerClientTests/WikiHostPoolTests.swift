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
        let status = host == "censored.example" ? 451 : 200
        guard let url = request.url,
            let response = HTTPURLResponse(
                url: url,
                statusCode: status,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        let body =
            request.url?.path.hasSuffix("/api/auth/apple") == true
            ? #"{"access_token":"ours","expires_in":3600}"#
            : #"{"wikis":[],"has_more":false}"#
        client?.urlProtocol(self, didLoad: Data(body.utf8))
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
        HostProtocol.reset()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [HostProtocol.self]
        let blocked = URL(string: "https://blocked.example") ?? URL.temporaryDirectory
        let api = WikiAPI(baseURL: blocked, session: URLSession(configuration: config))

        do {
            _ = try await api.wikis()
            Issue.record("an unreachable host answered")
        } catch WikiAPIError.unreachable(let failures) {
            #expect(
                failures == [
                    WikiHostFailure(
                        host: blocked,
                        reason: .network(URLError.Code.timedOut.rawValue)
                    )
                ]
            )
        } catch {
            Issue.record("the wrong error came back: \(error)")
        }
    }

    @Test("a one-shot identity token is never retried on a mirror")
    func identityTokenIsNotRetried() async {
        HostProtocol.reset()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [HostProtocol.self]
        let blocked = URL(string: "https://blocked.example") ?? URL.temporaryDirectory
        let mirror = URL(string: "https://mirror.example") ?? URL.temporaryDirectory
        let auth = AuthAPI(
            hosts: WikiHostPool(primary: blocked, mirrors: [mirror]),
            client: OAuthClient(id: "app", redirectURI: "app:/oauth", scope: "app"),
            session: URLSession(configuration: config)
        )

        await #expect(throws: WikiAPIError.self) {
            _ = try await auth.signIn(with: .apple, identityToken: "one-shot")
        }
        #expect(HostProtocol.asked == ["blocked.example"])
    }

    @Test("a safe preflight selects the mirror before a one-shot identity token exists")
    func preflightBeforeIdentityToken() async throws {
        HostProtocol.reset()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [HostProtocol.self]
        let blocked = URL(string: "https://blocked.example") ?? URL.temporaryDirectory
        let mirror = URL(string: "https://mirror.example") ?? URL.temporaryDirectory
        let auth = AuthAPI(
            hosts: WikiHostPool(primary: blocked, mirrors: [mirror]),
            client: OAuthClient(id: "app", redirectURI: "app:/oauth", scope: "app"),
            session: URLSession(configuration: config)
        )

        try await auth.prepareHost()
        _ = try await auth.signIn(with: .apple, identityToken: "one-shot")

        #expect(HostProtocol.asked == ["blocked.example", "mirror.example", "mirror.example"])
    }

    @Test("an HTTP 451 advances to the mirror")
    func censoredHostFailsOver() async throws {
        HostProtocol.reset()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [HostProtocol.self]
        let censored = URL(string: "https://censored.example") ?? URL.temporaryDirectory
        let mirror = URL(string: "https://mirror.example") ?? URL.temporaryDirectory
        let api = WikiAPI(
            hosts: WikiHostPool(primary: censored, mirrors: [mirror]),
            session: URLSession(configuration: config)
        )

        _ = try await api.wikis()

        #expect(HostProtocol.asked == ["censored.example", "mirror.example"])
    }

    @Test("an authorization code stays bound to its host and is never retried")
    func authorizationCodeIsNotRetried() async {
        HostProtocol.reset()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [HostProtocol.self]
        let blocked = URL(string: "https://blocked.example") ?? URL.temporaryDirectory
        let mirror = URL(string: "https://mirror.example") ?? URL.temporaryDirectory
        let auth = AuthAPI(
            hosts: WikiHostPool(primary: blocked, mirrors: [mirror]),
            client: OAuthClient(id: "app", redirectURI: "app:/oauth", scope: "app"),
            session: URLSession(configuration: config)
        )
        let request = AuthorizationRequest(
            url: blocked.appending(path: "oauth/authorize"),
            host: blocked
        )

        await #expect(throws: WikiAPIError.self) {
            _ = try await auth.exchange(code: "one-shot", verifier: "secret", for: request)
        }
        #expect(HostProtocol.asked == ["blocked.example"])
    }

    @Test("signing out is never repeated on a mirror")
    func signOutIsNotRetried() async {
        HostProtocol.reset()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [HostProtocol.self]
        let blocked = URL(string: "https://blocked.example") ?? URL.temporaryDirectory
        let mirror = URL(string: "https://mirror.example") ?? URL.temporaryDirectory
        let auth = AuthAPI(
            hosts: WikiHostPool(primary: blocked, mirrors: [mirror]),
            client: OAuthClient(id: "app", redirectURI: "app:/oauth", scope: "app"),
            session: URLSession(configuration: config)
        )

        await #expect(throws: WikiAPIError.self) {
            try await auth.signOut(Credential(token: "ours"))
        }
        #expect(HostProtocol.asked == ["blocked.example"])
    }
}
