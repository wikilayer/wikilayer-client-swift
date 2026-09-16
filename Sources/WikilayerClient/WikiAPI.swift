import Foundation

public enum WikiAPIError: Error, Sendable, Equatable {
    case status(Int)
    case malformed(String)
    case unreachable(String)
}

public struct WikiAPI: Sendable {
    private let hosts: WikiHostPool
    private let transport: JSONTransport
    private let syncPageSize: Int
    private let directoryPageSize: Int

    public init(
        hosts: WikiHostPool,
        session: URLSession = .shared,
        syncPageSize: Int = 500,
        directoryPageSize: Int = 50
    ) {
        self.hosts = hosts
        transport = JSONTransport(session: session)
        self.syncPageSize = syncPageSize
        self.directoryPageSize = directoryPageSize
    }

    public init(
        baseURL: URL,
        session: URLSession = .shared,
        syncPageSize: Int = 500,
        directoryPageSize: Int = 50
    ) {
        self.init(
            hosts: WikiHostPool(primary: baseURL),
            session: session,
            syncPageSize: syncPageSize,
            directoryPageSize: directoryPageSize
        )
    }

    public func sync(
        wikiID: Int64,
        after cursor: String?,
        limit: Int,
        as credential: Credential? = nil
    ) async throws -> SyncBatch {
        try await onAvailableHost(in: hosts) { host in
            let url = try syncURL(
                at: host,
                wikiID: wikiID,
                after: cursor,
                limit: limit
            )
            return try await fetch(SyncBatch.self, from: signed(url, as: credential))
        }
    }

    public func sync(
        wikiID: Int64,
        after cursor: String?,
        as credential: Credential? = nil
    ) async throws -> SyncBatch {
        try await sync(wikiID: wikiID, after: cursor, limit: syncPageSize, as: credential)
    }

    private func syncURL(at host: URL, wikiID: Int64, after cursor: String?, limit: Int) throws -> URL {
        var items = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor {
            items.append(URLQueryItem(name: "cursor", value: cursor))
        }
        let address = host.appending(path: "api/wikis/\(wikiID)/sync")
        guard let request = AskedQuery.url(address, items) else {
            throw WikiAPIError.malformed("could not build a URL for wiki \(wikiID)")
        }
        return request
    }

    public func wikis(
        matching query: String = "",
        limit: Int,
        offset: Int = 0
    ) async throws -> WikiPage {
        try await onAvailableHost(in: hosts) { host in
            var items = [
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset))
            ]
            if !query.isEmpty {
                items.append(URLQueryItem(name: "q", value: query))
            }
            guard let request = AskedQuery.url(host.appending(path: "api/wikis"), items) else {
                throw WikiAPIError.malformed("could not build a URL for the wiki directory")
            }
            return try await fetch(WikiPage.self, from: request)
        }
    }

    public func wikis(matching query: String = "", offset: Int = 0) async throws -> WikiPage {
        try await wikis(matching: query, limit: directoryPageSize, offset: offset)
    }

    public func myWikis(
        after cursor: String?,
        as credential: Credential,
        limit: Int
    ) async throws -> MyWikiPage {
        try await onAvailableHost(in: hosts) { host in
            var items = [URLQueryItem(name: "limit", value: String(limit))]
            if let cursor {
                items.append(URLQueryItem(name: "cursor", value: cursor))
            }
            guard let address = AskedQuery.url(host.appending(path: "api/me/wikis"), items) else {
                throw WikiAPIError.malformed("could not build a URL for the reader's own wikis")
            }
            return try await fetch(MyWikiPage.self, from: signed(address, as: credential))
        }
    }

    public func myWikis(after cursor: String?, as credential: Credential) async throws -> MyWikiPage {
        try await myWikis(after: cursor, as: credential, limit: syncPageSize)
    }

    public func resolve(_ address: URL, as credential: Credential? = nil) async throws -> ResolvedAddress {
        try await onAvailableHost(in: hosts) { host in
            let items = [URLQueryItem(name: "url", value: address.absoluteString)]
            guard let request = AskedQuery.url(host.appending(path: "api/resolve"), items) else {
                throw WikiAPIError.malformed("could not build a URL to resolve \(address)")
            }
            return try await fetch(ResolvedAddress.self, from: signed(request, as: credential))
        }
    }

    private func signed(_ url: URL, as credential: Credential?) -> URLRequest {
        var request = URLRequest(url: url)
        if let credential {
            request.setValue("Bearer " + credential.token, forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func fetch<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        try await fetch(type, from: URLRequest(url: url))
    }

    private func fetch<T: Decodable>(_ type: T.Type, from request: URLRequest) async throws -> T {
        try await transport.value(type, from: request, decoder: Self.readerOfWireDates)
    }

    static var readerOfWireDates: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            try parseWireDate(decoder.singleValueContainer().decode(String.self))
        }
        return decoder
    }

    static let wireDate = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    static let wireDateOnAWholeSecond = Date.ISO8601FormatStyle(includingFractionalSeconds: false)

    static func wireString(_ date: Date) -> String {
        let micros = Int64((date.timeIntervalSince1970 * 1_000_000).rounded())
        let wholeSeconds = Int64((Double(micros) / 1_000_000).rounded(.down))
        let fractionCutNotRounded = micros - wholeSeconds * 1_000_000
        let head = Date(timeIntervalSince1970: Double(wholeSeconds)).formatted(wireDateOnAWholeSecond)
        return head.dropLast() + String(format: ".%06dZ", fractionCutNotRounded)
    }

    static func parseWireDate(_ text: String) throws -> Date {
        do {
            return try Date(text, strategy: wireDate)
        } catch {
            return try parseWireDateOnAWholeSecond(text)
        }
    }

    private static func parseWireDateOnAWholeSecond(_ text: String) throws -> Date {
        do {
            return try Date(text, strategy: wireDateOnAWholeSecond)
        } catch {
            throw WikiAPIError.malformed("timestamp \(text) is in neither form: \(error.localizedDescription)")
        }
    }
}
