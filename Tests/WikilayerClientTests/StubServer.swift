import Foundation

final class StubServer: URLProtocol, @unchecked Sendable {
    private static let slotHeader = "X-Stub-Slot"

    private struct Slot {
        var status = 200
        var body = Data()
        var asked: [Ask] = []
    }

    struct Ask {
        let url: URL?
        let method: String?
        let headers: [String: String]
        let body: String?
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var slots: [String: Slot] = [:]

    static func open() -> StubbedSession {
        let name = UUID().uuidString
        lock.withLock { slots[name] = Slot() }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubServer.self]
        config.httpAdditionalHeaders = [slotHeader: name]
        return StubbedSession(name: name, session: URLSession(configuration: config))
    }

    static func answer(in name: String, status: Int, body: Data) {
        lock.withLock {
            slots[name]?.status = status
            slots[name]?.body = body
        }
    }

    static func asked(in name: String) -> [Ask] {
        lock.withLock { slots[name]?.asked ?? [] }
    }

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let headers = request.allHTTPHeaderFields ?? [:]
        let name = headers[Self.slotHeader] ?? ""
        let slot = Self.lock.withLock { () -> Slot? in
            Self.slots[name]?.asked.append(
                Ask(
                    url: request.url,
                    method: request.httpMethod,
                    headers: headers,
                    body: Self.sent(in: request)
                )
            )
            return Self.slots[name]
        }
        guard let slot, let url = request.url,
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: slot.status,
                  httpVersion: nil,
                  headerFields: ["Content-Type": "application/json"]
              )
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: slot.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func sent(in request: URLRequest) -> String? {
        if let body = request.httpBody {
            return String(data: body, encoding: .utf8)
        }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }

        var sent = Data()
        var chunk = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&chunk, maxLength: chunk.count)
            if read <= 0 { break }
            sent.append(chunk, count: read)
        }
        return String(data: sent, encoding: .utf8)
    }
}

struct StubbedSession {
    let name: String
    let session: URLSession

    func answers(_ body: String, status: Int = 200) {
        StubServer.answer(in: name, status: status, body: Data(body.utf8))
    }

    func answers(bytes: Data, status: Int = 200) {
        StubServer.answer(in: name, status: status, body: bytes)
    }

    var asked: [StubServer.Ask] {
        StubServer.asked(in: name)
    }

    var lastAsked: StubServer.Ask? {
        asked.last
    }
}
