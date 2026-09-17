import Foundation

public struct WikiHostFailure: Error, Sendable, Equatable {
    public enum Reason: Sendable, Equatable {
        case network(Int)
        case http(Int)
        case browser(String)
    }

    public let host: URL
    public let reason: Reason

    public init(host: URL, reason: Reason) {
        self.host = host
        self.reason = reason
    }

    var said: String {
        switch reason {
        case let .network(code):
            "\(host.absoluteString) is out of reach (URLError \(code))"
        case let .http(status):
            "\(host.absoluteString) answered \(status)"
        case let .browser(what):
            "\(host.absoluteString) sent the reader back with \(what)"
        }
    }
}

public actor WikiHostPool {
    private let hosts: [URL]
    private let failoverHTTPStatuses: Set<Int>
    private let didSelect: (@Sendable (URL) -> Void)?
    private var selected: URL

    public init(
        primary: URL,
        mirrors: [URL] = [],
        preferred: URL? = nil,
        failoverHTTPStatuses: Set<Int> = [451],
        didSelect: (@Sendable (URL) -> Void)? = nil
    ) {
        var distinct = [primary]
        for mirror in mirrors where !distinct.contains(mirror) {
            distinct.append(mirror)
        }
        hosts = distinct
        self.failoverHTTPStatuses = failoverHTTPStatuses
        self.didSelect = didSelect
        selected = preferred.flatMap { distinct.contains($0) ? $0 : nil } ?? primary
    }

    func candidates() -> [URL] {
        [selected] + hosts.filter { $0 != selected }
    }

    func select(_ host: URL) {
        guard selected != host else { return }
        selected = host
        didSelect?(host)
    }

    func shouldFailover(afterHTTPStatus status: Int) -> Bool {
        failoverHTTPStatuses.contains(status)
    }
}

func onAvailableHost<T: Sendable>(
    in pool: WikiHostPool,
    operation: @Sendable (URL) async throws -> T
) async throws -> T {
    var failures: [WikiHostFailure] = []
    for host in await pool.candidates() {
        do {
            let result = try await operation(host)
            await pool.select(host)
            return result
        } catch let error as URLError where error.code == .cancelled {
            throw error
        } catch let error as URLError {
            failures.append(WikiHostFailure(host: host, reason: .network(error.code.rawValue)))
        } catch WikiAPIError.status(let status) {
            guard await pool.shouldFailover(afterHTTPStatus: status) else {
                throw WikiAPIError.status(status)
            }
            failures.append(WikiHostFailure(host: host, reason: .http(status)))
        }
    }
    throw WikiAPIError.unreachable(failures)
}

func onSelectedHost<T: Sendable>(
    in pool: WikiHostPool,
    operation: @Sendable (URL) async throws -> T
) async throws -> T {
    guard let host = await pool.candidates().first else {
        throw WikiAPIError.unreachable([])
    }
    do {
        return try await operation(host)
    } catch let error as URLError where error.code == .cancelled {
        throw error
    } catch let error as URLError {
        throw WikiAPIError.unreachable([
            WikiHostFailure(host: host, reason: .network(error.code.rawValue))
        ])
    }
}
