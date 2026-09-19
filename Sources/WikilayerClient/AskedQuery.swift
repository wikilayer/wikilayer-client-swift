import Foundation

// URLComponents preserves `+`, while Go form decoding reads it as a space.
enum AskedQuery {
    static func url(_ address: URL, _ items: [URLQueryItem]) -> URL? {
        guard var asked = URLComponents(url: address, resolvingAgainstBaseURL: false) else {
            return nil
        }
        asked.queryItems = items
        let written = asked.percentEncodedQuery
        asked.percentEncodedQuery = encoded(written)
        return asked.url
    }

    static func form(_ fields: [String: String]) -> String {
        var body = URLComponents()
        body.queryItems = fields.map { URLQueryItem(name: $0.key, value: $0.value) }
        return encoded(body.percentEncodedQuery) ?? ""
    }

    private static func encoded(_ query: String?) -> String? {
        query?.replacingOccurrences(of: "+", with: "%2B")
    }
}
