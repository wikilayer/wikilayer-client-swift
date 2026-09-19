import Foundation

/// A provider that issues a native identity token.
public enum NativeProvider: String, Sendable, CaseIterable {
    case apple
    case google
}

/// The public parameters that identify an OAuth client.
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

/// A browser authorization URL bound to the host that issued it.
public struct AuthorizationRequest: Sendable, Equatable {
    public let url: URL
    let host: URL
}

public enum AccountDeletionError: Error, Equatable, Sendable {
    case liveWikis
}

/// Authentication and account operations for a shared host pool.
public struct AuthAPI: Sendable {
    private let hosts: WikiHostPool
    private let transport: JSONTransport
    public let client: OAuthClient

    public init(hosts: WikiHostPool, client: OAuthClient, session: URLSession = .shared) {
        self.hosts = hosts
        self.client = client
        self.transport = JSONTransport(session: session)
    }

    /// Exchanges a native provider token once on the selected host.
    public func signIn(
        with provider: NativeProvider,
        identityToken: String,
        nameOfferedOnce: String = ""
    ) async throws -> Credential {
        try await onSelectedHost(in: hosts) { host in
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

    /// Selects a reachable host before the caller obtains a one-use provider token.
    public func prepareHost() async throws {
        _ = try await onAvailableHost(in: hosts) { host in
            var request = URLRequest(url: host.appending(path: "api/wikis"))
            request.httpMethod = "GET"
            return try await transport.data(from: request)
        }
    }

    /// Creates a browser authorization request on the selected host.
    public func authorizationRequest(
        provider: String,
        state: String,
        challenge: String
    ) async -> AuthorizationRequest? {
        await hosts.candidates().first.flatMap { host in
            authorizationURL(
                at: host,
                provider: provider,
                state: state,
                challenge: challenge
            ).map { AuthorizationRequest(url: $0, host: host) }
        }
    }

    private func authorizationURL(
        at host: URL,
        provider: String,
        state: String,
        challenge: String
    ) -> URL? {
        AskedQuery.url(
            host.appending(path: "oauth/authorize"),
            [
                URLQueryItem(name: "client_id", value: client.id),
                URLQueryItem(name: "redirect_uri", value: client.redirectURI),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "scope", value: client.scope),
                URLQueryItem(name: "provider", value: provider),
                URLQueryItem(name: "state", value: state),
                URLQueryItem(name: "code_challenge", value: challenge),
                URLQueryItem(name: "code_challenge_method", value: "S256")
            ]
        )
    }

    /// Exchanges an OAuth code on the host that issued the authorization request.
    public func exchange(
        code: String,
        verifier: String,
        for authorization: AuthorizationRequest
    ) async throws -> Credential {
        let host = authorization.host
        do {
            var request = URLRequest(url: host.appending(path: "oauth/token"))
            request.httpMethod = "POST"
            request.setValue(
                "application/x-www-form-urlencoded",
                forHTTPHeaderField: "Content-Type"
            )
            request.httpBody = Data(
                form([
                    "grant_type": "authorization_code",
                    "code": code,
                    "code_verifier": verifier,
                    "client_id": client.id,
                    "redirect_uri": client.redirectURI
                ]).utf8
            )
            return try await transport.value(TokenGrant.self, from: request).credential()
        } catch let error as URLError {
            throw WikiAPIError.unreachable([
                WikiHostFailure(host: host, reason: .network(error.code.rawValue))
            ])
        }
    }

    /// Returns the account represented by a credential.
    public func account(as credential: Credential) async throws -> Account {
        try await onAvailableHost(in: hosts) { host in
            try await transport.value(
                Account.self,
                from: signed(host: host, path: "api/me", method: "GET", by: credential)
            )
        }
    }

    /// Changes the account display name and returns the updated account.
    public func rename(to name: String, as credential: Credential) async throws -> Account {
        try await onAvailableHost(in: hosts) { host in
            var request = signed(host: host, path: "api/me", method: "PATCH", by: credential)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(["display_name": name])
            return try await transport.value(Account.self, from: request)
        }
    }

    /// Permanently closes the account represented by a credential.
    public func deleteAccount(reason: String, as credential: Credential) async throws {
        do {
            _ = try await onSelectedHost(in: hosts) { host in
                var request = signed(host: host, path: "api/me", method: "DELETE", by: credential)
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONEncoder().encode(["reason": reason])
                return try await transport.data(from: request)
            }
        } catch WikiAPIError.status(409) {
            throw AccountDeletionError.liveWikis
        }
    }

    /// Revokes a credential on its selected host.
    public func signOut(_ credential: Credential) async throws {
        _ = try await onSelectedHost(in: hosts) { host in
            try await transport.data(
                from: signed(host: host, path: "api/auth/signout", method: "POST", by: credential)
            )
        }
    }

    private func signed(
        host: URL,
        path: String,
        method: String,
        by credential: Credential
    ) -> URLRequest {
        var request = URLRequest(url: host.appending(path: path))
        request.httpMethod = method
        request.setValue("Bearer " + credential.token, forHTTPHeaderField: "Authorization")
        return request
    }

    private func form(_ fields: [String: String]) -> String {
        AskedQuery.form(fields)
    }
}
