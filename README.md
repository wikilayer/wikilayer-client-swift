# Wikilayer Client for Swift

The Swift client for the Wikilayer API. It owns the requests and responses that
cross the network: authentication, the public directory, address resolution,
wiki synchronisation and the live change channel.

It does not own a local database, screen state or background scheduling. An app
decides how an arrived `SyncNode` is stored and when another pass starts.

```swift
let host = URL(string: "https://wikilayer.org")!
let hosts = WikiHostPool(primary: host)
let api = WikiAPI(hosts: hosts)

let directory = try await api.wikis(matching: "markdown")
let batch = try await api.sync(wikiID: 2982, after: nil)
```

## Mirrors and blocked networks

`WikiHostPool` takes the primary server and any mirrors. A request tries the next
host only after a network failure such as a timeout; an HTTP refusal remains the
answer and is not hidden by another host. A host that succeeds becomes the first
one tried afterwards. Pass a stored preferred host at startup and save changes
with `didSelect` if that choice must survive relaunches.

When every configured host fails at the network level, the client throws
`WikiAPIError.unreachable`. The app can distinguish that outcome from an HTTP
status and tell a reader that the service may require a VPN. The library does not
word or present that message.

Wikilayer currently has no mirror, so applications configure only
`https://wikilayer.org`.

## Running it

```sh
make test
make lint
```
