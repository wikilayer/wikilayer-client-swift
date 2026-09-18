import CryptoKit
import Foundation

/// A verifier, challenge and state for one OAuth authorization flow.
public struct PKCE: Sendable {
    public let verifier: String
    public let state: String

    public init() {
        verifier = Self.randomText()
        state = Self.randomText()
    }

    public var challenge: String {
        Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    private static func randomText() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            fatalError("the system has no randomness for a sign-in")
        }
        return base64URL(Data(bytes))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
