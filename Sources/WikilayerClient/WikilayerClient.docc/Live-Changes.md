# Live Changes

Use the live channel as a signal to synchronize, not as a stream of wiki data.

``WikiChannel/changes(inWiki:as:)`` yields whenever the server announces that the
wiki changed. On every element, run the normal cursor-based synchronization pass.
Several changes may be represented by one signal, and reconnecting does not replay
missed signals, so the synchronization cursor remains the source of completeness.

The channel reconnects after a failure with exponential backoff between
`firstRetry` and `longestRetry`. It calls `onFailure` before waiting. Cancelling the
consumer task or ending iteration closes the stream without reporting a failure.

The credential closure is evaluated for each connection attempt, allowing a
renewed or removed credential to take effect after reconnecting.
