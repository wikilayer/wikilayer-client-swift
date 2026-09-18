import Foundation

/// A dot-separated ancestry path returned with a synchronized node.
public struct NodePath: Equatable, Sendable {
    public static let none = Int64(0)

    public let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var labels: [Substring] {
        text.split(separator: ".")
    }

    public var wiki: Int64 {
        id(at: 0)
    }

    public var page: Int64 {
        id(at: 1)
    }

    public var parent: Int64 {
        id(at: labels.count - 2)
    }

    public var depth: Int {
        max(labels.count - 1, 0)
    }

    /// Returns whether the path has the given node among its ancestors.
    public func descends(from ancestor: Int64) -> Bool {
        labels.dropLast().contains("\(ancestor)")
    }

    /// Returns whether this path is the other path or one of its descendants.
    public func sitsInside(_ other: NodePath) -> Bool {
        text == other.text || text.hasPrefix("\(other.text).")
    }

    private func id(at position: Int) -> Int64 {
        let labels = self.labels
        guard position >= 0, position < labels.count else { return Self.none }
        return Int64(labels[position]) ?? Self.none
    }
}
