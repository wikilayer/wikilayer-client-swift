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

The overload with an explicit `limit` controls the server page size. The overload
without one uses the `syncPageSize` supplied to ``WikiAPI/init(hosts:session:syncPageSize:directoryPageSize:)``.

Cancellation is returned unchanged. Retryable host failures may select a mirror;
if every candidate fails, the call throws ``WikiAPIError/unreachable(_:)``.
