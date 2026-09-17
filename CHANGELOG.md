# Changelog

## 0.1.2

- Say what went wrong: `WikiAPIError` now describes itself, so a failure
  reaches a log or a reader as the host that did not answer and the reason it
  gave, rather than as "the operation couldn't be completed (error 2)".

## 0.1.1

- The server to talk to, and the mirrors to fall back on, now ship with the
  library in `hosts.yaml` rather than being written into each application.
  `WikiHostConfiguration.bundled` hands them over; an application that named
  its own host keeps working by passing it to `WikiHostPool` as before.

## 0.1.0

- First release: the requests, the response types and the subscription that
  streams a wiki's changes as they happen, taken out of the iOS reader so
  anything else can use them too.
- A request may be given several servers in order, and moves to the next when
  one cannot be reached. When none answers, the failure names every one that
  was tried.
