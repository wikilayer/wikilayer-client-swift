[![Tests](https://github.com/wikilayer/wikilayer-client-swift/actions/workflows/tests.yml/badge.svg)](https://github.com/wikilayer/wikilayer-client-swift/actions/workflows/tests.yml)
[![Documentation](https://github.com/wikilayer/wikilayer-client-swift/actions/workflows/documentation.yml/badge.svg)](https://wikilayer.github.io/wikilayer-client-swift/documentation/wikilayerclient/)

# Wikilayer Client for Swift

The Swift client for the Wikilayer API. It owns the requests and responses that
cross the network: authentication, the public directory, address resolution,
wiki synchronisation and the live change channel.

[Read the generated API documentation.](https://wikilayer.github.io/wikilayer-client-swift/documentation/wikilayerclient/)

It does not own a local database, screen state or background scheduling. An app
decides how an arrived `SyncNode` is stored and when another pass starts.

Add the package dependency and the `WikilayerClient` product:

```swift
.package(url: "https://github.com/wikilayer/wikilayer-client-swift.git", from: "0.1.1")
```

```swift
let hosts = WikiHostConfiguration.bundled.pool()
let api = WikiAPI(hosts: hosts)

let directory = try await api.wikis(matching: "markdown")
let batch = try await api.sync(wikiID: 2982, after: nil)
```

## Mirrors and blocked networks

The library owns the primary server and mirrors in its bundled `hosts.yaml`.
Applications start from `WikiHostConfiguration.bundled` instead of copying host
addresses into their own configuration. `WikiHostPool` then tries the next
host after a network failure such as a timeout, or after an HTTP status explicitly
configured as a blocking response (`451` by default). Other HTTP refusals remain
the server's answer and are not hidden by another host. A host that succeeds
becomes the first one tried afterwards. Pass a stored preferred host at startup
and save changes with `didSelect` if that choice must survive relaunches.

Reads may move to the next host automatically. One-shot authentication operations
do not: an identity token or authorization code may already have been consumed
when only its response was lost. Call `AuthAPI.prepareHost()` before asking Apple,
Google or another provider for a one-use token. Browser OAuth then creates one
opaque `AuthorizationRequest`; its code exchange is bound to the same host. A
provider refusal, malformed callback or failed exchange is returned immediately,
never mistaken for a reason to begin another sign-in against a mirror.

When every configured host fails at the network level, the client throws
`WikiAPIError.unreachable`, carrying every attempted host and its typed network or
HTTP failure. The app can distinguish that outcome from an ordinary HTTP status
and tell a reader that the service may require a VPN. The library does not word or
present that message.

Wikilayer currently has no mirror, so the bundled list is empty. Adding one is a
library configuration release and requires no application change.

## Running it

```sh
make test
make lint
make docs
```

## Lines of Code

<picture>
  <source media="(prefers-color-scheme: dark)" srcset=".github/loc-history-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset=".github/loc-history-light.svg">
  <img src=".github/loc-history.svg" alt="Lines of code over time">
</picture>
