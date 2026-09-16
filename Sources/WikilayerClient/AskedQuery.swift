import Foundation

// URLComponents leaves a bare `+` in a query value, and a server that reads the query the way a
// form is read takes it for a space: Go's `url.ParseQuery`, which our API runs on, turns `C++`
// into `C  `. Encoding it here is the only place that has to know.
enum AskedQuery {
    static func url(_ address: URL, _ items: [URLQueryItem]) -> URL? {
        guard var asked = URLComponents(url: address, resolvingAgainstBaseURL: false) else { return nil }
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
