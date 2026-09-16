import Foundation

public protocol WikiListening: Sendable {
    func changes(
        inWiki wikiID: Int64,
        as credential: @escaping @Sendable () async -> Credential?
    ) -> AsyncStream<Void>
}

public struct WikiChannel: WikiListening, Sendable {
    private static let silenceIsNotAFailedRequest = TimeInterval.greatestFiniteMagnitude

    private let hosts: WikiHostPool
    private let session: URLSession
    private let onFailure: @Sendable (Int64, any Error) -> Void

    private let firstRetry: Duration
    private let longestRetry: Duration

    public init(
        hosts: WikiHostPool,
        session: URLSession = .shared,
        firstRetry: Duration = .seconds(2),
        longestRetry: Duration = .seconds(60),
        onFailure: @escaping @Sendable (Int64, any Error) -> Void = { _, _ in }
    ) {
        self.hosts = hosts
        self.session = session
        self.firstRetry = firstRetry
        self.longestRetry = longestRetry
        self.onFailure = onFailure
    }

    public init(
        baseURL: URL,
        session: URLSession = .shared,
        firstRetry: Duration = .seconds(2),
        longestRetry: Duration = .seconds(60),
        onFailure: @escaping @Sendable (Int64, any Error) -> Void = { _, _ in }
    ) {
        self.init(
            hosts: WikiHostPool(primary: baseURL),
            session: session,
            firstRetry: firstRetry,
            longestRetry: longestRetry,
            onFailure: onFailure
        )
    }

    public func changes(
        inWiki wikiID: Int64,
        as credential: @escaping @Sendable () async -> Credential? = { nil }
    ) -> AsyncStream<Void> {
        AsyncStream { continuation in
            let listening = Task {
                var retry = firstRetry
                while !Task.isCancelled {
                    do {
                        try await onAvailableHost(in: hosts) { host in
                            try await listen(
                                at: host,
                                wikiID: wikiID,
                                as: await credential(),
                                continuation: continuation
                            )
                        }
                        retry = firstRetry
                    } catch is CancellationError {
                        break
                    } catch {
                        onFailure(wikiID, error)
                    }
                    guard await waited(retry) else { break }
                    retry = min(retry * 2, longestRetry)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in listening.cancel() }
        }
    }

    private func waited(_ interval: Duration) async -> Bool {
        do {
            try await Task.sleep(for: interval)
            return true
        } catch {
            return false
        }
    }

    private func listen(
        at host: URL,
        wikiID: Int64,
        as credential: Credential?,
        continuation: AsyncStream<Void>.Continuation
    ) async throws {
        var request = URLRequest(url: host.appending(path: "api/wikis/\(wikiID)/events"))
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if let credential {
            request.setValue("Bearer " + credential.token, forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = Self.silenceIsNotAFailedRequest

        let (bytes, response) = try await session.bytes(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw WikiAPIError.status(http.statusCode)
        }
        for try await line in bytes.lines where line == "event: changed" {
            continuation.yield()
        }
    }
}
