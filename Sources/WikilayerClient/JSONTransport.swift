import Foundation

struct JSONTransport: Sendable {
    let session: URLSession

    func value<T: Decodable>(
        _ type: T.Type,
        from request: URLRequest,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        let body = try await data(from: request)
        do {
            return try decoder.decode(type, from: body)
        } catch let alreadySaidPlainly as WikiAPIError {
            throw alreadySaidPlainly
        } catch {
            throw WikiAPIError.malformed(String(describing: error))
        }
    }

    @discardableResult
    func data(from request: URLRequest) async throws -> Data {
        let (body, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw WikiAPIError.status(http.statusCode)
        }
        return body
    }
}
