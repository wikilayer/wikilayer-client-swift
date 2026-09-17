import Foundation
import Testing

@testable import WikilayerClient

private func poolOfOne() throws -> WikiHostPool {
    let host = try #require(URL(string: "https://wiki.example"))
    return WikiHostPool(primary: host)
}

@Test func aCancelledRequestIsNotAHostThatCouldNotBeReached() async throws {
    let pool = try poolOfOne()

    await #expect(throws: URLError(.cancelled)) {
        try await onAvailableHost(in: pool) { _ in
            throw URLError(.cancelled)
        }
    }
}

@Test func aCancelledRequestToTheSelectedHostIsNotAHostThatCouldNotBeReached() async throws {
    let pool = try poolOfOne()

    await #expect(throws: URLError(.cancelled)) {
        try await onSelectedHost(in: pool) { _ in
            throw URLError(.cancelled)
        }
    }
}

@Test func aStoppedTaskIsNotAHostThatCouldNotBeReached() async throws {
    let pool = try poolOfOne()

    await #expect(throws: CancellationError.self) {
        try await onAvailableHost(in: pool) { _ in
            throw CancellationError()
        }
    }
}
