# Changelog

## 0.1.1

- Move the primary host and mirror list into the library-owned `hosts.yaml`.
- Provide `WikiHostConfiguration.bundled` for applications.

## 0.1.0

- Extract the Wikilayer API requests, response structures and live change
  channel from the iOS application.
- Allow a client to try an ordered set of hosts after network failures and
  report when none can be reached.
