# CivilTrust App — Phân tích kiến trúc và kế hoạch triển khai

> Tài liệu này được lập từ `desv2.md` và đối chiếu với mã nguồn hiện có trong `contracts/` v1.4.0 và `service/` v1.3.0. Phạm vi triển khai là app/web, NFC CCCD, chữ ký của hai bên, tài liệu và giao diện kiểm chứng. Không thay đổi mã nguồn `contracts/` hoặc `service/`.

## 1. Kết luận kiến trúc

Ý tưởng lõi của CivilTrust khả thi cho đồ án:

1. Dữ liệu CCCD, ảnh và nội dung hợp đồng được xử lý ở phía người dùng.
2. Notary Service chỉ nhận `agreementHash` 32 byte và cấp Signed Commitment Token (SCT).
3. Cuối ngày, service gom các hash thành Merkle tree và neo Merkle root lên Arbitrum.
4. Người dùng hoặc bên thứ ba có thể tính lại hash, kiểm SCT và kiểm Merkle proof.

Tuy nhiên, `desv2.md` hiện mô tả kiến trúc mục tiêu, không phải toàn bộ chức năng đang có. Những phần chưa tồn tại gồm:

- App/mobile/web.
- Cơ chế đọc và xác thực CCCD thật.
- Chữ ký hợp đồng của Bên A và Bên B.
- Phiên ký và đồng bộ trạng thái giữa hai thiết bị.
- Upload/download ảnh, PDF và presigned URL.
- WebAuthn registration/challenge/verification backend.
- FROST2+ phía service.
- Định dạng evidence package có thể kiểm chứng độc lập.

Kiến trúc hoàn chỉnh nên gồm bốn tầng:

```text
Mobile app / Web app
        │
        ├── App coordination/media layer (nếu dùng phiên ký qua link)
        │
        ├── CivilTrust Notary Service
        │       ├── SCT
        │       ├── Daily Merkle batch
        │       └── Merkle proof
        │
        └── CivilTrustRegistry / Arbitrum
                ├── Receipt verification
                └── Merkle proof verification
```

Nếu không xây app coordination backend, hai bên phải trao đổi proposal/signed package trực tiếp qua QR, file hoặc native share.

### 1.1. Các quyết định đã chốt

| Nội dung | Quyết định |
|---|---|
| Framework | Flutter/Dart |
| Thiết bị hiện có | iPhone, không có điện thoại Android |
| NFC trong MVP | Mock để demo |
| NFC sau MVP | Nghiên cứu và tích hợp đọc CCCD thật trên iOS trước |
| Mô hình ký | Hai bên ký từ xa trên hai thiết bị |
| Contract/service | Chỉ tích hợp, không sửa trong phạm vi công việc app |

Hệ quả của các quyết định này:

- Có thể phát triển phần lớn ứng dụng bằng Flutter Web và unit/widget test mà chưa cần điện thoại Android.
- Nếu máy phát triển là Windows, không thể tự build iOS tại máy; vẫn làm được Flutter Web, Dart core và mock flow. Build iOS cần macOS và Xcode.
- iOS Simulator phù hợp để thử UI, navigation, state machine và mock NFC. NFC thật phải thử trên iPhone vật lý có NFC.
- Vì hai bên ở xa, app cần một coordination layer hoặc cơ chế trao đổi package. Notary Service không cung cấp chức năng này.
- MVP nên mô phỏng hai thiết bị bằng hai browser profile/cửa sổ hoặc iPhone + trình duyệt máy tính.

## 2. Phân chia trách nhiệm

### 2.1. App chịu trách nhiệm

- Tạo và chỉnh sửa dự thảo hợp đồng.
- Chụp, resize và nén ảnh ở client.
- Đọc CCCD qua adapter NFC.
- Hiển thị consent và chính sách xử lý dữ liệu cá nhân.
- Phân biệt “đã đọc dữ liệu” với “đã xác thực chip”.
- Đóng băng nội dung trước khi ký.
- Yêu cầu từng bên ký đúng cùng một digest.
- Tạo PDF/evidence package bất biến.
- Tính `keccak256` trên đúng artifact đã đóng băng.
- Gọi API submit/status/proof/recover.
- Tự kiểm SCT, chữ ký hai bên và Merkle proof.
- Lưu an toàn dữ liệu trên thiết bị và cho phép xuất/nhập gói bằng chứng.

### 2.2. Service hiện tại chịu trách nhiệm

- Nhận `agreementHash`.
- Ký SCT EIP-712 bằng ECDSA hiện tại.
- Lưu hash trạng thái `pending`/`batched`.
- Gom hash thành Merkle tree.
- Neo root lên smart contract.
- Trả status và proof.
- Nhận SCT/QR để phục hồi record.

### 2.3. Smart contract hiện tại chịu trách nhiệm

- Lưu một Merkle root bất biến cho mỗi `dateKey`.
- Kiểm chữ ký batch và receipt của notary.
- Kiểm Merkle proof của `agreementHash`.
- Quản lý `batchSigner`, `receiptSigner` và pause/unpause.

### 2.4. Những điều blockchain không tự chứng minh

- CCCD thuộc về người đang cầm điện thoại.
- Người đọc CCCD đã đồng ý ký hợp đồng.
- Nội dung hợp đồng hợp pháp.
- Người ký có năng lực hành vi phù hợp.
- Tiền đã thực sự chuyển hoặc nhận.
- SCT là chữ ký của hai bên. SCT chỉ là chữ ký của notary trên receipt.

## 3. Các quyết định kỹ thuật bắt buộc

### 3.1. Flutter đa nền tảng, mock-first và iOS NFC về sau

Web NFC chỉ phù hợp với NDEF và không cung cấp đầy đủ low-level ISO-DEP/APDU. Với thiết bị hiện có, kiến trúc được chốt như sau:

- Flutter Web là target phát triển chính của MVP mock.
- Flutter iOS là target mobile đầu tiên.
- iOS Simulator chỉ chạy `MockIdentityReader`.
- iPhone vật lý dùng Core NFC/`NFCISO7816Tag` thông qua Flutter plugin hoặc platform channel Swift ở giai đoạn NFC thật.
- Android `IsoDep` là adapter mở rộng về sau, không phải dependency của MVP.
- Web verifier dùng cùng package Dart cho schema, canonicalization và crypto nếu thư viện hỗ trợ nhất quán.

Điều kiện để build/test iOS:

- Cần máy macOS có Xcode để compile, ký và cài Flutter app lên iPhone.
- Nếu chỉ có Windows, phát triển bằng Flutter Web/Windows và test tự động trước; dùng Mac cá nhân, máy Mac của thành viên nhóm hoặc CI/macOS runner khi cần tạo bản iOS.
- Core NFC yêu cầu iPhone vật lý hỗ trợ NFC, usage description và entitlement/capability phù hợp. Không lập kế hoạch test NFC thật trên simulator.

Tầng NFC phải có abstraction:

```ts
interface IdentityReader {
  isSupported(): Promise<boolean>;
  read(request: IdentityReadRequest): Promise<IdentityEvidence>;
  cancel(): Promise<void>;
}
```

Hai implementation đầu tiên:

- `MockIdentityReader`: dùng cho phát triển và demo.
- `IosCccdIdentityReader`: Core NFC/SDK thật, triển khai sau MVP.
- `AndroidCccdIdentityReader`: extension tương lai nếu nhóm có thiết bị Android.

### 3.1.1. Chiến lược kiểm thử khi chỉ có một iPhone

- Unit test: chạy Dart test trên máy phát triển.
- Widget test: test form, navigation, validation và state transitions.
- Flutter Web: mở hai browser profile hoặc một cửa sổ thường + ẩn danh để đóng vai A/B.
- iOS Simulator: test giao diện mobile và mock NFC nếu có Mac.
- Một iPhone vật lý: test app iOS, secure storage, biometric prompt và sau này là NFC.
- End-to-end hai thiết bị: giai đoạn đầu dùng iPhone cho một bên và Flutter Web trên laptop cho bên còn lại; trước khi nghiệm thu thật cần mượn thêm một thiết bị hoặc nhờ một thành viên nhóm chạy bên B.

### 3.2. NFC và chữ ký là hai bước khác nhau

Đọc CCCD dùng để lấy/kiểm tra thông tin định danh. Nó không chứng minh người đó đồng ý với hợp đồng.

Mỗi bên vẫn phải thực hiện một hành động ký riêng trên digest của nội dung đã đóng băng. Sinh trắc học chỉ dùng để cho phép khóa thiết bị thực hiện chữ ký; không nên ghi rằng “Face ID chính là chữ ký CCCD”.

### 3.3. Chọn một artifact chuẩn để hash

Không thực hiện quy trình:

```text
Hash PDF → nhận SCT → chèn SCT vào PDF → dùng PDF mới để kiểm tra hash
```

Chèn SCT/QR làm thay đổi byte của PDF và khiến hash không còn khớp.

MVP nên dùng gói bằng chứng tách rời:

```text
civiltrust-package.zip
├── agreement.pdf
├── evidence.civiltrust.json
├── attachments/
└── verification-qr.png
```

- `agreement.pdf` được đóng băng rồi mới hash.
- SCT và proof nằm trong `evidence.civiltrust.json`.
- QR được xuất riêng hoặc đặt trên một trang chứng nhận không được coi là file PDF đã hash.
- Nếu bắt buộc một PDF tự chứa, phải thiết kế cơ chế revision/extract byte gốc riêng; không thực hiện trong MVP.

### 3.4. Chốt thứ tự thanh toán

Hai lựa chọn:

#### Phương án MVP

```text
Đóng băng điều khoản
→ A ký
→ B ký
→ B chuyển tiền
→ A xác nhận nhận tiền
→ Tạo artifact cuối
→ Hash
→ Submit notary
```

#### Phương án event chain

```text
Agreement artifact H1: A và B ký hợp đồng
Payment receipt H2: tham chiếu H1, A ký xác nhận nhận tiền
```

Phương án event chain linh hoạt hơn nhưng tạo nhiều artifact và nhiều hash. MVP nên dùng phương án đầu tiên.

### 3.5. Coordination layer cho hai bên ký từ xa

Do hai bên dùng hai thiết bị ở xa, chỉ dùng Notary Service là không đủ. App cần một trong hai chế độ:

#### Chế độ demo không backend thật

- `MockSessionRepository` giữ session trong memory/local test fixture.
- Hai browser profile kết nối tới một mock/dev coordinator.
- Có thể dùng export/import proposal package nếu muốn demo hoàn toàn offline.

#### Chế độ tích hợp từ xa

Xây một app coordination backend riêng, không đặt vào hoặc sửa `service/`. Backend tối thiểu cần:

```text
POST /sessions
GET  /sessions/:id
POST /sessions/:id/party-a-signature
POST /sessions/:id/party-b-signature
POST /sessions/:id/payment-receipt
POST /sessions/:id/finalize
```

Khuyến nghị privacy:

- Client mã hóa draft, ảnh và chữ ký trước khi upload.
- Server chỉ lưu ciphertext và trạng thái tối thiểu.
- Khóa giải mã nằm trong URL fragment hoặc được trao đổi ngoài server; fragment không được gửi trong HTTP request.
- Session ID và capability token phải ngẫu nhiên, không dùng số CCCD/SĐT.
- Session có TTL và chức năng xóa.
- Chỉ khi đã finalize, thiết bị chịu trách nhiệm hoàn tất mới gửi `agreementHash` sang Notary Service.

Nếu chưa xây coordinator, “ký từ xa” chỉ có thể thực hiện bằng cách A và B gửi file/package qua ứng dụng nhắn tin hoặc native share.

## 4. Quy trình dưới góc nhìn người dùng

### 4.1. Bên A — Người tạo thỏa thuận

1. A mở CivilTrust và chọn loại thỏa thuận: thuê trọ, vay tiền, đặt cọc hoặc bàn giao tài sản.
2. A nhập điều khoản, số tiền, thời hạn và các thông tin cần thiết.
3. A chụp tối đa số ảnh cho phép. Ảnh được resize/nén ngay trên thiết bị.
4. App giải thích mục đích đọc CCCD, dữ liệu nào được sử dụng và dữ liệu nào sẽ bị xóa.
5. A đồng ý rồi quét CCCD.
6. App hiển thị kết quả:
   - dữ liệu đã đọc;
   - chip đã/không được xác thực;
   - nguồn dữ liệu là NFC thật hay mock.
7. A kiểm tra toàn bộ bản dự thảo.
8. A bấm “Đóng băng nội dung”. Từ đây mọi thay đổi sẽ tạo revision mới.
9. App yêu cầu sinh trắc học/PIN để khóa thiết bị ký digest.
10. A chia sẻ proposal package hoặc link phiên ký cho B.

### 4.2. Bên B — Người nhận và ký

1. B mở link hoặc import proposal package.
2. App kiểm tra package, hash và chữ ký của A.
3. B đọc toàn bộ điều khoản và ảnh.
4. B quét CCCD nếu luồng yêu cầu định danh hai bên.
5. App hiển thị kết quả đọc/xác thực để B xác nhận.
6. B bấm “Đồng ý và ký”.
7. App yêu cầu sinh trắc học/PIN rồi ký đúng digest mà A đã ký.
8. Nếu có thanh toán, app hiển thị VietQR để B dùng app ngân hàng chuyển tiền.
9. B đánh dấu đã thực hiện chuyển khoản và gửi signed package cho A.

### 4.3. A xác nhận thanh toán và hoàn tất

1. A nhận signed package và app kiểm tra chữ ký B.
2. A tự kiểm tra tài khoản ngân hàng; CivilTrust không tự kết luận tiền đã đến.
3. A bấm “Tôi xác nhận đã nhận tiền”.
4. A ký xác nhận này bằng khóa thiết bị.
5. App tạo PDF và evidence manifest cuối cùng.
6. App đóng băng artifact, tính `agreementHash` và không sửa file sau bước này.
7. App gửi duy nhất hash tới `POST /api/v1/agreements/submit`.
8. Service trả SCT.
9. App tự kiểm tra SCT rồi hiển thị “Đã cấp biên nhận — đang chờ neo blockchain”.
10. A và B tải/lưu `civiltrust-package.zip`.

### 4.4. Sau khi batch được neo

1. Người dùng mở lại hợp đồng và bấm “Làm mới trạng thái”.
2. App gọi endpoint status.
3. Nếu `pending`, app giải thích hợp đồng đã có SCT nhưng chưa được neo trong daily batch.
4. Nếu `batched`, app tải Merkle proof.
5. App tự kiểm proof và có thể gọi `verifyAgreement` qua RPC.
6. App hiển thị transaction hash, chain, contract address và thời điểm neo.

### 4.5. Người kiểm chứng độc lập

1. Người kiểm chứng mở web verifier.
2. Họ kéo thả `agreement.pdf` và `evidence.civiltrust.json` hoặc chọn ZIP.
3. Trình duyệt tính lại hash cục bộ; tài liệu không cần upload lên notary service.
4. Web kiểm tra chữ ký A và B.
5. Web kiểm tra xác nhận nhận tiền nếu có.
6. Web kiểm SCT với đúng chain, contract và signer tin cậy.
7. Web kiểm Merkle proof và root on-chain.
8. Kết quả được hiển thị thành các mục độc lập:
   - tài liệu có khớp hash không;
   - chữ ký A có hợp lệ không;
   - chữ ký B có hợp lệ không;
   - SCT có hợp lệ không;
   - agreement đã được neo chưa;
   - Merkle proof có hợp lệ không;
   - đang kiểm tra chain/contract nào.

Không dùng một dấu tích xanh duy nhất cho mọi loại bằng chứng.

## 5. State machine đề xuất

```text
DRAFT
→ IDENTITY_A_VERIFIED
→ IDENTITY_B_VERIFIED
→ CONTENT_FROZEN
→ A_SIGNED
→ B_SIGNED
→ PAYMENT_PENDING            (nếu có thanh toán)
→ PAYMENT_CONFIRMED          (nếu có thanh toán)
→ FINALIZED
→ SUBMITTING
→ COMMITTED_PENDING_ANCHOR
→ BATCHED
→ VERIFIED
```

Các trạng thái lỗi cần có:

```text
NFC_UNAVAILABLE
IDENTITY_READ_FAILED
IDENTITY_NOT_AUTHENTICATED
SIGNATURE_REJECTED
SIGNATURE_INVALID
DOCUMENT_HASH_MISMATCH
NOTARY_UNAVAILABLE
SCT_INVALID
PROOF_UNAVAILABLE
PROOF_INVALID
WRONG_CHAIN_OR_CONTRACT
```

## 6. Mô hình dữ liệu app

```ts
interface EvidenceManifestV1 {
  schemaVersion: "civiltrust-evidence/v1";
  agreementId: string;
  revision: number;
  document: {
    fileName: string;
    mediaType: "application/pdf";
    hashAlgorithm: "keccak256";
    documentHash: `0x${string}`;
    attachmentHashes: `0x${string}`[];
  };
  parties: PartyEvidence[];
  paymentReceipt?: PaymentReceiptEvidence;
  notary?: {
    sct: SignedCommitmentToken;
    proof?: MerkleProofEvidence;
  };
}

interface PartyEvidence {
  role: "partyA" | "partyB";
  identityMethod: "cccd-nfc" | "manual" | "mock";
  identityCommitment: `0x${string}`;
  chipAuthentication: "verified" | "not_verified" | "unsupported" | "mock";
  signedDigest: `0x${string}`;
  publicKey: unknown;
  signature: unknown;
  signedAtClient: string;
}
```

Raw CCCD/APDU dump không được ghi vào manifest, URL, analytics hoặc debug log bản release.

## 7. Module source code đề xuất cho Flutter

```text
app/
├── pubspec.yaml
├── lib/
│   ├── app/                    # Router, theme, dependency injection
│   ├── features/
│   │   ├── agreements/         # Draft, freeze, review, finalize
│   │   ├── identity/           # Mock/iOS CCCD adapters
│   │   ├── signing/            # Party A/B signing ceremony
│   │   ├── sessions/           # Remote coordination
│   │   ├── payment/            # VietQR + receipt confirmation
│   │   ├── notary/             # submit/status/proof/recover
│   │   └── verifier/           # Local/chain verification
│   ├── core/
│   │   ├── evidence/           # Schema and canonicalization
│   │   ├── crypto/             # Hash/signature/SCT/Merkle
│   │   ├── storage/            # Secure/local persistence
│   │   └── networking/         # HTTP/RPC clients
│   └── platform/
│       ├── identity_reader.dart
│       ├── mock_identity_reader.dart
│       └── ios_identity_reader.dart
├── ios/
│   └── Runner/                 # Core NFC platform channel về sau
├── web/                        # Flutter Web shell
├── test/                       # Unit/widget/golden tests
├── integration_test/           # A/B and notary flows
├── coordinator/                # Backend phiên ký riêng nếu được phép
└── docs/
    ├── evidence-schema.md
    ├── signing-protocol.md
    └── threat-model.md
```

Không đặt private key notary/relayer hoặc cluster secret trong Flutter app.

## 8. Kế hoạch triển khai

### Giai đoạn 0 — Chốt giao thức và môi trường Flutter, 2–3 ngày

- Chọn artifact được hash.
- Chọn thứ tự ký/thanh toán/notarize.
- Xác nhận Flutter Web + Flutter iOS.
- Kiểm tra máy phát triển có macOS/Xcode hay cần mượn Mac/CI.
- Chọn session backend hay package exchange cho hai thiết bị từ xa.
- Viết `evidence-schema-v1`.
- Viết state machine và sequence diagram.

**Đầu ra:** không còn mơ hồ về byte nào được hash và mỗi chữ ký ký dữ liệu gì.

### Giai đoạn 1 — Flutter skeleton và vertical slice mock, 5–7 ngày

- Tạo Flutter project hỗ trợ web và iOS.
- Thiết lập router, state management, environment và test.
- Form hợp đồng mẫu.
- Hai mock identity.
- Freeze nội dung.
- Hai chữ ký test.
- Tạo PDF.
- Tính hash.
- Gọi `/submit`.
- Lưu và kiểm SCT.
- Export evidence package.

**Đầu ra:** chạy xuyên suốt được mà chưa phụ thuộc NFC thật.

### Giai đoạn 2 — Evidence Core và test vector, 4–5 ngày

- Canonical serialization.
- `keccak256` file.
- Evidence manifest schema validation.
- Party signature verification.
- SCT parsing/verification.
- Merkle proof verification.
- QR encode/decode.
- Test vector dùng chung giữa mobile và web.

### Giai đoạn 3 — Remote signing session, 1–2 tuần

- `SessionRepository` interface.
- `MockSessionRepository` cho demo.
- Tạo/join session bằng link hoặc QR.
- A và B quan sát cùng revision đã freeze.
- Optimistic locking/version check để ngăn ký hai revision khác nhau.
- Đồng bộ chữ ký và trạng thái.
- TTL, cancel và finalize ownership.
- Nếu được phép: coordinator backend riêng, ưu tiên lưu ciphertext.

### Giai đoạn 4 — Chữ ký hai bên, khoảng 1 tuần

- MVP: `MockPartySigner` có chữ ký kiểm được để hoàn thiện luồng.
- iOS thật: khóa P-256 trong Keychain/Secure Enclave nếu capability phù hợp.
- Yêu cầu LocalAuthentication/biometric hoặc device passcode trước khi ký.
- Ký digest của nội dung đã freeze.
- Ghi public key, algorithm và signature vào evidence.
- Flutter/Web verifier kiểm chữ ký.

Không phụ thuộc WebAuthn trong MVP. Nếu sau này dùng passkey/WebAuthn thì cần RP backend, challenge và credential registry riêng.

### Giai đoạn 5 — PDF, evidence package và VietQR, 4–6 ngày

- Render PDF cuối sau khi đủ chữ ký/sự kiện.
- Đóng băng file và tính hash.
- Export/import ZIP hoặc file evidence.
- Sinh VietQR.
- Tạo xác nhận nhận tiền riêng có chữ ký A.

### Giai đoạn 6 — Tích hợp notary và blockchain, 3–5 ngày

- Client cho submit/status/proof/recover.
- Xử lý submit `200` và `201`.
- Ghim chain ID/contract address theo environment.
- Kiểm SCT ECDSA v1.3.0.
- Kiểm proof cục bộ.
- Gọi `verifyReceipt`/`verifyAgreement` bằng RPC.
- Hiển thị transaction explorer link.

### Giai đoạn 7 — iOS NFC adapter sau MVP, 1–3 tuần cộng thời gian nghiên cứu SDK

- Kiểm tra thiết bị/quyền NFC.
- Scan lifecycle, timeout, retry và cancel.
- Flutter plugin hoặc platform channel sang Swift/Core NFC.
- Giao tiếp ISO 7816/APDU theo tài liệu/SDK được phép sử dụng.
- Tích hợp protocol CCCD khi có tài liệu và trust anchors.
- Xác minh certificate/chip nếu SDK cho phép.
- Xóa raw buffer sau khi trích xuất dữ liệu cần thiết.

### Giai đoạn 8 — Hardening và demo, 4–5 ngày

- Không log PII.
- Secure storage.
- Test sửa một byte PDF.
- Test chữ ký/SCT/proof giả.
- Test sai chain và contract.
- Test thiết bị không NFC.
- Test offline và service lỗi.
- Test export/import trên thiết bị khác.
- Chuẩn bị kịch bản demo trước và sau daily anchor.

Ước lượng một người sau khi đổi sang Flutter + remote session:

- MVP Flutter Web/iOS mock, hai bên ký từ xa qua mock/dev coordinator: 4–5 tuần.
- MVP có coordination backend ổn định: 5–7 tuần.
- iOS NFC thật và verifier hoàn chỉnh: cộng thêm 1–3 tuần sau khi có protocol/SDK, Mac và quyền/capability cần thiết.

## 9. Thứ tự ưu tiên

1. Chốt artifact và signing protocol.
2. Dựng Flutter Web/iOS project và shared Dart core.
3. Làm vertical slice bằng mock identity.
4. Làm remote session giữa hai browser/device.
5. Tích hợp ECDSA SCT hiện tại.
6. Làm web verifier.
7. Thêm VietQR/payment receipt.
8. Thêm iOS Core NFC sau khi có SDK/protocol và môi trường macOS.
9. Sau cùng mới làm media cloud và compatibility với FROST2+.

Không nên bắt đầu từ NFC thật hoặc giao diện đẹp trước khi chốt hash và signing protocol.

## 10. Phụ thuộc cần nhận từ thành viên contract/service

- Service base URL cho môi trường dev/test.
- Chain ID và địa chỉ contract Arbitrum Sepolia.
- ABI chính xác của deployment.
- `batchSigner` và `receiptSigner` test.
- Một SCT ECDSA hợp lệ làm test vector.
- Một daily batch/proof hợp lệ làm test vector.
- Quyết định response SCT idempotent phải có field `signer`.
- Chính sách kiểm receipt lịch sử sau khi rotate signer.
- Cách xử lý recovery cho record `pending` thuộc ngày cũ.
- Xác nhận FROST2+ không chặn MVP.

## 11. Rủi ro cần ghi đúng trong báo cáo

- PWA thuần không bảo đảm đọc được CCCD chip.
- NFC không thay thế hành động ký.
- WebAuthn user verification không tự cung cấp danh tính ngoài đời.
- Không được nhúng SCT vào PDF sau khi đã hash nếu không có chuẩn revision.
- Service hiện chưa có FROST2+.
- Service hiện chưa có media/presigned URL/session API.
- SCT Receipt không có `deadline`; deadline chỉ có ở BatchAttestation.
- Chi phí gas/storage/domain là ước lượng biến động.
- Zero-PII on-chain không đồng nghĩa toàn hệ thống tự động tuân thủ pháp luật dữ liệu cá nhân.
- Không gọi sản phẩm là công chứng hoặc dịch vụ dấu thời gian được công nhận nếu chưa có đánh giá pháp lý phù hợp.

## 12. Tiêu chí hoàn thành MVP

- Hai bên nhìn thấy và ký đúng cùng một nội dung đã freeze.
- Một byte thay đổi làm verification thất bại.
- Mock CCCD và adapter NFC dùng chung interface.
- Không gửi PII tới Notary Service hoặc RPC.
- App tự kiểm SCT thay vì chỉ tin API response.
- App theo dõi được `pending` → `batched`.
- App tự kiểm Merkle proof.
- Export/import evidence package tái lập đúng hash và kết quả chữ ký.
- Web verifier hiển thị riêng từng loại bằng chứng.
- Kịch bản demo không phụ thuộc FROST2+ hoặc mainnet.

## 13. Các câu hỏi cần chốt trước khi bắt đầu code

Các câu hỏi còn lại sau khi đã chốt Flutter, mock-first và hai thiết bị từ xa:

1. Máy phát triển của bạn là Windows hay macOS? Bạn có quyền sử dụng một máy Mac để build iOS không?
2. Luồng ký từ xa có được phép xây một coordination backend riêng trong `app/` không?
3. Nếu có backend, MVP được phép lưu draft/ảnh hay phải mã hóa hoàn toàn ở client trước khi upload?
4. Artifact được neo là hash của PDF hay hash của canonical evidence manifest?
5. Thanh toán và xác nhận nhận tiền phải nằm trong cùng artifact hay là event riêng?
6. MVP dùng mock device signature hay bắt buộc passkey/WebAuthn/chữ ký sinh trắc học thật?
7. MVP có bắt buộc Viettel IDC/Google Drive không, hay chỉ cần export/import file?
8. Nhóm đã có service URL và contract Sepolia deployment chưa?
9. Deadline nộp bài và số người làm phần app là bao nhiêu?

## 14. Cập nhật quyết định và trạng thái MVP (10/10/2026)

Các câu 1–7 ở trên đã được chốt:

- Máy phát triển là Windows, hiện không có máy Mac.
- Cho phép coordinator backend riêng trong `app/coordinator/`.
- Coordinator chỉ giữ AES-256-GCM ciphertext; khóa giải mã nằm trong capability invite.
- Artifact bất biến là `agreement.pdf`; SCT/proof nằm trong `evidence.civiltrust.json`.
- Hai bên ký xong, chuyển tiền và Bên A xác nhận nhận tiền trước khi tạo PDF cuối và submit hash.
- Hai bên có thể dùng Flutter app hoặc Flutter Web; MVP demo bằng hai browser/device.
- ZIP export/import là bắt buộc. Google Drive là tích hợp sau MVP vì cần OAuth/consent/token lifecycle, nhưng sẽ tải lên đúng gói ZIP nên không đổi evidence protocol.

Đã triển khai trong `app/`:

- Flutter Web/iOS skeleton và giao diện Tạo/Tham gia/Kiểm chứng/Cấu hình.
- `IdentityReader` với mock CCCD và seam dành cho iOS Core NFC.
- Canonical JSON + Keccak-256 content/document digest.
- Chữ ký mock Ed25519 kiểm chứng được và session validator chống đổi draft/digest/chữ ký.
- Hai thiết bị ký từ xa qua coordinator với bearer capability, AES-GCM, TTL và optimistic locking.
- PDF cuối, evidence sidecar, ZIP export/import và kiểm tra offline.
- Client gọi đúng endpoint submit của `service/` và đọc SCT từ response envelope.
- Unit/widget tests cho capability, AES-GCM, chữ ký và UI smoke test.

Chưa thuộc vertical slice hiện tại và là backlog ưu tiên:

1. Kiểm SCT EIP-712 hoàn toàn ở client thay vì mới lưu response.
2. Poll status, tải/kiểm Merkle proof và gọi RPC `verifyAgreement`.
3. Persist coordinator bằng Redis/PostgreSQL, rate limit, audit tối thiểu và triển khai HTTPS.
4. Ký xác nhận nhận tiền riêng bằng khóa của A; hiện receipt là xác nhận rõ ràng trong final evidence.
5. Adapter Google Drive tải/lấy nguyên ZIP.
6. Keychain/Secure Enclave + LocalAuthentication và CCCD NFC thật trên iPhone.
7. Media/ảnh đính kèm với hash riêng, giới hạn dung lượng và mã hóa client-side.

Hai thông tin còn cần từ nhóm contract/service để hoàn thiện tích hợp blockchain là URL dev, địa chỉ deployment Arbitrum Sepolia/ABI và test vector SCT + Merkle proof. Thông tin quản lý dự án còn thiếu là deadline và số người thực hiện phần app.

## 15. Cập nhật hai mẫu hợp đồng và luồng giao diện (10/10/2026)

### 15.1. Kết quả đọc mẫu

- `template/Hop-dong-thue-nha-lam-tam-tru.docx` cung cấp cấu trúc thông tin hai bên, CCCD, địa chỉ, tài sản/địa điểm, giá trị, thời hạn, bàn giao, nghĩa vụ, vi phạm và giải quyết tranh chấp. Do đây là mẫu thuê nhà chứ không phải hợp đồng đặt cọc, MVP chỉ kế thừa cấu trúc dữ liệu và điều khoản chung rồi chuyển thành mẫu đặt cọc đa mục đích.
- `template/hop-dong-vay-tien_1009151044_2311232834.doc` là Word nhị phân cũ. Nội dung chính gồm thông tin hai bên, số tiền, mục đích vay, giao tiền, thời hạn, lãi suất, chậm trả, chi phí, cam kết và tranh chấp. Mẫu này được ánh xạ trực tiếp hơn sang hợp đồng vay.
- Mẫu gốc được giữ nguyên và đóng gói như asset tham chiếu; ứng dụng không sửa trực tiếp file Word. Nội dung hợp đồng thực tế được sinh từ dữ liệu có cấu trúc để dễ kiểm tra, hash và thay adapter NFC sau này.

### 15.2. Luồng người dùng đã cải thiện

1. Bên A chọn **Hợp đồng đặt cọc** hoặc **Hợp đồng vay tiền**.
2. A đọc CCCD mock; tên, ngày sinh, số CCCD, ngày/nơi cấp và địa chỉ được tự điền.
3. A điền trường riêng của mẫu và thông tin tài khoản nhận tiền.
4. A xem toàn văn, đánh dấu đã đọc và khóa nội dung. Từ thời điểm này hai bên ký cùng một digest bất biến.
5. App tạo link mời riêng và VietQR động chứa ngân hàng, số tài khoản, số tiền, nội dung chuyển khoản.
6. B mở link trên thiết bị/browser khác, đọc hợp đồng, xác minh CCCD mock, đồng ý và ký.
7. B quét QR/chuyển bằng app ngân hàng rồi đánh dấu đã chuyển. Đây chỉ là thông báo trạng thái, không được coi là bằng chứng tiền đã đến.
8. A làm mới trạng thái, kiểm tra giao dịch thật trong app ngân hàng và xác nhận đã nhận tiền.
9. App tạo `agreement.pdf`, nhận SCT nếu Notary Service sẵn sàng, rồi xuất ZIP gồm PDF bất biến và `evidence.civiltrust.json`.
10. Bất kỳ ai cũng có thể nhập ZIP ở màn Kiểm chứng để đối chiếu hash, chữ ký và SCT.

### 15.3. Trường dữ liệu theo mẫu

- Đặt cọc: loại giao dịch, mô tả tài sản, địa chỉ/giao nhận, tổng giá trị, tiền cọc, hạn hoàn tất, xử lý vi phạm, thỏa thuận bổ sung.
- Vay tiền: mục đích vay, tiền gốc, ngày giải ngân, ngày đến hạn, lãi suất năm, cách trả nợ, xử lý chậm trả, thỏa thuận bổ sung.
- Thông tin định danh dùng chung: họ tên, ngày sinh, số CCCD, ngày/nơi cấp, thường trú, nơi ở hiện tại và identity commitment.

### 15.4. Ranh giới MVP và hướng NFC thật

- `IdentityReader` là interface ổn định. Mock hiện trả đúng schema dự kiến cho NFC nên thay bằng `NfcIdentityReader` không phải đổi màn hợp đồng, hash hay artifact.
- NFC chỉ cung cấp/kiểm chứng dữ liệu chip; thao tác đồng ý và chữ ký điện tử vẫn là bước riêng.
- VietQR là payload tạo phía client; cần thử với nhiều app ngân hàng trước production. MVP không tự đọc biến động số dư nên A bắt buộc kiểm tra tiền thật.
- Nội dung mẫu hiện phục vụ demo kỹ thuật, chưa thay thế việc luật sư rà soát điều khoản, đặc biệt lãi suất, phạt cọc, thẩm quyền tranh chấp và bảo vệ dữ liệu cá nhân.
- Google Drive, Secure Enclave/passkey, CCCD NFC thật và xác minh SCT/Merkle on-chain đầy đủ vẫn thuộc giai đoạn sau.
