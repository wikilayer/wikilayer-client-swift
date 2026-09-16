# Hosts and Mirrors

Share one ``WikiHostPool`` between the API, authentication, and live channel.

The pool starts with a primary host and may receive ordered mirrors. Safe reads
advance after transport failures and configured blocking statuses; HTTP 451 is
enabled by default. A successful host becomes preferred for later calls.

Use the `preferred` argument to restore a previous choice and `didSelect` to save
changes. If every candidate fails, ``WikiAPIError/unreachable(_:)`` carries a
``WikiHostFailure`` for each attempt. This lets an application distinguish an
unreachable service from an ordinary server refusal and decide whether to suggest
a VPN.

Wikilayer currently has no mirror, so production applications should configure
only `https://wikilayer.org` until another endpoint exists.
