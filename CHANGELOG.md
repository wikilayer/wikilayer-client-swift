# Changelog

## 0.1.2

- Say what went wrong: `WikiAPIError` now describes itself, so a failure
  reaches a log or a reader as the host that did not answer and the reason it
  gave, rather than as "the operation couldn't be completed (error 2)".

## 0.1.1

- Move the primary host and mirror list into the library-owned `hosts.yaml`.
- Provide `WikiHostConfiguration.bundled` for applications.

## 0.1.0

- Extract the Wikilayer API requests, response structures and live change
  channel from the iOS application.
- Allow a client to try an ordered set of hosts after network failures and
  report when none can be reached.
