# Hosts and Mirrors

Start with ``WikiHostConfiguration/bundled``, whose `hosts.yaml` belongs to this
library, and share its ``WikiHostPool`` between the API, authentication, and live
channel. Applications do not copy or own the server addresses.

The pool starts with a primary host and may receive ordered mirrors. Safe reads
advance after transport failures and configured blocking statuses; HTTP 451 is
enabled by default. A successful host becomes preferred for later calls.

Use the `preferred` argument to restore a previous choice and `didSelect` to save
changes. If every candidate fails, ``WikiAPIError/unreachable(_:)`` carries a
``WikiHostFailure`` for each attempt. This lets an application distinguish an
unreachable service from an ordinary server refusal and decide whether to suggest
a VPN.

Wikilayer currently has no mirror, so the bundled mirrors list is empty. A later
library release can add one without changing an application configuration.
