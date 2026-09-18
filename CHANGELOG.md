# Changelog

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
