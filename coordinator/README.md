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
