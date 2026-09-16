import Foundation
import Testing

@testable import WikilayerClient

struct WikiHostConfigurationTests {
    @Test("the bundled host belongs to the library")
    func bundled() {
        #expect(WikiHostConfiguration.bundled.primary.absoluteString == "https://wikilayer.org")
        #expect(WikiHostConfiguration.bundled.mirrors.isEmpty)
    }

    @Test("ordered mirrors are read from YAML")
    func mirrors() throws {
        let hosts = try WikiHostConfiguration.parse("""
        primary: https://wikilayer.org
        mirrors:
          - https://one.example
          - https://two.example
        """)

        #expect(hosts.mirrors.map(\.host) == ["one.example", "two.example"])
    }
}
