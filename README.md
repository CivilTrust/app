# CivilTrust MVP

Flutter Web/iOS client and a small encrypted coordinator for a two-party remote electronic-agreement demo. The implementation is isolated in `app/`; it does not modify `contracts/` or `service/`.

## What works

- Party A selects a deposit or loan template, consents to mock CCCD data, completes validated terms, freezes the agreement, and signs its canonical digest.
- The client encrypts the signing session with AES-256-GCM and uploads only the envelope to the coordinator.
- Party B opens a capability invite on another browser/device, verifies A, reads mock CCCD, and signs the same digest.
- For the current MVP payment direction, Party B transfers to Party A: B is the depositor for a deposit agreement or the lender for a loan agreement. Party A checks the real banking app before confirming receipt.
- Party A verifies the returned session, records a manual payment receipt confirmation, generates immutable `agreement.pdf`, hashes it with Keccak-256, calls the existing notary service, and finalizes the coordinator session.
- SCT/evidence stays in `evidence.civiltrust.json`; it is never inserted back into the hashed PDF.
- Export/import ZIP verifies the PDF hash, canonical evidence hash, and both mock signatures offline.

Mock signatures use ephemeral Ed25519 keys and are demo evidence only. The `IdentityReader` and `PartySigner` boundaries are designed to be replaced by Core NFC and a Keychain/Secure Enclave signing ceremony later.

## Run on Windows

Install Flutter, Node.js 20+, and start the coordinator:

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

## Configuration

Compile-time values are supplied with `--dart-define`:

| Variable              | Default                     |
| --------------------- | --------------------------- |
| `COORDINATOR_URL`   | `http://localhost:8788`   |
| `NOTARY_URL`        | `http://localhost:8787`   |
| `ARBITRUM_RPC_URL`  | Arbitrum Sepolia public RPC |
| `REGISTRY_CONTRACT` | zero address                |
| `CHAIN_ID`          | `421614`                  |

Do not put notary/relayer private keys or cluster secrets in Flutter defines.

## iOS and NFC

Windows can develop and test the Flutter Web/shared Dart code, but cannot build or install the iOS target. An iOS build requires macOS, Xcode, Apple signing, and a physical iPhone for NFC. The simulator cannot test real NFC.

`IosIdentityReader` is currently a deliberate seam, not a fake production implementation. Real CCCD support still requires the approved CCCD protocol/SDK, trust anchors, ISO 7816 APDU handling, Core NFC entitlement, privacy review, and tests on an iPhone.

## Deliberate MVP limits

- Coordinator storage is in memory; restarting it deletes sessions.
- Invite fragments are bearer capabilities. Share them over a trusted channel and never log them.
- Google Drive is deferred because OAuth, consent, token storage, and Drive scopes add deployment work. ZIP export/import is the portable baseline; a Drive repository can upload the exact same ZIP later.
- The app submits to the existing notary service, but local EIP-712 SCT verification, proof polling, Merkle verification, and direct RPC verification remain the next integration milestone.
- The payment receipt is an explicit Party A confirmation in the final evidence, not proof from a bank API.

Detailed architecture and phased work are in [plan.md](plan.md). Coordinator API details are in [coordinator/README.md](coordinator/README.md).
