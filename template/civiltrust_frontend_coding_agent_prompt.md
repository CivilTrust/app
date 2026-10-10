# PROMPT CHO CODING AGENT — CIVILTRUST APP (FLUTTER WEB + IOS)

## 0. Vai trò, phạm vi và nguyên tắc làm việc

Bạn là **Senior Flutter Engineer + Product/UX Engineer + QA Engineer** làm trực tiếp trong repository CivilTrust. Mục tiêu là cải thiện ứng dụng Flutter đang chạy thật, không dựng mockup tĩnh và không viết lại hệ thống từ đầu.

Phạm vi được phép sửa:

- `app/lib/`, `app/test/`, `app/web/`, `app/ios/`, `app/coordinator/` và tài liệu/cấu hình thuộc `app/` khi cần.
- Không sửa bất kỳ file nào trong `contracts/` hoặc `service/`. Hai thư mục đó thuộc thành viên khác. Chỉ đọc mã, ABI và tài liệu để tích hợp đúng API hiện hữu.
- Không đổi protocol ký, canonical JSON, hash, định dạng evidence hoặc artifact nếu chưa có migration có version và test tương thích.

Trước khi code:

1. Đọc `app/README.md`, `app/plan.md`, `app/desv2.md`, prompt này, models, coordinator, crypto, signing, artifact, notary adapter và tests.
2. Kiểm chứng bằng code: phân loại **đã chạy thật**, **adapter/seam đã có**, **chưa có**. Không coi tài liệu thiết kế là implementation.
3. Kiểm tra `git status` của `contracts/` và `service/` trước/sau công việc để chứng minh không chỉnh sửa hai phần đó.
4. Lập kế hoạch ngắn rồi triển khai theo ưu tiên; không dừng ở bản kế hoạch.
5. Sau mỗi nhóm thay đổi, chạy formatter, analyzer, unit/widget/integration test phù hợp và web release build nếu môi trường cho phép.
6. Máy phát triển là Windows, không có macOS. Được kiểm thử Flutter Web và shared Dart; không tuyên bố đã build/test iOS nếu không có Xcode và iPhone vật lý.

## 1. Sự thật hiện tại của `app/` phải được bảo toàn

### 1.1. Những gì đã có thật

- Flutter Material 3 cho Web/iOS, điều hướng chính: **Tạo hợp đồng**, **Tham gia ký**, **Kiểm chứng**, **Thông tin**.
- Hai mẫu nghiệp vụ:
  - `deposit-v1`: **Hợp đồng đặt cọc**, tham chiếu cấu trúc từ `template/Hop-dong-thue-nha-lam-tam-tru.docx` nhưng đã được khái quát cho thuê trọ, mua bán đồ cũ và giao dịch tài sản.
  - `loan-v1`: **Hợp đồng vay tiền**, tham chiếu `template/hop-dong-vay-tien_1009151044_2311232834.doc`.
- `IdentityReader` là abstraction; `MockIdentityReader` trả dữ liệu mẫu có cấu trúc. NFC CCCD thật chưa được triển khai.
- `MockPartySigner` tạo chữ ký Ed25519 kiểm chứng được cho demo; chưa phải chữ ký Secure Enclave, Face ID hay chữ ký số được chứng nhận.
- A khóa `AgreementDraft`, ký canonical digest; B mở capability invite trên thiết bị/browser khác và ký đúng digest đó.
- Coordinator riêng trong `app/coordinator/`: session mã hóa AES-256-GCM phía client, bearer capability, TTL 24 giờ, optimistic locking, lưu RAM.
- B đánh dấu đã chuyển tiền; A phải kiểm tra app ngân hàng thật rồi xác nhận đã nhận.
- Sau xác nhận, app tạo `agreement.pdf`, tính Keccak-256 trên đúng bytes PDF, tạo `evidence.civiltrust.json`, gọi Notary Service và xuất ZIP.
- ZIP importer kiểm hash PDF, evidence canonical và chữ ký mock A/B ở local.
- `NotaryClient` hiện có `submit(hash)` và `status(hash)`; client chưa hoàn thiện SCT EIP-712 self-verification, proof polling, Merkle verification và RPC verification.

### 1.2. Những gì chưa có và không được giả vờ đã có

- NFC CCCD thật/C06, chip authentication thật, Core NFC entitlement và APDU production.
- Secure Enclave/passkey/WebAuthn production signing.
- Lưu nháp bền vững, danh sách “Hợp đồng của tôi”, router/deep-link hoàn chỉnh và khôi phục sau reload.
- Coordinator production database, revoke/cancel session, negotiation/yêu cầu sửa, đồng bộ final ZIP cho B.
- Bank API xác nhận giao dịch; VietQR chỉ là hướng dẫn chuyển khoản.
- Google Drive OAuth/upload.
- Tải/kiểm Merkle proof và xác minh on-chain đầy đủ trong app.
- Kết luận pháp lý như “đã công chứng”, “hợp pháp 100%” hoặc “CCCD đã xác thực”.

Mọi UI phải phản ánh đúng các giới hạn trên. Không tạo CTA giả, dấu tích xanh giả hoặc success state chỉ vì API được mô tả trong tài liệu.

## 2. Luồng nghiệp vụ chuẩn của MVP

Luồng chuẩn, không tự ý đảo thứ tự:

1. A chọn **Hợp đồng đặt cọc** hoặc **Hợp đồng vay tiền**.
2. A đọc CCCD mock và xem lại dữ liệu cá nhân được tự điền.
3. A nhập trường nghiệp vụ, thông tin nhận tiền và điều khoản.
4. A xem toàn văn, đồng ý rõ ràng, khóa nội dung và ký digest.
5. App tạo capability invite; A gửi link riêng tư cho B.
6. B mở link, xem đúng nội dung A đã khóa, đọc CCCD mock, đồng ý và ký cùng digest.
7. App hiển thị VietQR; B chuyển tiền bằng app ngân hàng và chỉ đánh dấu **“Tôi đã thực hiện chuyển khoản”**.
8. A làm mới trạng thái, tự kiểm tra tài khoản ngân hàng, rồi xác nhận đã nhận đủ tiền.
9. App tạo PDF cuối bất biến, hash đúng bytes, submit duy nhất `agreementHash` tới Notary Service và nhận SCT nếu service sẵn sàng.
10. A tải ZIP; người dùng có thể import ZIP để kiểm chứng offline.

### 2.1. Vai trò và chiều tiền trong MVP

Đây là quyết định bắt buộc để khớp với luồng “B chuyển tiền — A xác nhận”:

- **Đặt cọc:** A là bên nhận cọc/chủ tài sản/người bán; B là bên đặt cọc; B chuyển tiền cọc cho A.
- **Vay tiền:** A là bên vay/nhận giải ngân; B là bên cho vay; B chuyển tiền vay cho A.
- A là người khởi tạo và người nhận tiền trong MVP hiện tại.

Không mô tả “A cho B vay” trong khi VietQR lại chuyển về tài khoản A. Nếu sau này hỗ trợ vai trò linh hoạt, model phải có các trường rõ ràng như `initiatorRole`, `payerRole`, `payeeRole`, `paymentConfirmerRole`; migration phải giữ đọc được evidence cũ.

### 2.2. Phạm vi của chữ ký và PDF cuối

- A/B ký `frozenDigest` của `AgreementDraft` trước thanh toán.
- `PaymentReceipt` được A xác nhận sau chữ ký B; hiện chưa có chữ ký mật mã riêng cho receipt này.
- PDF cuối được dựng sau thanh toán và chứa nội dung đã ký cùng metadata chữ ký/thanh toán.
- Vì vậy UI/evidence phải nói chính xác: **A/B đã ký nội dung thỏa thuận có digest X; A đã ghi nhận nhận tiền; PDF cuối đóng gói các bằng chứng này**.
- Không tuyên bố chữ ký A/B trực tiếp ký mọi byte của PDF cuối hoặc B đã ký xác nhận thanh toán.
- SCT của Notary Service ký cam kết đối với hash PDF; SCT không thay thế chữ ký A/B và không phải công chứng.

### 2.3. Nợ kỹ thuật bảo mật phải mô tả trung thực

- `MockPartySigner` hiện chỉ ký `frozenDigest`; object `identity` được đặt cạnh chữ ký nhưng chưa nằm trong message được ký. Vì vậy không được mô tả đây là chữ ký đã ràng buộc mật mã với CCCD.
- Khóa Ed25519 mock được sinh tạm thời ngay lúc ký, chưa có chứng thư hoặc chuỗi tin cậy nối public key với con người ngoài đời.
- Phiên bản production nên có signing envelope được domain-separate và version hóa, tối thiểu ràng buộc: `agreementDigest`, `identityCommitment`, `role`, `session/revision id` và protocol version. Việc này là migration protocol, phải đọc được evidence v1 và có test vector; không được đổi âm thầm.
- `EvidenceManifest` đang ghi schema `civiltrust-evidence/1.0`; parser hiện chưa enforce/migrate schema. Trước khi thêm field NFC/proof/attachment cần bổ sung schema validation và fixtures tương thích.
- Cách tính `evidenceHash` hiện phụ thuộc phép chuyển state `paymentConfirmed` ↔ `committedPendingAnchor` trong artifact pipeline. Không đổi state/hash convention này nếu chưa có evidence v2 và migration rõ ràng.

## 3. Hai mẫu hợp đồng và dữ liệu cần thu thập

### 3.1. Hợp đồng đặt cọc

Các trường tối thiểu hiện có:

- Loại giao dịch.
- Mô tả tài sản/đối tượng đặt cọc.
- Địa chỉ hoặc nơi giao nhận.
- Tổng giá trị giao dịch.
- Số tiền đặt cọc.
- Hạn ký hợp đồng chính hoặc giao nhận.
- Xử lý vi phạm đặt cọc.
- Thỏa thuận bổ sung.

Không gọi đây là “Hợp đồng thuê nhà” nếu nội dung chỉ là đặt cọc. Có thể thêm preset “Đặt cọc thuê trọ”, “Đặt cọc mua đồ cũ”, “Khác”, nhưng mọi preset phải hiển thị toàn bộ điều khoản trước khi ký và không tự tạo khẳng định pháp lý tuyệt đối.

### 3.2. Hợp đồng vay tiền

Các trường tối thiểu hiện có:

- Mục đích vay của A.
- Số tiền B cho A vay.
- Ngày B giải ngân cho A.
- Ngày A phải hoàn trả.
- Lãi suất `%/năm`.
- Phương thức trả nợ.
- Xử lý chậm trả.
- Thỏa thuận bổ sung.

Validation phải chặn số tiền không hợp lệ, ngày đến hạn trước ngày giải ngân và lãi suất sai định dạng/ngoài giới hạn được sản phẩm lựa chọn. Không tự đặt mức lãi/phạt là “đúng pháp luật” nếu chưa được rà soát pháp lý.

### 3.3. Dữ liệu định danh

Schema hiện có gồm:

- `source`, `displayName`, `documentNumberMasked`, `readAt`.
- `chipAuthentication`, `identityCommitment`.
- `attributes`: họ tên, ngày sinh, số CCCD, ngày/nơi cấp, thường trú, nơi ở hiện tại.

Trong UI production-facing, ưu tiên số CCCD đã che; chỉ hiển thị số đầy đủ ở màn review/PDF khi thật sự cần và đã có consent. Không đưa PII vào URL, logs, analytics, crash report hoặc Notary Service.

## 4. Kiến trúc sẵn sàng cho NFC thật

Không gắn logic hợp đồng trực tiếp với `MockIdentityReader`. Mọi identity flow phải gọi qua `IdentityReader` hoặc một controller/service phía trên abstraction đó.

Chuẩn bị cho adapter NFC tương lai bằng các nguyên tắc:

- Phân biệt `mock`, `unsupported`, `cancelled`, `readFailed`, `read`, `chipAuthenticated`, `trustValidated`; không rút gọn tất cả thành boolean `verified`.
- Hiển thị consent riêng trước khi đọc CCCD; consent định danh không được gộp với checkbox đồng ý hợp đồng.
- Cho phép retry/cancel; không mất dữ liệu form khi phiên NFC thất bại.
- Chuẩn hóa dữ liệu trước khi tạo `identityCommitment`; version hóa thuật toán commitment và schema nếu thay đổi.
- Adapter iOS tương lai phải xử lý Core NFC/ISO 7816/APDU, entitlement, trust anchors và privacy review ở native layer. Không đưa APDU vào widget.
- Không lưu ảnh chip/raw DG/APDU transcript trong agreement nếu policy chưa yêu cầu. Nếu cần lưu, phải mã hóa, consent rõ và hash/manifest có version.
- `IdentityEvidence.source == mock` hoặc `chipAuthentication == mock` phải hiện nhãn: **“Dữ liệu mô phỏng — chưa xác thực chip CCCD”**.
- Chỉ hiện “Đã xác thực chip” khi adapter thật trả bằng chứng và trust validation đã chạy thành công.

Thiết kế model mới phải backward-compatible với `IdentityEvidence.fromJson()` hiện tại hoặc có `schemaVersion` cùng migration/test vector.

## 5. Tích hợp an toàn với coordinator, service và contract

### 5.1. Coordinator thuộc `app/`

- Reuse `RemoteSessionRepository`, `SessionCipher`, `SessionCapabilities` và optimistic version.
- Capability nằm trong URL fragment để không tự động gửi tới web server; không chuyển sang query parameter.
- Không log fragment, token hoặc encryption key.
- Xử lý rõ invalid/expired/conflict/decryption error và cho phép retry hợp lý.
- Coordinator chỉ lưu encrypted envelope; production persistence sau này phải giữ API/envelope contract hoặc có migration.

### 5.2. Notary Service thuộc `service/` — chỉ tích hợp, không sửa

- Submit qua `POST /api/v1/agreements/submit` với duy nhất `agreementHash` dạng 32-byte hex.
- Đọc status qua endpoint hiện có mà `NotaryClient.status()` đang dùng.
- Không gửi PDF, terms, họ tên, CCCD, tài khoản ngân hàng, capability hay encryption key.
- Chấp nhận response theo adapter hiện tại; lỗi service không được làm mất PDF/evidence/ZIP local.
- Retry phải idempotent và có giới hạn; không submit trong vòng lặp vô hạn.
- Trước khi thêm proof/recover/sync, đọc `service/docs/api.md` và tạo method ở client adapter; không sửa server để tiện frontend.

### 5.3. Smart contract thuộc `contracts/` — chỉ đọc/verify

- App không tự broadcast `anchorDailyRoot`; đó là trách nhiệm service/relayer.
- Tương lai app có thể dùng RPC read-only để gọi `verifyReceipt` và `verifyAgreement` theo ABI đã deploy.
- Chỉ bật on-chain verification khi có chain ID, contract address, proof và ABI/version khớp.
- Zero address hoặc thiếu deployment phải hiện “Chưa cấu hình”, không hiện “Đã neo”.
- Trạng thái `submitted/pending` không được ánh xạ thành `batched` nếu chưa có proof/on-chain confirmation.

## 6. Artifact, evidence và tính tương thích

- `agreement.pdf` là artifact bất biến sau khi tạo; hash Keccak-256 tính trên bytes cuối cùng.
- `evidence.civiltrust.json` là sidecar chứa session, document hash, evidence hash, SCT/proof khi có.
- SCT/proof được thêm vào sidecar/ZIP; không render lại PDF sau khi hash.
- ZIP tối thiểu phải có đúng `agreement.pdf` và `evidence.civiltrust.json`.
- Importer phải từ chối ZIP thiếu file, hỏng central directory, PDF hash sai, evidence bị sửa hoặc chữ ký sai.
- Khi mở rộng attachments/QR, mỗi file phải có digest trong manifest và schema version; không chỉ nhét file vào ZIP rồi gọi là evidence.
- Mọi thay đổi canonicalization, tên field hoặc enum state phải có backward-compatibility tests với fixture phiên bản cũ.

## 7. UX/UI cần cải thiện trên nền hiện tại

Phong cách: tin cậy, tối giản, hiện đại, Vietnamese-first, mobile-first. Không biến app thành dashboard blockchain.

### 7.1. Luồng A

- Chọn mẫu bằng hai card rõ mục đích và chiều tiền.
- Identity step hiển thị consent và nhãn mock nổi bật.
- Form chia nhóm nhỏ; label luôn nhìn thấy; tiền định dạng VNĐ nhưng model lưu integer.
- Date picker/validator thay cho text tự do khi phù hợp.
- Review hiển thị toàn văn, vai trò A/B, số tiền, tài khoản nhận và cảnh báo mock.
- Trước khi khóa, dialog giải thích nội dung không thể sửa dưới chữ ký cũ.
- Sau khi tạo session, hiển thị link riêng tư, thời hạn hết hạn từ coordinator, copy/share và trạng thái chờ B.
- Khi B báo chuyển, CTA phải là “Tôi đã kiểm tra và xác nhận nhận đủ … VNĐ”, kèm cảnh báo kiểm tra ngân hàng thật.
- Result phân biệt: PDF/ZIP đã tạo, SCT đã nhận nhưng chưa self-verify, đang chờ batch, đã neo có proof.

### 7.2. Luồng B

- Mở invite tự động từ fragment hoặc cho phép dán link/mã.
- Hiển thị toàn bộ nội dung đã khóa trước identity/sign.
- Tách checkbox “đã đọc và đồng ý” khỏi consent CCCD.
- Chỉ ký sau khi `SessionValidator` xác nhận digest và chữ ký A.
- Sau ký, hiển thị đúng người nhận, ngân hàng, số tiền, nội dung và VietQR.
- Nút chỉ ghi “Tôi đã thực hiện chuyển khoản”; không tuyên bố ngân hàng đã xác nhận.
- Sau khi báo chuyển, giải thích phải chờ A kiểm tra và finalization.

### 7.3. Verifier

Hiển thị từng kiểm tra độc lập:

- PDF hash: valid/invalid.
- Evidence canonical hash: valid/invalid.
- Chữ ký A: valid/invalid/not checked.
- Chữ ký B: valid/invalid/not checked.
- Xác nhận nhận tiền: present/absent; không gọi là bank-verified.
- SCT: received/not available/verified/invalid.
- Merkle proof và on-chain: pending/not configured/verified/invalid.

Không dùng một dấu tích tổng hợp để suy ra “hợp đồng hợp pháp” hoặc “đã công chứng”.

### 7.4. Design system và accessibility

- Dùng Material 3/theme/tokens dùng chung, spacing 4/8, touch target tối thiểu 44–48 px.
- Mobile một cột; desktop max-width hợp lý, không kéo form hết viewport.
- Loading/error/empty/retry rõ ràng; spinner không chạy vô hạn.
- Không phân biệt trạng thái chỉ bằng màu; thêm icon/text/semantic labels.
- Hỗ trợ keyboard, focus, text scaling và tránh overflow ở 375/768/1280 px.
- Không hardcode PII/tài khoản thật trong production. Mock data phải ở adapter/dev fixture.

## 8. Kiến trúc code mong muốn

Ưu tiên cải tiến tăng dần, không rewrite:

- Giữ models/protocol hiện tại; tách widget lớn thành section/component khi có giá trị test/reuse.
- Tách mutable form state khỏi immutable `AgreementDraft` đã khóa.
- Tách validation/domain formatting khỏi widget.
- Không thêm Riverpod/BLoC/Provider nếu state hiện tại chưa cần; nếu bổ sung persistence/router, chọn một hướng tối thiểu và migration rõ.
- Không để widget tự tạo trực tiếp adapter production; inject interface khi cần test hoặc chọn mock/real theo config.
- Không lưu raw PII trong global debug state.
- Nếu thêm local persistence, mã hóa dữ liệu nhạy cảm, có nút xóa và không lưu capability ngoài nhu cầu khôi phục đã được giải thích cho người dùng.

Các abstraction cần bảo toàn hoặc mở rộng có version:

- `IdentityReader`
- `PartySigner`
- `RemoteSessionRepository`
- `NotaryClient`
- `ArtifactService`
- `SessionValidator`
- `AgreementDraft` / `SigningSession` / `EvidenceManifest`

## 9. Thứ tự triển khai hợp lý từ trạng thái hiện tại

### Phase A — Correctness P0

1. Sửa mọi mâu thuẫn vai trò/chiều tiền giữa deposit, loan, VietQR và PDF.
2. Bổ sung validation ngày, tiền, lãi suất, BIN/số tài khoản và error message cụ thể.
3. Gắn nhãn mock identity/mock signature ở đúng bước.
4. Làm rõ phạm vi chữ ký draft so với payment receipt/PDF final.
5. Thêm regression tests cho hai template và state transitions.

### Phase B — UX/responsive P0

1. Tách wizard thành các bước nhỏ có Back/Next mà không mất dữ liệu.
2. Cải thiện mobile/desktop, accessibility, loading/error/retry.
3. Hiển thị expiry/conflict/invalid invite thân thiện.
4. Kiểm tra toàn bộ luồng bằng hai browser profile.

### Phase C — Persistence và quản lý phiên P1

1. Draft autosave/local repository có cảnh báo privacy.
2. “Hợp đồng của tôi” với trạng thái thực, không suy đoán.
3. Khôi phục phiên an toàn sau reload; không log capability.
4. Cơ chế hủy/revision chỉ khi coordinator thực sự hỗ trợ.

### Phase D — Service/contract verification P1

1. Parse SCT typed, self-verify theo EIP-712/format thực tế.
2. Poll status có backoff và giới hạn.
3. Tải proof theo API thật, kiểm Merkle local và gọi RPC read-only.
4. Chỉ hiển thị `batched/verified on-chain` sau phép kiểm thật.

### Phase E — NFC/signing production P2

1. Implement `IosIdentityReader` trên macOS với iPhone vật lý và protocol CCCD được phê duyệt.
2. Version hóa identity evidence/commitment và thêm fixtures tương thích.
3. Thay mock signer bằng Keychain/Secure Enclave/passkey theo threat model đã chốt.
4. Giữ mock adapter cho test/demo, không trộn nhãn production.

Google Drive và media attachment chỉ làm sau khi evidence manifest, consent, encryption và OAuth lifecycle đã được thiết kế/test.

## 10. Acceptance criteria

1. Người dùng chọn được đúng hai mẫu: đặt cọc và vay tiền.
2. Luồng cả hai mẫu đều thống nhất B chuyển tiền cho A; hợp đồng vay ghi B cho A vay.
3. CCCD mock luôn có nhãn mô phỏng và không bị mô tả là chip verified.
4. A/B ký cùng một frozen digest; sửa draft làm digest đổi và buộc ký lại.
5. B không thể ký nếu chữ ký A/digest không hợp lệ.
6. Invite invalid/expired/conflict có lỗi hiểu được và không làm lộ capability.
7. VietQR lấy đúng BIN, tài khoản A, số tiền theo mẫu và nội dung giao dịch.
8. B báo chuyển không tự tạo `PaymentReceipt`.
9. Chỉ A xác nhận sau khi kiểm tra ngân hàng mới chuyển sang `paymentConfirmed`.
10. PDF chỉ tạo sau payment confirmation; bytes không đổi sau hash.
11. Notary request chỉ chứa `agreementHash`; service lỗi vẫn tải được ZIP không SCT.
12. Import ZIP phát hiện PDF/evidence bị sửa và không fake SCT/on-chain validity.
13. Không có file thay đổi trong `contracts/` và `service/`.
14. `dart format`, `flutter analyze`, `flutter test`, coordinator tests pass.
15. Flutter Web release build thành công; iOS được ghi rõ là chưa kiểm chứng trên Windows.
16. UI không overflow ở khoảng 375, 768 và 1280 px; thao tác keyboard/touch dùng được.

## 11. Báo cáo cuối của coding agent

Trả lời bằng tiếng Việt, gồm:

1. Repo audit và khác biệt giữa tài liệu với code thực tế.
2. Quyết định nghiệp vụ/kiến trúc, đặc biệt vai trò, chiều tiền và phạm vi chữ ký.
3. Những gì đã triển khai và file đã thay đổi.
4. Tests/build đã chạy cùng kết quả; phần chưa thể chạy phải nói rõ.
5. Xác nhận `contracts/` và `service/` không bị sửa.
6. Hướng dẫn demo hai browser/device.
7. Tính năng chưa có thật và rủi ro/TODO ưu tiên tiếp theo.

**Definition of Done:** frontend chạy thật theo protocol hiện có; hai mẫu hợp đồng có nội dung và chiều tiền nhất quán; người dùng A/B đi hết luồng từ identity mock tới ZIP; trạng thái evidence trung thực; abstraction đủ sạch để thay NFC/signing và bổ sung service/contract verification sau này; không chỉnh sửa `contracts/` hoặc `service/`.
