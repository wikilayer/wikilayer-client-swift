# Changelog

## 0.5.0

### Changed

- The shared corpus now says what a sort key past ASCII does to the order of
  siblings: it is read by the code points of its characters. This port already
  answered that way, the Kotlin port did not, and a wiki whose sort keys reach past
  the basic plane came out in a different order there. Both ports move to this
  minor together.

## 0.4.0

### Added

- The tree of pages a wiki keeps, which every app reading a wiki works out the
  same way and until now wrote for itself.

  ```swift
  struct PageInTree {
      let id: Int64
      let parentID: Int64   // the node it hangs from: the wiki itself at the top
      let title: String
      let sortKey: String   // SyncNode.sortKey, the server's order among siblings
      let isHome: Bool      // the page the wiki is read from
  }

  let tree: [PageBranch] = pages.pageTree
  ```

  Hand in the pages of one wiki in one language, including the home page, in any
  order: siblings come back by `sortKey` and then by id, and the home page leads
  whatever it sorts as, so two apps storing the same wiki draw the same tree.

  `PageBranch` carries `id`, `title` and `children: [PageBranch]`. Nothing handed
  in is dropped: a page whose parent was not handed in is a root of its own, so
  are pages whose parents form a cycle, and a page repeated across two sync
  batches is kept once.

  ```swift
  tree.outline(expanded: Set<Int64>)   // -> [PageOutlineRow]
  tree.neighbours(of: Int64)           // -> PageNeighbours?
  tree.ancestors(of: Int64)            // -> [Int64]
  ```

  `PageOutlineRow` is `id`, `title`, `depth` counting from 0 at the top, and
  `hasChildren`, which tells a closed branch from a page with nothing under it.
  Only the branches named in `expanded` show their children, and which those are
  stays with the caller.

  `PageNeighbours` is `previous` and `next`, each a `PageStep` of `id` and
  `title`. The walk closes into a ring, so the last page leads back to the first
  rather than to a dead end. Fewer than three pages answer `nil`, because with
  two both ways lead to the same page, and so does a page the tree does not hold:
  either way there is nowhere to step from here.

  `ancestors(of:)` lists the pages above the given one, outermost first, and does
  not include the page itself.

## 0.3.0

### Changed

- What a wiki looks like now travels on the wiki's own node in a sync:
  `SyncNode.iconURL` and `SyncNode.pagesTree`. Every wiki has one node of kind
  `wiki`, whose `id` is the wiki's own, and a sync returns it like any other:

  ```swift
  // was: taken from the account's listing of the wikis a reader owns
  let icon = myWiki.iconURL
  let keepsPagesUnderPages = myWiki.pagesTree

  // now: taken from the wiki's own node, as it arrives in a sync
  let node = batch.nodes.first { $0.kind == .wiki && $0.id == wikiID }
  let icon = node?.iconURL
  let keepsPagesUnderPages = node?.pagesTree ?? false
  ```

  The listing only ever covered the wikis a reader owns, so it could never
  answer for a wiki they merely follow; `MyWiki` has lost `iconURL` and
  `pagesTree` rather than keep answering for half of them.
- `WikiSummary` and `ResolvedAddress` keep the icon and lose `pagesTree`. Both
  describe a wiki before it is followed, when no node for it has arrived yet,
  which is why the icon stays on them and the rest moves.

### Requires

- A server from 21 September 2026 or later, second deploy of that day. An older
  one is told apart by what it sends: the wiki's node arrives without
  `icon_url` and `pages_tree`, so every wiki reads as having neither.

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

- `AuthAPI.deleteAccount(reason:as:)` throws `AccountDeletionError.liveWikis`
  when the server refuses to delete an account that still owns wikis it has not
  archived, so the app can name the wikis that are in the way instead of
  showing a bare failure.

## 0.1.5

### Added

- `AuthAPI.deleteAccount(reason:as:)` for deleting an account from the app.

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
