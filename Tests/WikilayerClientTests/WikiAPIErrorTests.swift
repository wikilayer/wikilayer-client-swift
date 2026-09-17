import Foundation
import Testing

@testable import WikilayerClient

@Test func anUnreachableHostSaysWhichOneAndWhy() throws {
    let host = try #require(URL(string: "https://wiki.example"))
    let error = WikiAPIError.unreachable([WikiHostFailure(host: host, reason: .network(-1009))])

    let said = error.localizedDescription
    #expect(said.contains("wiki.example"))
    #expect(said.contains("-1009"))
    #expect(
        !said.contains("error 2"),
        """
        an enum that says nothing bridges to "the operation couldn't be completed (error 2)", \
        and every log line about a sync that failed then names the case number of a type the \
        reader cannot see, while the host and the reason sit unread inside it
        """
    )
}

@Test func aRefusedRequestSaysTheStatusItWasRefusedWith() throws {
    #expect(WikiAPIError.status(401).localizedDescription.contains("401"))
    #expect(WikiAPIError.malformed("sync page").localizedDescription.contains("sync page"))
}
