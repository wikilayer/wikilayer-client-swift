# Changelog

## 0.3.0

### Changed

- What a wiki looks like now travels on the wiki's own node in a sync:
  `SyncNode.iconURL` and `SyncNode.pagesTree`. A reader who follows a wiki
  rather than owning it is listed it nowhere, so the account's listing could
  never tell them, and it no longer pretends to: `MyWiki` has lost `iconURL`
  and `pagesTree`.
- `WikiSummary` and `ResolvedAddress` keep the icon and lose `pagesTree`: both
  answer about a wiki the reader does not hold yet, which is the only moment
  before its own node can speak.

### Requires

- A server from 21 September 2026 or later, second deploy of that day.

## 0.2.0

### Added

- `SyncNode.pageID` names the page a node belongs to, as the server works it out:
  a page answers with itself, a block with its nearest page ancestor. A page's
  document is the nodes carrying its identifier, so it stops at a page nested
  inside it.
- `WikiSummary`, `MyWiki` and `ResolvedAddress` carry the wiki's icon and whether
  it keeps pages under pages: `iconURL` / `wikiIconURL` and `pagesTree` /
  `wikiPagesTree`.

### Removed

- `NodePath.page`. A path carries identifiers and no kinds, so it could only ever
  answer with the first node below the wiki, which is the wrong page for anything
  inside a nested one. Read `SyncNode.pageID` instead:

  ```swift
  // was
  let page = node.nodePath.page
  // now
  let page = node.pageID
  ```

  A store that derived its own page column from the path holds the same mistake
  and has to be rebuilt from the synchronised values.

### Requires

- A server from 21 September 2026 or later. Against an older one every `pageID`
  reads 0.

## 0.1.6

### Added

- `AuthAPI` reports the server's refusal to close an account that still owns a
  live wiki, so the app can say which wikis are in the way.

## 0.1.5

### Added

- `AuthAPI.closeAccount(as:reason:)` for deleting an account from the app.

## 0.1.4

### Changed

- Expanded the API reference with the contracts for synchronisation, live
  changes, authentication, host selection, failures and wire models. No API
  changes are required when updating.

## 0.1.3

### Fixed

- Cancellation is returned to the caller instead of being reported as an
  unreachable host.

## 0.1.2

### Changed

- `WikiAPIError` now provides a readable description containing the failed host
  and its reason instead of a generic system error.

## 0.1.1

### Changed

- The server to talk to, and the mirrors to fall back on, now ship with the
  library in `hosts.yaml` rather than being written into each application.
  Existing callers can continue to create `WikiHostPool` with an explicit host.

## 0.1.0

### Added

- Requests and response models for the public directory, address resolution,
  synchronisation and authentication.
- A live change channel for wikis.
- Ordered hosts with automatic failover for safe requests and a typed failure
  for every host attempted.
