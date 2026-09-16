import Foundation

public actor WikiHostPool {
    private let hosts: [URL]
    private let didSelect: (@Sendable (URL) -> Void)?
    private var selected: URL

    public init(
        primary: URL,
        mirrors: [URL] = [],
        preferred: URL? = nil,
        didSelect: (@Sendable (URL) -> Void)? = nil
    ) {
        var distinct = [primary]
        for mirror in mirrors where !distinct.contains(mirror) {
            distinct.append(mirror)
        }
        hosts = distinct
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
}

func onAvailableHost<T: Sendable>(
    in pool: WikiHostPool,
    operation: @Sendable (URL) async throws -> T
) async throws -> T {
    var lastNetworkError: (any Error)?
    for host in await pool.candidates() {
        do {
            let result = try await operation(host)
            await pool.select(host)
            return result
        } catch let error as URLError {
            lastNetworkError = error
        }
    }
    throw WikiAPIError.unreachable(String(describing: lastNetworkError ?? URLError(.unknown)))
}
