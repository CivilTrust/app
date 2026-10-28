# NFC G0/G1 — triển khai và nghiệm thu 27/10/2026

Phạm vi: chỉ `app/`. Không sửa contracts/service, không mua dịch vụ hoặc đưa CCCD thật vào repo. Chưa commit/push lượt triển khai này; các file kế hoạch tiếp tục để ngoài commit.

## 1. G0: đã kiểm kê, chưa qua cổng tích hợp thật

| Đầu vào | Bằng chứng | Kết luận |
| --- | --- | --- |
| Thiết bị | Người dùng xác nhận iPhone 12 / iOS 26.2, có CCCD cá nhân | Chưa test Core NFC vật lý |
| Máy build | Không có Mac; local Windows có Flutter 3.47.7 / Dart 3.13.5, không có Xcode | Cần macOS CI hoặc mượn Mac |
| Apple team | Người dùng xác nhận nhóm/trường chưa có Apple Developer Program/App Store Connect | Signing/TestFlight BLOCKED; chưa tạo tài khoản/chứng chỉ/app record |
| SDK/giao thức CCCD | Chưa có SDK, sample, AID, trust anchors/verifier | Xác thực thật BLOCKED; không đoán APDU/AID hoặc tự chọn vendor |
| GitHub | `gh repo view`: CivilTrust/app, WRITE, public, main | Có quyền source; không commit CCCD, khóa hoặc SDK riêng không có quyền phân phối |
| Actions | API đọc `repos/CivilTrust/app/actions/permissions` trả HTTP 403 | Chưa xác nhận chính sách/quota runner; quyền Write không chứng minh CI dùng được |
| iOS project | Có usage description, chưa có Team/entitlements/bridge thật | Không thêm cấu hình giả để che blocker |

Chạy `./nfc-preflight.ps1` để lấy inventory chỉ đọc. Script không kiểm từ xa tài khoản Apple và không đọc thẻ. Có file cấu hình không phải bằng chứng test thiết bị.

Đã chuẩn bị `.github/workflows/ios-preflight.yml`: chạy thủ công bằng `workflow_dispatch`, quyền `contents: read`, không signing secrets, không upload IPA/TestFlight. Chưa chạy workflow, chưa xác nhận compile Xcode/plugin hoặc quota. Build unsigned không cài lên iPhone được. Chỉ người có quyền mới chủ động dispatch sau khi kiểm chính sách/chi phí runner.

Đường G2 đề xuất: Windows → macOS CI/Xcode → ký hợp lệ → App Store Connect/TestFlight → iPhone. Phương án khác là mượn Mac và profile/capability phù hợp; không mặc định tài khoản Apple miễn phí đáp ứng mọi capability. [Flutter iOS setup](https://docs.flutter.dev/platform-integration/ios/setup), [GitHub signing trên macOS](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications).

## 2. G1: đã triển khai

### Adapter và dữ liệu

- A/B dùng `IdentityService` có thể inject; không khởi tạo mock trực tiếp trong thao tác đọc.
- `IDENTITY_MODE=mock|native-lab|verified-native`; giá trị lạ bị từ chối. Mặc định mock giữ demo; native lỗi không tự fallback mock. APP_ENV vẫn chỉ local/staging, chưa có production mode.
- Web/Windows từ chối native reader; iOS stub vẫn báo chưa cấu hình. Kể cả reader tự báo supported, luồng đọc thật vẫn gate ở G1 để không đưa PII vào pipeline cũ.
- Consent trước đọc, typed errors, chặn đọc đồng thời, cancel khi rời foreground/dispose, timeout và bỏ callback muộn. Sau cancel/timeout, lượt mới phải chờ underlying read kết thúc.
- Unknown reader error được làm sạch; cancel best-effort có timeout. Không đưa raw SDK exception vào UI.
- Mock signer từ chối native proof; PDF/ZIP exporter chặn danh tính không phải mock trước khi tải font/tạo PDF. Chưa có dữ liệu CCCD thật đi qua coordinator.

### Giao thức binding v2

- Evidence có version, typed assurance, context/challenge, verifier/policy, proof slot và holderCheck=unchecked. Unknown version/field v2 bị từ chối. V1 giữ serialization để không phá hash hồ sơ cũ.
- Ceremony ngẫu nhiên tạo trước A đọc; ceremony/protocol nằm trong immutable draft. A không cần coordinator session ID chưa tồn tại. B có challenge riêng trên cùng ceremony/draft.
- Challenge local 256-bit có hạn tối đa 15 phút. Envelope ký chứa domain/protocol, agreement/ceremony ID, role, draft digest, identity hash, public-key fingerprint, challenge, signedAt và algorithm.
- Verify kiểm signature, envelope, role, context/time; SessionValidator kiểm liên kết với draft thật. Algorithm/schema được allowlist, không chấp nhận mọi tên bắt đầu bằng Ed25519.
- Guard trong một demo signer chặn dùng lại challenge và ký đồng thời; có nút đọc lại/làm mới challenge khi hết hạn hoặc gửi phiên lỗi.
- **Giới hạn:** in-memory guard không chống replay toàn hệ thống, không ngăn tạo signer mới. Nonce/chữ ký client không chứng minh chip sống. G3 cần trusted issuer/verifier và kho consume challenge nếu policy yêu cầu dùng một lần.
- Verify lịch sử dùng signedAt đã được bảo vệ, không vô hiệu ZIP chỉ vì hiện tại quá 15 phút. Đây chưa phải timestamp từ bên tin cậy; không tuyên bố chống sửa đồng hồ client.
- ZIP có hai chữ ký v2 dùng civiltrust-evidence/2.0; hồ sơ cũ dùng /1.0 vẫn nhập được. SCT giữ PDF bytes/hash và schema. Đây là plumbing version/binding cho G1, chưa mở export bằng chứng CCCD thật của G3/G4.
- UI tách chữ ký demo hợp lệ khỏi xác thực CCCD/chủ thẻ; v1 ghi rõ identity chưa ràng buộc. Client cũ không kiểm được chữ ký v2: A/B phải cùng dùng bản mới.

### Native intake và diagnostics

- Paste raw code, join=code hoặc URL HTTP(S) có fragment; kiểm key 32 byte, ID/token bounded; từ chối owner, query/URL nguy hiểm. Không fetch host từ lời mời; lỗi không lộ capability.
- Native tạo mã paste thay vì link file://. Check staging native vẫn yêu cầu endpoint HTTPS nhưng không đòi origin của trình duyệt.
- Thông tin → **Kiểm tra NFC readiness** hiển thị mode, blocker và capability. Không đọc thẻ, gọi coordinator hay upload dữ liệu. iPhone/iOS hiển thị là baseline do người dùng cung cấp, không phải device detection.

## 3. Kết quả kiểm thử

| Phép kiểm | Kết quả |
| --- | --- |
| flutter analyze --no-pub | Đạt, không có issue |
| flutter test --no-pub với LIVE_COORDINATOR_URL loopback | **120/120 đạt**, không skip |
| Coordinator npm test | **7/7 đạt** sau khi cho phép localhost ngoài sandbox |
| Flutter Web staging release build | Đạt; APP_ENV=staging, COORDINATOR_URL=/coordinator, NOTARY_ENABLED=false |
| nfc-preflight.ps1 | Chạy đạt; verdict G0 external gates BLOCKED |
| Git diff whitespace check | Đạt |
| iOS unsigned/signed build, TestFlight, NFC vật lý | Chưa chạy, không được tính pass |

Các test mới kiểm consent/expiry/mode/no fallback/default verifier, cancel/timeout/dispose/late callback/concurrency; tráo identity B/source/assurance/role/draft/key/signature/time/ceremony/challenge/domain/version; replay sang agreement khác; ZIP v2/v1, chặn PII export và PDF hash bất biến khi thêm SCT; invite paste và widget 375×812. Bộ hồi quy Web/VietQR cũ cũng chạy.

Hai ca live HTTP trong lượt cuối gồm ca coordinator baseline và ca chữ ký v2 mới: tạo A, B đọc bằng participant capability, cập nhật encrypted session, A tự verify rồi finalize. Server chỉ bind loopback, dùng dữ liệu tổng hợp; không phải test hai thiết bị/iPhone.

Test PDF dùng Helvetica fixture có cảnh báo thiếu glyph tiếng Việt như baseline; đây là test byte/hash/ZIP, **không phải** nghiệm thu bố cục/font PDF thực. Bản thực dùng NotoSans như trước. Không dùng kết quả unit/widget thay nghiệm thu NFC thật.

## 4. Mở G2/G3 và bàn giao

1. Bố trí Apple team, macOS build và quyền/quota Actions; không gửi secrets trong chat. Chưa phát sinh mua dịch vụ.
2. Xin SDK/sample iOS đúng loại CCCD, hỗ trợ iOS 26.2; AID, phương thức access, trust anchors, phạm vi kiểm data/chip/holder, license và quyền dùng CCCD cá nhân. Không coi plugin đọc tag chung là CCCD authentication.
3. Nếu cần server verifier: API riêng với challenge, signed assertion/issuer key ID, policy/trust version, role/ceremony/key binding, verifiedAt/expiry, replay và privacy/retention. Chưa có API đó; app không giữ vendor server secret.
4. Contracts/service vẫn nhận PDF hash và phát SCT/proof như trước; không nhận raw CCCD/chip/ảnh. SCT/Merkle không tự xác nhận danh tính. Coordinator chuyển ciphertext, không phải identity verifier.
5. G2/G3 mới làm bridge Core NFC, runtime readingAvailable, entitlement/AID thật và SDK; G4 mới mở export thật sau chốt consent/privacy. Face ID không tự chứng minh chủ CCCD; chưa có liveness/đối chiếu chân dung.
