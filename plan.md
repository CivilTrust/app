# CivilTrust App — Phân tích kiến trúc và kế hoạch triển khai

> Cập nhật ngày 25/10/2026. Kế hoạch thực hiện hiện hành nằm ở mục 8–13; các mục 14–15 ghi lại quyết định và tiến độ trước đó. Phạm vi công việc chỉ là `app/` (Flutter client, web verifier và `app/coordinator/`). `contracts/` v1.4.0 và `service/` v1.3.0 do thành viên khác phụ trách; app chỉ tích hợp qua giao thức đã thống nhất.

## 1. Kết luận kiến trúc

Ý tưởng lõi của CivilTrust khả thi cho đồ án:

1. Dữ liệu CCCD, ảnh và nội dung hợp đồng được xử lý ở phía người dùng.
2. Notary Service chỉ nhận `agreementHash` 32 byte và cấp Signed Commitment Token (SCT).
3. Cuối ngày, service gom các hash thành Merkle tree và neo Merkle root lên Arbitrum.
4. Người dùng hoặc bên thứ ba có thể tính lại hash, kiểm SCT và kiểm Merkle proof.

`desv2.md` mô tả kiến trúc mục tiêu. Mã nguồn hiện tại đã có Flutter Web/iOS skeleton, hai chữ ký Ed25519 demo trên cùng digest, coordinator mã hóa phiên ký, PDF/ZIP và kiểm tra hash/chữ ký mock khi nhập ZIP. Những phần còn thiếu cho mục tiêu dài hạn là CCCD thật, chữ ký thiết bị gắn với danh tính, lưu trữ phiên bền vững, xác minh SCT/Merkle/RPC trong app, media/cloud và FROST2+ phía service. Mục 8 nêu rõ phần nào cần hoàn tất cho demo testnet trước hạn nộp.

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

Coordinator hiện đã nằm trong `app/coordinator/` và chỉ giữ encrypted envelope trong bộ nhớ. Mô hình trao đổi file/QR trực tiếp vẫn là phương án khác, không thuộc đường triển khai demo hiện tại.

### 1.1. Các quyết định đã chốt

| Nội dung | Quyết định |
|---|---|
| Framework | Flutter/Dart |
| Thiết bị hiện có | iPhone, không có điện thoại Android |
| NFC trong MVP | Mock để demo |
| NFC sau MVP | Nghiên cứu và tích hợp đọc CCCD thật trên iOS trước |
| Mô hình ký | Hai bên ký từ xa trên hai thiết bị |
| Contract/service | Chỉ tích hợp, không sửa trong phạm vi công việc app |
| Demo gần nhất | Flutter Web trên hai browser/profile, kiểm chứng trên Arbitrum Sepolia |
| Artifact được neo | `keccak256` của byte cuối cùng trong `agreement.pdf`; SCT/proof ở JSON đi kèm |
| Thời hạn | 2–3 tuần từ 25/10/2026; mục tiêu luồng chính trước 08/11, dự phòng đến 15/11 |
| Môi trường | Windows, chưa có Mac; không đặt iOS native/NFC thật vào điều kiện nghiệm thu demo |

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

Do hai bên dùng hai thiết bị ở xa, Notary Service không thay thế coordinator. `app/coordinator/` hiện có Node HTTP server lưu encrypted envelope trong memory, cấp owner/participant bearer capability, TTL và optimistic version. API hiện thực là:

```text
POST   /v1/sessions
GET    /v1/sessions/:id
PUT    /v1/sessions/:id           (expectedVersion + encryptedPayload)
POST   /v1/sessions/:id/finalize (owner only)
DELETE /v1/sessions/:id          (owner only)
```

Client mã hóa toàn bộ session bằng AES-256-GCM trước khi upload; coordinator không phân tích từng chữ ký hay trạng thái thanh toán. Khóa giải mã và participant token nằm trong URL fragment, không nằm trong query parameter hay HTTP request. Cả A và B hiện có thể `PUT` encrypted envelope nếu sở hữu capability tương ứng; server chỉ kiểm version, chưa enforce state transition theo vai trò. Restart server làm mất mọi phiên. Đây là giới hạn demo và là đầu việc production sau mục tiêu testnet.

Sau khi A/B ký và A xác nhận nhận tiền, client A tạo PDF rồi gửi duy nhất `agreementHash` sang Notary Service; finalize coordinator không được xem là bằng chứng đã neo.

## 4. Quy trình dưới góc nhìn người dùng

Mục 4 mô tả luồng sản phẩm tổng quát. Demo hiện chỉ có hai mẫu đặt cọc và vay tiền, CCCD mock, chữ ký Ed25519 demo và ZIP gồm PDF/JSON; trạng thái triển khai chính xác và việc cần làm tiếp nằm ở mục 8.

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

Sơ đồ dưới đây là trạng thái đích, không phải toàn bộ enum đã được implement. Demo phải tách trạng thái phiên ký khỏi các kết quả kiểm SCT/proof/RPC; `BATCHED` do service trả về chưa đồng nghĩa `VERIFIED`.

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

Interface dưới đây là phác thảo kiến trúc ban đầu, chưa phải schema ZIP hiện hành. Mã đang ghi `civiltrust-evidence/1.0` với `documentHash`, `evidenceHash`, `session`, `signedCommitment`, `merkleProof`; parser từ chối schema khác. Không đổi schema theo phác thảo này trong kỳ demo nếu chưa có version/migration và test vector. Signing envelope v2 ở mục 8.5 là công việc sau demo.

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

Đây là sơ đồ tổ chức mục tiêu; không phải danh sách thư mục đã có. Mã hiện đặt artifact verifier trong `lib/features/artifacts/` và coordinator tại `app/coordinator/`. Ưu tiên bổ sung adapter/test vào cấu trúc hiện có, không tái cấu trúc hàng loạt trước demo.

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

## 8. Kế hoạch hiện hành: demo testnet trong 2–3 tuần

### 8.1. Phạm vi, đường găng và mốc bàn giao

Kế hoạch này bắt đầu ngày 25/10/2026. Một người làm phần `app/`; `contracts/` và `service/` do thành viên khác thực hiện. Ngày mục tiêu là **08/11/2026** cho luồng chính, **15/11/2026** là hạn dự phòng chạy thử và sửa lỗi. Đây là mốc lập kế hoạch, cần cập nhật nếu nhóm chốt ngày nộp chính xác khác.

**Luồng demo cần đạt:** A chọn mẫu và ký bằng mock → B mở invite, ký và báo chuyển tiền → A kiểm tra app ngân hàng, xác nhận thủ công → app tạo PDF và ZIP → gửi duy nhất hash PDF cho service → app tự kiểm SCT → sau khi batch neo, app tải và tự kiểm Merkle proof → app gọi RPC read-only tới contract Sepolia → verifier trình bày từng mức bằng chứng. Hai browser profile trên máy Windows là kịch bản bắt buộc; iPhone + browser chỉ là kịch bản bổ sung khi đã có HTTPS và endpoint truy cập được từ điện thoại.

**Quy ước bất biến:** `agreementHash = keccak256(bytes của agreement.pdf cuối cùng)`. SCT và proof chỉ được bổ sung vào `evidence.civiltrust.json`/ZIP; không render lại PDF sau submit. Chữ ký A/B v1 ký digest của draft, không trực tiếp ký toàn bộ byte PDF. `PaymentReceipt` v1 là xác nhận thủ công của A, chưa có chữ ký mật mã riêng. UI phải ghi đúng các giới hạn này.

**Đầu vào ngoài app đang thiếu:** deployment Sepolia (address/ABI/signer), service URL thử nghiệm và một SCT + Merkle proof + transaction thật. App vẫn phát triển bằng fixture local trong khi chờ, nhưng không thể nghiệm thu bước on-chain nếu chưa có các đầu vào này.

### 8.2. Tuần 1 — 26/10 đến 01/11: kiểm SCT và chuẩn bị giao thức tích hợp

| Công việc trong `app/` | Cách thực hiện/đầu ra | Kiểm tra hoàn thành |
|---|---|---|
| Ổn định baseline | Chạy `flutter analyze`, `flutter test`, `npm test` của coordinator và web build trên môi trường có Flutter/Node; ghi lại lỗi môi trường riêng với lỗi code. Không đưa iOS build vào tuần này. | Bộ test hiện có chạy được; có script/hướng dẫn chạy demo hai browser. |
| Model/API SCT | Tạo model có kiểm version, field, độ dài hash/signature; adapter `NotaryClient` nhận cả submit `201` và idempotent `200`, không tin dữ liệu thiếu/sai định dạng. Giữ tương thích SCT ECDSA v1.3.0 của service. | Test với response mới, response lặp, thiếu `signer`, sai hash và lỗi HTTP. |
| EIP-712 verifier | Từ PDF hash và SCT, tính đúng typed-data digest; kiểm domain `CivilTrustRegistry`/`1`, chain ID, verifying contract, message hash, timestamp/nonce và ECDSA signer. Khi có deployment, đối chiếu signer được contract cho phép; trước đó chỉ ghi “hợp lệ với signer cấu hình/fixture”, không gọi là xác minh on-chain. | SCT hợp lệ pass; sửa một field, đổi chain/contract/signer hoặc sửa một byte PDF đều fail. |
| Tách trạng thái kết quả | Hiển thị rõ `PDF/ZIP đã tạo`, `SCT đã nhận`, `SCT đã tự kiểm`, `đang chờ anchor`, `proof đã kiểm`, `on-chain đã kiểm`; trạng thái service là dữ liệu đầu vào, không thay thế phép kiểm client. | Không có nhãn “đã neo” khi mới nhận SCT hoặc chỉ nhận status `pending`. |
| Liên hệ backend | Gửi danh sách bàn giao ở mục 10; yêu cầu fixture thật và deployment trước cuối tuần 1. | Nhận hoặc ghi rõ blocker cùng người phụ trách và ngày dự kiến. |

Các file trọng tâm: `lib/features/notary/notary_client.dart`, `lib/core/crypto/`, `lib/features/artifacts/evidence_manifest.dart`, `lib/features/artifacts/verify_bundle_page.dart`, test tương ứng. Không để private key notary/relayer trong Flutter defines hay ZIP.

### 8.3. Tuần 2 — 02/11 đến 08/11: Merkle proof và RPC Sepolia

| Công việc trong `app/` | Cách thực hiện/đầu ra | Kiểm tra hoàn thành |
|---|---|---|
| Status/proof client | Poll status có backoff/giới hạn; dùng `dateKey` service trả, gọi `GET /api/v1/agreements/:dateKey/:hash/proof`; phân biệt chưa có batch, record chưa có, lỗi mạng và response hỏng. | Không poll vô hạn; `404` không bị diễn giải là hash chưa từng được neo. |
| Merkle local | Dùng leaf `keccak256(bytes.concat(keccak256(abi.encode(agreementHash))))` và sorted-pair hashing giống service/contract. Đối chiếu root, hash, dateKey và proof trong response; lưu proof cùng metadata cần thiết trong sidecar. | Fixture 1/2/3 lá từ backend pass; proof, leaf, root hoặc dateKey sai fail. |
| RPC read-only | Pin chain ID và contract address theo môi trường; gọi `verifyReceipt` và `verifyAgreement` qua ABI đúng deployment; so sánh kết quả với kiểm tra local và hiển thị explorer link. Không broadcast anchor từ app. | Sai chain/address/ABI hoặc RPC unavailable hiện “chưa kiểm được”; chỉ trả “on-chain đã kiểm” khi `eth_call` cho kết quả hợp lệ. |
| ZIP sau anchor | Thêm SCT/proof/tx metadata vào `evidence.civiltrust.json`, giữ nguyên `agreement.pdf` và `documentHash`; cho tải ZIP cập nhật. Import ZIP trên browser khác phải kiểm lại từ đầu. | Hash PDF trước/sau khi thêm proof bằng nhau; import ZIP phát hiện PDF/proof bị sửa. |
| Chạy xuyên suốt | Hai browser A/B, coordinator và service testnet; chuẩn bị một hồ sơ đã neo sẵn vì cron 23:59 UTC tương ứng 06:59 hôm sau giờ Việt Nam. | Có một hash PDF, SCT, proof, tx hash và contract address Sepolia đối chiếu được độc lập. |

Nếu deployment/proof thật chưa có, hoàn thành adapter và test bằng fixture, giữ nhãn RPC là “chưa tích hợp testnet”. Thành viên service chịu trách nhiệm tạo batch hoặc cung cấp hồ sơ đã neo; app không tự sửa cron/relayer.

### 8.4. Tuần dự phòng — 09/11 đến 15/11: ổn định demo

1. Chạy lại hai mẫu đặt cọc/vay tiền trên hai browser, gồm refresh, invite hết hạn, version conflict, service mất mạng và submit lặp; khôi phục hoặc hướng dẫn lại thao tác thay vì báo thành công giả.
2. Kiểm export/import ZIP ở browser độc lập; đối chiếu SCT/proof/RPC. Kiểm tra chiều tiền: B chuyển cho A; A chỉ xác nhận sau khi tự kiểm app ngân hàng.
3. Kiểm UI tại khoảng 375, 768 và 1280 px, thao tác bằng bàn phím/touch, lỗi mạng và thông báo mock rõ ràng. Chỉ dùng iPhone Safari như kiểm tra web bổ sung nếu endpoint đã được triển khai HTTPS; không tuyên bố đã build iOS native.
4. Chuẩn bị hai bộ hồ sơ demo: trước anchor (SCT hợp lệ, proof chưa có) và sau anchor (proof/RPC hợp lệ), cùng các bản bị sửa để cho thấy verifier từ chối. Ghi địa chỉ contract, transaction và ngày batch trong kịch bản trình diễn.
5. Chạy lại static analysis, unit/widget tests, coordinator tests và Flutter Web release build. Chỉ mở rộng test nếu có lỗi tích hợp cụ thể.

### 8.5. Sau demo — chất lượng bằng chứng và sản phẩm lâu dài

**Ưu tiên đầu tiên: evidence/signing protocol v2.** V1 hiện chỉ ký `frozenDigest` của draft; object danh tính, vai trò, thời điểm ký và `PaymentReceipt` chưa được chữ ký ràng buộc đầy đủ. V2 cần signing envelope có version và domain separation, tối thiểu gồm agreement digest, `identityCommitment`, role, session/revision ID; xác nhận thanh toán là sự kiện riêng tham chiếu agreement và có chữ ký của A. Thêm migration/reader cho ZIP v1, test giả mạo từng field và không nâng nhãn bảo đảm của hồ sơ v1 lên v2. Vẫn giữ PDF hash là artifact neo trừ khi nhóm quyết định migration giao thức riêng.

Sau v2: lưu draft/capability an toàn để tiếp tục sau reload; persistent coordinator có TTL, rate limit, role-scoped updates và idempotency; phân phối ZIP cuối cho B; media/attachment manifest; cloud lưu nguyên ZIP. Chữ ký Keychain/Secure Enclave và Core NFC CCCD trên iPhone chỉ triển khai khi có Mac/Xcode, iPhone vật lý, protocol/SDK và trust anchors. FROST2+ ở service là nâng cấp tương thích chữ ký notary, không làm app đổi artifact hoặc luồng tạo hợp đồng.

## 9. Thứ tự ưu tiên và quy tắc cắt phạm vi

1. Demo trước hạn: SCT EIP-712 tự kiểm → proof Merkle tự kiểm → RPC Sepolia đọc và đối chiếu → ZIP sau anchor → E2E hai browser.
2. Các sửa tối thiểu để demo trung thực: nhãn mock, phân biệt các mức bằng chứng, xử lý lỗi/submit lặp và không tuyên bố metadata v1 đã được A/B ký đầy đủ.
3. Nếu thiếu thời gian, cắt UI polish, Google Drive, ảnh đính kèm, iOS native/NFC, Secure Enclave và coordinator production. Không cắt phép kiểm SCT/proof/RPC mà vẫn quảng bá là demo “on-chain verified”.
4. Sau demo, ưu tiên evidence/signing v2 trước khi dùng dữ liệu CCCD thật hoặc mở rộng hồ sơ ra production.

## 10. Bàn giao cần nhận từ thành viên contracts/service

| Đầu vào | Người phụ trách | App dùng vào việc gì | Hạn mong muốn |
|---|---|---|---|
| Chain ID 421614, address Sepolia, ABI đúng của deployment v1.4.0, contract version, explorer URL và tx deploy | Contracts | Pin EIP-712 domain, build RPC `eth_call`, chống nhầm chain/contract | Trước 01/11 |
| `batchSigner`, `receiptSigner` của deployment và chính sách kiểm SCT cũ khi signer rotate | Contracts | Quyết định chữ ký SCT nào được tin ở thời điểm kiểm chứng | Trước 01/11 |
| Dev/test base URL truy cập từ Flutter Web, CORS, response mẫu `submit` 201/200, `status`, `proof`, `recover` | Service | Tạo typed adapter và xử lý status/lỗi đúng API | Trước 01/11 |
| SCT ECDSA hợp lệ/sai, proof 1/2/3 lá, root, `dateKey`, tx hash và một batch đã neo trên Sepolia | Cả hai | Fixture Dart/TypeScript/Solidity và kịch bản demo không phải chờ cron | Trước 03/11 |
| Quy tắc quiet window 23:55 UTC, khi nào proof sẵn sàng, ý nghĩa `404` và recovery record pending ngày cũ | Service | Poll và hiển thị trạng thái đúng; xử lý tự phục hồi về sau | Trước 03/11 |

Hai điểm giao thức cần thành viên service xác nhận/sửa trong repo của họ: `submit` lần đầu có `sct.signer` nhưng nhánh idempotent hiện thiếu field này; recovery cho record `pending` ngày cũ chưa chuyển nó sang `targetDateKey`. App cần chịu được lỗi/khác biệt tạm thời và ghi đúng mức kiểm chứng, nhưng không tự thay đổi mã `service/`. Contract hỗ trợ ECDSA và Schnorr; service hiện ký ECDSA, đủ cho demo testnet. FROST2+ không nằm trên đường găng.

## 11. Rủi ro cần ghi đúng trong báo cáo

- Chưa có Mac nên Flutter iOS native và Core NFC không được kiểm chứng trong kỳ demo; Flutter Web trên iPhone chỉ là kiểm tra trình duyệt.
- Chữ ký A/B v1 là Ed25519 demo với khóa tạm thời, ký draft digest; danh tính đặt cạnh chữ ký và `PaymentReceipt` chưa được chữ ký đó ràng buộc mật mã. `evidenceHash` tự tính lại từ JSON không thay thế chữ ký trên toàn bộ metadata. Verifier phải ghi rõ phạm vi kiểm tra và không kết luận danh tính/chuyển tiền đã được chứng minh.
- Có SCT không đồng nghĩa đã được neo; `batched` do service báo cũng chưa đủ nếu app chưa kiểm proof và root trên đúng contract.
- Thiếu deployment Sepolia, fixture thật hoặc endpoint test là blocker cho demo on-chain, không phải lỗi riêng của Flutter app.
- Coordinator đang lưu in-memory; restart xóa phiên. Owner capability hiện chưa được lưu để khôi phục sau reload và link mời là bearer capability, cần chia sẻ qua kênh tin cậy.
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

## 12. Tiêu chí nghiệm thu demo testnet

1. Hai browser/profile hoàn tất cả mẫu đặt cọc và vay tiền; B chuyển cho A, A xác nhận thủ công sau khi kiểm app ngân hàng. Cả A/B ký cùng frozen digest; sửa draft làm chữ ký không hợp lệ.
2. PDF cuối được tạo một lần sau bước thanh toán; `keccak256` của byte PDF không đổi khi bổ sung SCT/proof vào JSON/ZIP. Import ZIP trên browser độc lập tính lại hash và kiểm hai chữ ký Ed25519 demo.
3. Request notary chỉ chứa `agreementHash` 32 byte, không có CCCD, họ tên, nội dung, tài khoản ngân hàng, capability hay khóa giải mã. Service lỗi không làm mất khả năng xuất ZIP local.
4. App tự kiểm EIP-712 SCT, gồm PDF hash, message, domain, chain/contract và signer; SCT sai bị từ chối. Xử lý cả submit mới và submit lặp.
5. App lấy `dateKey`/proof từ API, tự kiểm Merkle leaf/path/root và dùng RPC read-only xác nhận receipt/inclusion ở đúng CivilTrustRegistry Sepolia. Service status `pending`/`batched` chỉ là thông tin tham khảo; UI không tự suy diễn on-chain validity.
6. Màn verifier hiển thị riêng: kiểm cục bộ PDF/chữ ký mock, SCT, proof và RPC; thiếu dữ liệu/lỗi mạng hiện “chưa kiểm được”, sai dữ liệu hiện “không hợp lệ”. Có explorer link cho tx thật.
7. Có một hồ sơ mẫu trước anchor và một hồ sơ mẫu sau anchor để demo không phụ thuộc đúng thời điểm cron. Có test âm tính cho PDF/SCT/proof/chain bị sửa.
8. `flutter analyze`, `flutter test`, coordinator `npm test` và Flutter Web release build chạy đạt trên môi trường có công cụ; nếu công cụ chưa có, ghi rõ giới hạn và không tuyên bố pass. Không yêu cầu iOS native, NFC thật, FROST2+ hoặc mainnet để nghiệm thu demo.

**Chưa phải tiêu chí của demo:** ràng buộc mật mã identity/payment bằng signing envelope v2, lưu trữ coordinator production, khôi phục capability sau reload, media/cloud và iOS NFC. Các khoản này có thứ tự trong mục 8.5. Mọi màn hình/tài liệu demo phải ghi đúng giới hạn của v1.

## 13. Quyết định đã chốt và thông tin còn cần xác nhận

Đã chốt với người phụ trách app ngày 25/10/2026: ưu tiên demo/testnet trước, giữ hash của `agreement.pdf` với SCT/proof ở JSON đi kèm, hiện không có Mac và hạn demo/nộp bài khoảng 2–3 tuần. Flutter Web hai browser là đường nghiệm thu chính. Repo `app/` đã có commit local `1dc88a7`; push GitHub hiện bị từ chối quyền Write và sẽ thực hiện khi quyền repository được cấp. Việc push không chặn phát triển local, nhưng nhóm nên giải quyết sớm để chia sẻ code và tránh mất bản sao.

Thông tin còn cần chốt để khóa lịch thực tế:

1. Ngày/giờ nộp chính xác và số người có thể hỗ trợ riêng phần app; hiện kế hoạch giả định một người và hạn dự phòng 15/11.
2. Khi nào có deployment Sepolia và service test URL; ai cung cấp bộ fixture SCT/proof/transaction thật.
3. Demo chỉ trên hai browser máy tính hay bắt buộc một bên dùng iPhone Safari? Trường hợp iPhone cần HTTPS và coordinator/service truy cập được qua mạng, `localhost` trên máy Windows không đủ.
4. Nhóm có đồng ý dùng hồ sơ đã neo sẵn cho buổi demo không, do lịch anchor hàng ngày không trùng thời điểm thuyết trình.

## 14. Lịch sử quyết định và trạng thái MVP (10/10/2026)

Đây là ảnh chụp tiến độ ngày 10/10; kế hoạch và ưu tiên mới nhất xem mục 8–13. Các quyết định đã chốt ở thời điểm đó:

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

Thông tin còn cần từ nhóm contract/service được cập nhật chi tiết ở mục 10. Người phụ trách app đã chốt hạn demo khoảng 2–3 tuần từ 25/10 nhưng chưa cung cấp giờ nộp chính xác hoặc số người hỗ trợ app.

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
- Tại ngày 10/10, Google Drive, Secure Enclave/passkey, CCCD NFC thật và xác minh SCT/Merkle on-chain đầy đủ đều thuộc backlog. Theo quyết định ngày 25/10, xác minh SCT/Merkle/on-chain được kéo lên đường găng demo ở mục 8; các hạng mục còn lại vẫn sau demo.
