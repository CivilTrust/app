# CivilTrust App Coordinator

Minimal coordination API for remote two-device signing. It is intentionally separate from `service/`.

The server stores only opaque AES-GCM envelopes. Encryption/decryption happens in the Flutter client. Session capabilities are random bearer tokens; the owner capability can finalize or delete, while either party can read and update with optimistic version checks.

```powershell
cd coordinator
npm.cmd test
npm.cmd start
```

Default URL: `http://localhost:8788`.

This MVP uses in-memory storage. Restarting the process removes every session. Production work should replace the `Map` with a TTL-capable store while preserving the same encrypted envelope contract.

## CORS and phone demo

Default development CORS allows HTTP loopback origins only. Set
`ALLOWED_ORIGINS=https://app.example.test` (comma-separated exact origins,
without trailing paths) for a deployed Web client. `APP_ENV=staging` requires
an explicit HTTPS allowlist. Origins outside the list are rejected before
session mutations; requests without Origin remain available to native/CLI
clients and must still provide the appropriate session capability. CORS is
not authentication. The in-memory demo is capped at 200 active sessions;
expired entries are reclaimed when creating new sessions.

`node src/demo-server.js` serves only `app/build/web` and routes
`/coordinator/*` to this handler, binding to `127.0.0.1:8790` by default.
It does not proxy `service/`, expose source files or log request URLs/bodies.
Use the app-level `start-phone-demo.ps1`/`stop-phone-demo.ps1` scripts for a
temporary HTTPS URL and lifecycle state. See [phone demo runbook](../docs/phone-demo.md).
