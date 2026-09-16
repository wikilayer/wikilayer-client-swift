import Foundation

public enum NativeProvider: String, Sendable, CaseIterable {
    case apple
    case google
}

public struct OAuthClient: Sendable, Equatable {
    public let id: String
    public let redirectURI: String
    public let scope: String

    public init(id: String, redirectURI: String, scope: String) {
        self.id = id
        self.redirectURI = redirectURI
        self.scope = scope
    }
}

public struct AuthAPI: Sendable {
    private let hosts: WikiHostPool
    private let transport: JSONTransport
    public let client: OAuthClient

    public init(hosts: WikiHostPool, client: OAuthClient, session: URLSession = .shared) {
        self.hosts = hosts
        self.client = client
        self.transport = JSONTransport(session: session)
    }

    public func signIn(
        with provider: NativeProvider,
        identityToken: String,
        nameOfferedOnce: String = ""
    ) async throws -> Credential {
        try await onAvailableHost(in: hosts) { host in
            var request = URLRequest(url: host.appending(path: "api/auth/\(provider.rawValue)"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode([
                "id_token": identityToken,
                "name": nameOfferedOnce
            ])
            return try await transport.value(TokenGrant.self, from: request).credential()
        }
    }

    public func authorizationURL(provider: String, state: String, challenge: String) async -> URL? {
        guard let host = await hosts.candidates().first else { return nil }
        return AskedQuery.url(host.appending(path: "oauth/authorize"), [
            URLQueryItem(name: "client_id", value: client.id),
            URLQueryItem(name: "redirect_uri", value: client.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: client.scope),
            URLQueryItem(name: "provider", value: provider),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ])
    }

    public func exchange(code: String, verifier: String) async throws -> Credential {
        try await onAvailableHost(in: hosts) { host in
            var request = URLRequest(url: host.appending(path: "oauth/token"))
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = Data(form([
                "grant_type": "authorization_code",
                "code": code,
                "code_verifier": verifier,
                "client_id": client.id,
                "redirect_uri": client.redirectURI
            ]).utf8)
            return try await transport.value(TokenGrant.self, from: request).credential()
        }
    }

    public func account(as credential: Credential) async throws -> Account {
        try await onAvailableHost(in: hosts) { host in
            try await transport.value(
                Account.self,
                from: signed(host: host, path: "api/me", method: "GET", by: credential)
            )
        }
    }

    public func rename(to name: String, as credential: Credential) async throws -> Account {
        try await onAvailableHost(in: hosts) { host in
            var request = signed(host: host, path: "api/me", method: "PATCH", by: credential)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(["display_name": name])
            return try await transport.value(Account.self, from: request)
        }
    }

    public func signOut(_ credential: Credential) async throws {
        _ = try await onAvailableHost(in: hosts) { host in
            try await transport.data(
                from: signed(host: host, path: "api/auth/signout", method: "POST", by: credential)
            )
        }
    }

    private func signed(host: URL, path: String, method: String, by credential: Credential) -> URLRequest {
        var request = URLRequest(url: host.appending(path: path))
        request.httpMethod = method
        request.setValue("Bearer " + credential.token, forHTTPHeaderField: "Authorization")
        return request
    }

    private func form(_ fields: [String: String]) -> String {
        AskedQuery.form(fields)
    }
}
