# ``WikilayerClient``

Read and authenticate with the Wikilayer API from a Swift application.

## Overview

WikilayerClient owns the values that cross the network and the calls that move
them. It covers authentication, the public directory, address resolution, wiki
synchronisation, and the live change channel. Storage and user interface policy
remain with the application.

Create one shared ``WikiHostPool`` and give it to each service:

```swift
let hosts = WikiHostPool(primary: URL(string: "https://wikilayer.org")!)
let wiki = WikiAPI(hosts: hosts)
let directory = try await wiki.wikis(matching: "markdown")
```

Reads can fail over to configured mirrors after network failures or selected HTTP
statuses. One-use authentication operations are never retried. See
<doc:Authentication-Flows> before integrating native or browser sign-in.

## Topics

### Reading Wikilayer

- ``WikiAPI``
- ``WikiChannel``
- ``WikiListening``

### Authentication

- <doc:Authentication-Flows>
- ``AuthAPI``
- ``OAuthClient``
- ``AuthorizationRequest``
- ``Credential``
- ``PKCE``

### Hosts and failures

- <doc:HostsAndMirrors>
- ``WikiHostPool``
- ``WikiHostFailure``
- ``WikiAPIError``

### Wire models

- ``Account``
- ``WikiSummary``
- ``WikiPage``
- ``MyWiki``
- ``MyWikiPage``
- ``SyncNode``
- ``SyncBatch``
- ``ResolvedAddress``
- ``NodePath``
