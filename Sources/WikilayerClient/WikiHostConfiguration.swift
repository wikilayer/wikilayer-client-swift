import Foundation

/// The hosts shipped with the client library.
public struct WikiHostConfiguration: Sendable, Equatable {
    public let primary: URL
    public let mirrors: [URL]

    public init(primary: URL, mirrors: [URL] = []) {
        self.primary = primary
        self.mirrors = mirrors
    }

    /// The library-owned `hosts.yaml` configuration.
    public static let bundled: Self = {
        guard let file = Bundle.module.url(forResource: "hosts", withExtension: "yaml") else {
            fatalError("hosts.yaml is not in the WikilayerClient bundle")
        }
        do {
            return try parse(String(contentsOf: file, encoding: .utf8))
        } catch {
            fatalError("hosts.yaml could not be read: \(error)")
        }
    }()

    public func pool(
        preferred: URL? = nil,
        didSelect: (@Sendable (URL) -> Void)? = nil
    ) -> WikiHostPool {
        WikiHostPool(primary: primary, mirrors: mirrors, preferred: preferred, didSelect: didSelect)
    }

    static func parse(_ yaml: String) throws -> Self {
        let meaningful = yaml.split(whereSeparator: \.isNewline).map {
            $0.split(separator: "#", maxSplits: 1).first.map(String.init)?.trimmingCharacters(
                in: .whitespaces
            ) ?? ""
        }.filter { !$0.isEmpty }
        guard let primaryLine = meaningful.first(where: { $0.hasPrefix("primary:") }),
            let primary = URL(string: value(after: ":", in: primaryLine)),
            primary.scheme == "https"
        else {
            throw WikiAPIError.malformed("hosts.yaml has no HTTPS primary host")
        }
        let mirrorStart = meaningful.firstIndex(where: { $0.hasPrefix("mirrors:") })
        let mirrors =
            mirrorStart.map { start in
                meaningful.dropFirst(start + 1).prefix(while: { $0.hasPrefix("-") }).compactMap {
                    URL(string: $0.dropFirst().trimmingCharacters(in: .whitespaces))
                }
            } ?? []
        return Self(primary: primary, mirrors: mirrors)
    }

    private static func value(after separator: Character, in line: String) -> String {
        line.split(separator: separator, maxSplits: 1).last.map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
    }
}
