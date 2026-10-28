# CivilTrust App Coordinator

Minimal coordination API for remote two-device signing. It is intentionally separate from `service/`.

The server stores opaque AES-GCM envelopes plus workflow metadata and hashed capability tokens. Encryption/decryption happens in the Flutter client. Legacy `/v1` retains owner/participant semantics. New `/v2` separates creator ownership from business roles A/B and requires signed, role-scoped actions with optimistic version checks.

```powershell
cd coordinator
npm.cmd test
npm.cmd start
```

Default URL: `http://localhost:8788`.

Requires Node.js >=24. The server/demo uses SQLite at `app/.demo/coordinator.sqlite` (override with `COORDINATOR_DB_PATH`). Keep and back up that file across restarts; tests use the memory adapter unless explicitly testing SQLite. This single-node demo is not permanent production storage. Legacy sessions expire after 24 hours; v2 active sessions after 7 days, finalized artifact downloads after 30 days.

## Creator-independent workflow `/v2`

- `POST /v2/sessions`: preallocated session ID, owner/participant tokens, creatorRole, public action key, signed creation packet and encrypted payload. Repeating the same identity/capabilities is idempotent; it does not replace existing payloads.
- `GET /v2/sessions/:id`: bearer capability required; returns role, version, phase, expiry, registered keys and encrypted snapshot.
- `POST /v2/sessions/:id/actions`: capability plus signed packet binding role/action/version/draft digest/encrypted payload hash. A approves recipient details, creator signs first, other party signs next, B reports transfer, A confirms receipt. The frozen draft digest cannot change.
- `publishArtifact` action: only A after receipt confirmation; atomically stores encrypted original ZIP and finalizes the session. `GET /v2/sessions/:id/artifact` allows either capability to retrieve the same encrypted archive. V1 cannot mutate v2 sessions.

Capabilities are not legal identity. The initial owner knows the participant invitation token; action signatures and mock identity do not prove two distinct real people. Trusted CCCD/NFC verification remains separate future work. Never log tokens, seeds, decrypted agreements or invitation fragments.

## CORS and phone demo

Default development CORS allows HTTP loopback origins only. Set
`ALLOWED_ORIGINS=https://app.example.test` (comma-separated exact origins,
without trailing paths) for a deployed Web client. `APP_ENV=staging` requires
an explicit HTTPS allowlist. Origins outside the list are rejected before
session mutations; requests without Origin remain available to native/CLI
clients and must still provide the appropriate session capability. CORS is
not authentication. The demo is capped at 200 retained sessions;
expired entries are reclaimed when creating new sessions.

`node src/demo-server.js` serves only `app/build/web` and routes
`/coordinator/*` to this handler, binding to `127.0.0.1:8790` by default.
It does not proxy `service/`, expose source files or log request URLs/bodies.
Use the app-level `start-phone-demo.ps1`/`stop-phone-demo.ps1` scripts for a
temporary HTTPS URL and lifecycle state. See [phone demo runbook](../docs/phone-demo.md).
