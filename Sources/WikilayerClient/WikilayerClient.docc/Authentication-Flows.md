# Authentication Flows

Keep one-use provider credentials on a single Wikilayer host.

## Native providers

Call ``AuthAPI/prepareHost()`` before opening the Apple or Google sign-in sheet.
The safe preflight selects a reachable host before the provider creates an
identity token. Send that token exactly once with
``AuthAPI/signIn(with:identityToken:nameOfferedOnce:)``.

## Browser OAuth

Create a ``PKCE`` value, then ask ``AuthAPI`` for one
``AuthorizationRequest``. Open its public ``AuthorizationRequest/url`` in the
system browser. After checking the returned state, exchange the code with
``AuthAPI/exchange(code:verifier:for:)``.

The authorization request remembers its issuing host internally. Callers cannot
move the exchange to another host, and an OAuth refusal or malformed callback
must not begin a second authorization flow against a mirror.
