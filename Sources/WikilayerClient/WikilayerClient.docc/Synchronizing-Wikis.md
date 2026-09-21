# Synchronizing Wikis

Fetch an ordered page of changes and advance with the returned cursor.

Call ``WikiAPI/sync(wikiID:after:as:)`` with `nil` for the first page. Apply every
``SyncNode`` in the returned order, then persist ``SyncBatch/cursor`` only after
the whole page has been stored. While ``SyncBatch/hasMore`` is true, request the
next page immediately with that cursor.

A node whose ``SyncNode/deleted`` value is true removes the local record with the
same identifier. Other nodes replace the locally stored representation. Empty
wire fields are decoded as empty strings or zero values where the model declares
those defaults.

``SyncNode/pageID`` names the page a node belongs to: a page answers with itself,
and a block with its nearest page ancestor. A page's document is the nodes
carrying its identifier, which is what stops that document at a page nested
inside it. ``SyncNode/path`` cannot answer this, because it carries identifiers
and no kinds, so the server is the side that works it out.

The overload with an explicit `limit` controls the server page size. The overload
without one uses the `syncPageSize` supplied to ``WikiAPI/init(hosts:session:syncPageSize:directoryPageSize:)``.

Cancellation is returned unchanged. Retryable host failures may select a mirror;
if every candidate fails, the call throws ``WikiAPIError/unreachable(_:)``.
