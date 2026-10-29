# CivilTrust MVP

## NFC readiness (G0/G1)

See [NFC G0/G1 acceptance](docs/nfc-g0-g1-acceptance.md) for implemented bindings, tests and external blockers. Run `./nfc-preflight.ps1` for a read-only inventory. In the app open **Thông tin → Kiểm tra NFC readiness**. `IDENTITY_MODE` accepts `mock` (default), `native-lab`, or `verified-native`; native modes fail closed until a real SDK/verifier is integrated and never fall back to mock. No real CCCD should be used in this release.

New agreements use demo signing envelopes v2; evidence ZIP v2 remains supported and the new B-proposal flow uses evidence v3 for immutable PDF plus evolving payment evidence. Legacy v1 remains readable with an identity-unbound warning. A valid demo signature is not CCCD or cardholder authentication. The manual iOS preflight workflow is unsigned compilation only, not a device-installable build or NFC acceptance; it has not been run. Both parties must use the updated app for new profiles.

Flutter Web/iOS client and a small encrypted coordinator for a two-party remote electronic-agreement demo. The implementation is isolated in `app/`; it does not modify `contracts/` or `service/`.

## What works

The default UI uses the workspace described in [workspace acceptance](docs/workspace-acceptance.md). New B-created proposals follow [B-proposal acceptance](docs/payer-proposal-acceptance.md): B supplies terms and mock identity, A supplies its own mock identity/bank details, A freezes/signs, then B reviews/signs. The signed PDF is saved before payment; B may attach a receipt, A checks its bank and confirms, and later evidence retains exactly the same PDF hash. A-created flows retain their existing behavior. Existing B sessions retain creator-first semantics rather than changing an in-flight agreement. **Hồ sơ** provides encrypted local drafts/history and recovery export/import without accounts. Close/reopen requires the same origin and vault password, or an encrypted backup on another device. The original A-first description below applies to existing A/legacy flows.

- Party A selects a deposit or loan template, consents to mock CCCD data, completes validated terms, freezes the agreement, and signs a v2 envelope binding its canonical digest, role and mock identity.
- The client encrypts the signing session with AES-256-GCM and uploads only the envelope to the coordinator.
- Party B opens a capability invite on another browser/device, verifies A, reads mock CCCD, and signs its own v2 envelope referencing the same frozen draft digest.
- For the current MVP payment direction, Party B transfers to Party A: B is the depositor for a deposit agreement or the lender for a loan agreement. Party A checks the real banking app before confirming receipt.
- A/B share the same offline VietQR account-transfer profile, with PNG download/share and copyable payment details for a single-phone flow. New payment references are reviewed and signed in the draft; existing sessions keep their old reference. The **Thông tin → Thử VietQR cục bộ** tool generates a preview locally without creating a session or sending account details to coordinator/notary.
- Party A verifies the returned session, records a manual payment receipt confirmation, generates immutable `agreement.pdf`, hashes it with Keccak-256, calls the existing notary service, and finalizes the coordinator session.
- SCT/evidence stays in `evidence.civiltrust.json`; it is never inserted back into the hashed PDF.
- Export/import ZIP verifies the PDF hash, canonical evidence hash, and both mock signatures offline.

Mock signatures use ephemeral Ed25519 keys and are demo evidence only. The `IdentityReader` and `PartySigner` boundaries are designed to be replaced by Core NFC and a Keychain/Secure Enclave signing ceremony later.

## Run on Windows

Install Flutter, Node.js 24+, and start the coordinator:

```powershell
cd app\coordinator
npm.cmd test
npm.cmd start
```

In another terminal:

```powershell
cd app
flutter pub get
flutter run -d chrome `
  --dart-define=COORDINATOR_URL=http://localhost:8788 `
  --dart-define=NOTARY_URL=http://localhost:8787
```

On the prepared Windows development machine, you can also run `./run-web.ps1`.
The script uses `http://localhost:8787` for notary unless `CIVILTRUST_NOTARY_URL`
is set. The current Bun service defaults to port `3000`, so a local run normally
needs `$env:CIVILTRUST_NOTARY_URL='http://localhost:3000'` before launching
`./run-web.ps1` or `./run-demo.ps1`. The Flutter app must use the exact port on
which the service is listening.
After changing User PATH, close and reopen PowerShell before calling `flutter`
directly; an already-open terminal keeps its old PATH value.

For a one-command local demo that starts the coordinator when needed, use:

```powershell
./run-demo.ps1
```

Open two browser profiles/windows. Party A uses **Tạo hợp đồng**, copies the invite, and Party B opens it directly (the fragment switches to **Tham gia ký**) or pastes it manually. B signs and reports the transfer; A refreshes, checks the bank transaction, confirms receipt, and downloads the ZIP.

If the existing notary service is unavailable, ZIP export still succeeds without SCT. Start and configure `service/` separately when demonstrating SCT and later anchoring.
For a phone browser, `localhost` means the phone itself; use reachable HTTPS
coordinator/notary URLs. Native iOS builds still require a Mac.

For a temporary HTTPS URL shared by Windows and iPhone, run
`./start-phone-demo.ps1` (Flutter, Node and `cloudflared` required). It builds
the mock Web demo, serves the coordinator at the same origin and disables
notary requests until a real HTTPS service is supplied. Keep Windows awake;
stop with `./stop-phone-demo.ps1`. See [phone demo runbook](docs/phone-demo.md)
for device checks, lifetime and limitations.

## Configuration

Compile-time values are supplied with `--dart-define`:

| Variable              | Default                     |
| --------------------- | --------------------------- |
| `COORDINATOR_URL`   | `http://localhost:8788`   |
| `NOTARY_URL`        | `http://localhost:8787`   |
| `ARBITRUM_RPC_URL`  | Arbitrum Sepolia public RPC |
| `REGISTRY_CONTRACT` | zero address                |
| `CHAIN_ID`          | `421614`                  |
| `SCT_BATCH_SIGNER` | empty                     |
| `SCT_RECEIPT_SIGNER` | empty                   |
| `APP_ENV` | `local` (`staging` enforces reachable HTTPS configuration) |
| `NOTARY_ENABLED` | `true` (`false` explicitly exports without SCT/network calls to notary) |

Coordinator/notary URLs may also be root-relative (for example `/coordinator`)
when served by the same Web origin. Query, fragment and credential-bearing
endpoints are rejected by configuration checks. The **Thông tin** tab runs an
on-demand read-only health probe; it never creates a session or submits a PDF hash.

`SCT_BATCH_SIGNER` and `SCT_RECEIPT_SIGNER` are **public addresses** from the
same registry deployment as `REGISTRY_CONTRACT`. Configure at least one signer
and the correct chain/registry to let the app classify an SCT as locally valid.
Until then it reports `chưa cấu hình` even if ECDSA recovery succeeds. A locally
valid SCT means the PDF hash, EIP-712 domain, signature and configured signer
match; it does not establish Merkle inclusion or on-chain registration. Do not
put notary/relayer private keys or cluster secrets in Flutter defines.

## iOS and NFC

Windows can develop and test the Flutter Web/shared Dart code, but cannot build or install the iOS target. An iOS build requires macOS, Xcode, Apple signing, and a physical iPhone for NFC. The simulator cannot test real NFC.

`IosIdentityReader` is currently a deliberate seam, not a fake production implementation. Real CCCD support still requires the approved CCCD protocol/SDK, trust anchors, ISO 7816 APDU handling, Core NFC entitlement, privacy review, and tests on an iPhone.

## Deliberate MVP limits

- The server/demo persists encrypted sessions and token hashes in SQLite (`.demo/coordinator.sqlite`). Keep the database across restarts and back it up; active workflow sessions expire after 7 days, finalized downloads after 30 days. This is not permanent production hosting.
- Invite fragments are bearer capabilities. Share them over a trusted channel and never log them.
- Google Drive is deferred because OAuth, consent, token storage, and Drive scopes add deployment work. ZIP export/import is the portable baseline; a Drive repository can upload the exact same ZIP later.
- The app locally verifies EIP-712 SCT signatures against deployment-scoped public signer addresses when configured, including during ZIP import. The test vector comes from Viem; no live testnet deployment is bundled. Proof polling, Merkle verification and direct RPC verification remain the next integration milestones.
- The payment receipt is an explicit Party A confirmation in the final evidence, not proof from a bank API.

Detailed architecture and phased work are in [plan.md](plan.md). Coordinator API details are in [coordinator/README.md](coordinator/README.md).
