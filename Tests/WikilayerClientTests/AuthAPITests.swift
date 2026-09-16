import CryptoKit
import Foundation
import Testing

@testable import WikilayerClient

private func stubbedAuth() -> (AuthAPI, StubbedSession) {
    let stub = StubServer.open()
    let api = AuthAPI(
        hosts: WikiHostPool(primary: URL(string: "https://wikilayer.org") ?? URL.temporaryDirectory),
        client: OAuthClient(
            id: "wikilayer-app",
            redirectURI: "org.wikilayer:/oauth/callback",
            scope: "app"
        ),
        session: stub.session
    )
    return (api, stub)
}

@Suite("Signing in")
struct AuthAPITests {
    @Test("the identity token the phone produced is traded for one of ours")
    func nativeSignIn() async throws {
        let (api, stub) = stubbedAuth()
        stub.answers("""
        {"access_token":"ours","token_type":"Bearer","expires_in":7776000,"scope":"app"}
        """)

        let credential = try await api.signIn(
            with: .apple,
            identityToken: "apple-said-so",
            nameOfferedOnce: "Ada Lovelace"
        )

        #expect(credential.token == "ours")

        let asked = try #require(stub.lastAsked)
        #expect(asked.url?.absoluteString.hasSuffix("/api/auth/apple") == true)
        let sent = try #require(asked.body)
        #expect(sent.contains("apple-said-so"))
        #expect(sent.contains("Ada Lovelace"), "Apple hands the name over once, and never again")
    }

    @Test("a refused identity token is refused here too, with the status it was refused by")
    func refusedSignIn() async throws {
        let (api, stub) = stubbedAuth()
        stub.answers(#"{"error":"that identity token was not accepted"}"#, status: 401)

        await #expect(throws: WikiAPIError.status(401)) {
            try await api.signIn(with: .google, identityToken: "stale")
        }
    }

    @Test("the browser is sent to our own client, with the challenge and the provider named")
    func authorizationURL() async throws {
        let secret = PKCE()
        let (api, _) = stubbedAuth()

        let request = try #require(await api.authorizationRequest(
            provider: "github",
            state: secret.state,
            challenge: secret.challenge
        ))
        let start = request.url

        let asked = try #require(URLComponents(url: start, resolvingAgainstBaseURL: false)?.queryItems)
        func value(_ name: String) -> String? { asked.first { $0.name == name }?.value }
        #expect(start.path == "/oauth/authorize")
        #expect(value("client_id") == api.client.id)
        #expect(value("redirect_uri") == api.client.redirectURI)
        #expect(value("response_type") == "code")
        #expect(
            value("scope") == api.client.scope,
            "the app asks for what it is for, and the server allows no more"
        )
        #expect(value("provider") == "github")
        #expect(value("state") == secret.state)
        #expect(value("code_challenge") == secret.challenge)
        #expect(value("code_challenge_method") == "S256")
    }

    @Test("the code is exchanged with the verifier, in a form body where a plus is not a space")
    func exchange() async throws {
        let (api, stub) = stubbedAuth()
        stub.answers(#"{"access_token":"ours","expires_in":3600}"#)

        let request = try #require(await api.authorizationRequest(
            provider: "github",
            state: "state",
            challenge: "challenge"
        ))
        _ = try await api.exchange(code: "code+with/reserved=", verifier: "verifier", for: request)

        let asked = try #require(stub.lastAsked)
        #expect(asked.url?.absoluteString.hasSuffix("/oauth/token") == true)
        #expect(asked.headers["Content-Type"] == "application/x-www-form-urlencoded")

        let sent = try #require(asked.body)
        let fields = sent.split(separator: "&").reduce(into: [String: String]()) { fields, pair in
            let halves = pair.split(separator: "=", maxSplits: 1)
            guard halves.count == 2 else { return }
            fields[String(halves[0])] = String(halves[1]).removingPercentEncoding
        }
        #expect(fields["grant_type"] == "authorization_code")
        #expect(fields["code_verifier"] == "verifier")
        #expect(fields["client_id"] == api.client.id)
        #expect(fields["code"] == "code+with/reserved=")
    }

    @Test("who is signed in is asked for with the credential, and nothing else")
    func account() async throws {
        let (api, stub) = stubbedAuth()
        stub.answers("""
        {"id":7,"display_name":"Ada Lovelace","email":"ada@example.org"}
        """)
        let credential = Credential(token: "ours")

        let who = try await api.account(as: credential)

        #expect(who.id == 7)
        #expect(who.displayName == "Ada Lovelace")
        #expect(who.email == "ada@example.org")
        #expect(who.avatarURL == nil)
        #expect(stub.lastAsked?.headers["Authorization"] == "Bearer ours")
    }

    @Test("a new name is sent under the credential, and the account comes back wearing it")
    func rename() async throws {
        let (api, stub) = stubbedAuth()
        stub.answers("""
        {"id":7,"display_name":"Ada, Countess of Lovelace","email":"ada@example.org"}
        """)

        let renamed = try await api.rename(to: "Ada, Countess of Lovelace", as: Credential(token: "ours"))

        #expect(renamed.displayName == "Ada, Countess of Lovelace")
        let asked = try #require(stub.lastAsked)
        #expect(asked.url?.absoluteString.hasSuffix("/api/me") == true)
        #expect(asked.method == "PATCH", "an account replaced instead of patched loses everything not sent")
        #expect(asked.headers["Authorization"] == "Bearer ours")
        let sent = try #require(asked.body)
        #expect(sent.contains("Ada, Countess of Lovelace"))
    }

    @Test("signing out is a call, not just forgetting: a copy off the device must stop working")
    func signOut() async throws {
        let (api, stub) = stubbedAuth()
        stub.answers("", status: 204)

        try await api.signOut(Credential(token: "ours"))

        let asked = try #require(stub.lastAsked)
        #expect(asked.url?.absoluteString.hasSuffix("/api/auth/signout") == true)
        #expect(asked.headers["Authorization"] == "Bearer ours")
    }
}

@Suite("The secret an app keeps for one sign-in")
struct PKCETests {
    @Test("the challenge is what the server recomputes from the verifier")
    func challenge() throws {
        let secret = PKCE()

        let digest = SHA256.hash(data: Data(secret.verifier.utf8))
        let expected = Data(digest).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        #expect(secret.challenge == expected)
        #expect(!secret.challenge.contains("="), "padding is not part of the base64url the server compares")
    }

    @Test("no two sign-ins share a secret")
    func distinct() {
        let one = PKCE()
        let two = PKCE()

        #expect(one.verifier != two.verifier)
        #expect(one.state != two.state)
        #expect(one.verifier.count >= 43, "a verifier shorter than this is guessable")
    }
}
