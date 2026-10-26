# Kế hoạch app tuần 2 — 02/11 đến 08/11/2026

**Quyết định ưu tiên:** (P0) luồng A/B dùng được trên laptop Windows và iPhone Safari qua HTTPS; VietQR rõ chiều tiền và dùng được khi B chỉ có một điện thoại. (P0) kiểm proof Merkle và RPC read-only ở mức tối thiểu để demo giá trị kiểm chứng, tùy đầu vào từ service/contracts. (P1) chuẩn bị giao diện, API và dữ liệu an toàn cho NFC; **không đặt đọc CCCD thật làm điều kiện qua tuần 2**. Người phụ trách app chỉ sửa `app/`.

Người dùng hiện có iPhone và CCCD, **không có Mac**; nhóm có tài khoản nhận tiền và app ngân hàng để xem trước VietQR mà không chuyển tiền thật. Theo [Flutter](https://docs.flutter.dev/platform-integration), build iOS native chỉ thực hiện trên macOS; Flutter Web có thể build trên Windows. [Apple Core NFC](https://developer.apple.com/documentation/corenfc/) là API của app iOS trên thiết bị hỗ trợ NFC. Vì vậy iPhone Safari kiểm được Web/QR/ZIP và luồng A/B, nhưng không kiểm được `IosIdentityReader` hoặc quét chip CCCD của app native. Đây là suy luận từ hai nền tảng và đúng với cấu trúc app hiện tại.

## 1. Baseline và khoảng trống thực tế

| Mảng | Đã có trong `app/` | Còn thiếu để dùng trên thiết bị thật |
| --- | --- | --- |
| Luồng A/B | Mẫu đặt cọc/vay, coordinator mã hóa, link capability, ký mock, PDF/ZIP, nhập ZIP | HTTPS có chứng chỉ được iPhone tin cậy, truy cập được từ cả hai thiết bị cho Web/coordinator/notary; thử link, refresh, download/import và lỗi trên Safari iPhone |
| VietQR | `VietQrService` tự tạo payload TLV/CRC; A và B hiển thị QR đúng số tiền draft; A nhập BIN/tài khoản | Test giải mã độc lập và quét bằng app ngân hàng; xác nhận tên người nhận/số tiền; cách B lưu/chia sẻ QR hoặc copy thông tin khi chỉ dùng một iPhone; thông báo chuyển tiền vẫn là tự khai |
| NFC | `IdentityReader` interface, `MockIdentityReader`; `IosIdentityReader` luôn `isSupported=false`; `Info.plist` có `NFCReaderUsageDescription` | Chưa chọn reader bằng DI/feature flag; chưa có Core NFC bridge, entitlement/AID, APDU, SDK/giao thức CCCD, xác thực chip, Mac/Xcode, native device build |
| Kiểm chứng | SCT EIP-712 local, hash PDF, chữ ký mock A/B, status hiển thị trung thực | Proof client, Merkle local, RPC read-only, ZIP cập nhật sau anchor; registry Sepolia hiện chưa có address trong deployment file |

`IdentityEvidence.attributes` hiện có thể chứa **số CCCD đầy đủ** trong luồng mock. Nếu đưa dữ liệu đọc từ CCCD thật vào object này, nó sẽ đi vào phiên mã hóa, PDF và ZIP. Trước NFC thật phải chốt trường nào được giữ, đối tượng được xem và thời hạn lưu; không đổ raw APDU, ảnh, chứng thư hoặc số CCCD đầy đủ vào log/fixture. Không gọi `chipAuthentication=verified` nếu chưa kiểm chứng thư và trust anchor.

## 2. Định nghĩa thành công cuối tuần

1. Trên laptop Windows và iPhone Safari cùng mở được **một bản Web HTTPS**; URL coordinator/notary cũng dùng HTTPS, có CORS phù hợp. A/B hoàn tất cả hai hướng vai trò (đặt cọc, vay) với danh tính **mock**, link invite mở trên iPhone, ZIP tải/nhập được ít nhất trên một trình duyệt độc lập. Nếu Safari không lưu/nhập ZIP ổn định, ghi đúng bước lỗi và có đường xuất/nhập qua laptop để demo.
2. VietQR có test payload/CRC bằng bộ giải mã độc lập; số tiền, BIN/tài khoản, nội dung chuyển khoản nhất quán giữa A và B. Quét QR bằng ít nhất một app ngân hàng ở màn **xem trước người nhận/số tiền**, không thực hiện chuyển tiền thật cho test. B dùng một iPhone có thể lưu/chia sẻ QR hoặc copy chi tiết để mở trong app ngân hàng; nếu ngân hàng không nhận ảnh QR, hiển thị rõ phương án nhập tay.
3. Nếu service/contracts bàn giao fixture đúng hạn, app lấy proof, kiểm Merkle local rồi gọi RPC read-only trên đúng chain/registry. ZIP sau anchor giữ byte PDF/hash bất biến. Nếu chưa có endpoint/deployment thật, adapter và test fixture vẫn phải hoàn thành; UI giữ “chưa kiểm on-chain”, **không** dùng status `batched` làm bằng chứng.
4. NFC có quyết định kỹ thuật được ghi: đường native, ranh giới PII, trạng thái mock/không hỗ trợ/đang đọc/lỗi/đã xác thực và checklist Mac/SDK. Không dùng CCCD thật trong demo Web; không hiển thị “đã xác thực chip” từ mock.

## 3. Lịch ngày theo đường găng một người làm app

| Ngày | Công việc trong `app/` | Đầu ra kiểm được | Phụ thuộc/điểm dừng |
| --- | --- | --- | --- |
| **Thứ hai 02/11** | Khóa baseline `ddfef3e` + biên bản `453399c`; lập ma trận Windows Chrome/Edge và iPhone Safari (model/iOS thực tế); cấu hình staging HTTPS truy cập được từ cả hai thiết bị cho Web/coordinator/notary bằng `--dart-define`; kiểm CORS, mixed content, link `#join=` và log không lộ capability. Chỉ dùng dữ liệu mock trên staging. Kiểm ngay Mac/SDK/AID/trust anchor cho NFC. | Một URL staging mở được từ cả hai thiết bị; health coordinator qua HTTPS; checklist NFC có trạng thái `blocked`/`ready` cụ thể. | Không tự đưa service/contracts lên production; cần URL/CORS từ thành viên phụ trách. Nếu thiếu, chạy Web+coordinator staging và giữ notary offline. |
| **Thứ ba 03/11** | Rà payload `VietQrService`: parse ngược TLV, kiểm CRC, giới hạn độ dài trường/amount/purpose, test golden vector đối chiếu trình đọc độc lập; không chỉ kiểm chuỗi có BIN/amount. Bổ sung UX nhận tiền: hiện tên A, BIN, tài khoản, số tiền, nội dung; nút copy từng trường và lưu/chia sẻ ảnh QR cho người chỉ có một iPhone; giữ nhãn “B báo chuyển” và “A tự xác nhận”. | Test parser/CRC và UI; quét màn xem trước trên ít nhất một app ngân hàng, chụp kết quả đã che tài khoản; QR A/B khớp. | [NAPAS](https://napas.com.vn/dich-vu-chuyen-tien-nhanh-napas-247) mô tả VietQR là chuyển tiền qua app ngân hàng theo tiêu chuẩn EMVCo; app không được suy ra tiền đã đến chỉ vì QR quét được. Không nhúng credential/API NAPAS trong Web. |
| **Thứ tư 04/11** | Chạy A trên Windows ↔ B trên iPhone và đảo vai; thử link mời mở Safari, bàn phím/date picker, QR một điện thoại, màn 375/768/1280 px, refresh, ZIP download/import, service tắt, coordinator restart, CORS. Sửa đúng lỗi được tái hiện. | Biên bản có model iPhone/iOS, Safari, URL build/commit, từng ca pass/fail, ảnh lỗi đã che capability/PII. | Không có Mac nên không có Safari Web Inspector native; dùng log server tối thiểu, DevTools phía Windows và quan sát màn iPhone. |
| **Thứ năm 05/11** | Tách identity reader chọn theo nền tảng/cấu hình, trình bày rõ mock vs NFC chưa sẵn sàng; thiết kế interface kết quả NFC và các lỗi cancel/timeout/permission/tag/verification. Song song tạo typed proof/status client từ schema service, kiểm `dateKey`, hash, root, proof, txHash; test 200/pending/404/bad JSON/offline. | Mock Web vẫn chạy; không có đường UI nào báo chip verified. Proof client có test fixture, không poll vô hạn. | Chưa có Mac/SDK thì **dừng ở interface và UX**; không viết APDU bằng cách đoán giao thức CCCD. |
| **Thứ sáu 06/11** | Merkle leaf/path local khớp fixture service/contract, sau đó RPC `eth_chainId` + `eth_call` read-only `verifyReceipt`/`verifyAgreement` đúng ABI và registry. Tách mức proof local/contract; lưu proof+metadata vào sidecar ZIP version có reader tương thích, giữ PDF byte/hash. | Positive/negative fixture 1/2/3 leaf, sai leaf/root/path/dateKey/chain/contract; ZIP trước/sau proof giữ nguyên PDF. | Nếu thiếu deployment/ABI/proof thật, test bằng fixture và UI `chưa kiểm testnet`; không chặn việc nghiệm thu UX. |
| **07–08/11** | Chạy lại 2 thiết bị và một hồ sơ trước/sau anchor; test mạng chậm, reload, submit lặp; kiểm PDF/ZIP trên Safari/Windows; `flutter analyze`, `flutter test`, coordinator `npm test`, Web build. Khóa script demo, ghi blocker chuyển sang tuần 3. | Báo cáo nghiệm thu tuần 2; commit riêng VietQR/thiết bị và proof/RPC nếu xong. | Cần team cung cấp một hồ sơ đã anchor trước giờ demo, vì cron batch không nhất thiết trùng giờ trình diễn. |

Nếu chỉ còn một ngày sau khi giải quyết lỗi iPhone/VietQR, ưu tiên chạy **proof local + RPC trên một fixture đã anchor**. Không mở thêm cloud, ảnh đính kèm, NFC native hoặc thay đổi signing protocol v2 trong tuần này.

## 4. NFC: kế hoạch chuẩn bị, điều kiện bật đọc thật

1. **Ngay trong app:** thay hard-code `MockIdentityReader` ở `create_agreement_page.dart` và `join_agreement_page.dart` bằng factory/DI. Web và build demo dùng mock có nhãn rõ. iOS chỉ hiển thị lựa chọn NFC khi adapter `isSupported()` thực sự true; lỗi/hủy trả về để người dùng thử lại hoặc dùng mock nếu chế độ demo cho phép. Version hóa `IdentityEvidence` nếu đổi ý nghĩa các field.
2. **Điều kiện để bắt đầu native:** có Mac/Xcode, Apple signing, iPhone vật lý, giao thức/SDK CCCD được phép dùng, AID và phương pháp xác thực/trust anchors. `Info.plist` hiện chỉ có usage string; [Apple yêu cầu NFC Tag Reading entitlement và AID cho ISO 7816](https://developer.apple.com/documentation/corenfc/nfctagreadersession). Chỉ thêm entitlement/AID khi giá trị thật được xác nhận; không điền AID phỏng đoán.
3. **Lượt native sau khi đủ điều kiện:** Swift platform channel dùng `NFCTagReaderSession`/`NFCISO7816Tag`, APDU qua SDK/giao thức, xác thực chứng thư/chip, kiểm hủy/timeout/tag rời, xóa buffer nhạy cảm. Test trên iPhone vật lý với dữ liệu thử nghiệm, rồi mới cân nhắc CCCD cá nhân. Không coi việc đọc được text là đã xác thực chip. Chữ ký hợp đồng vẫn là bước riêng, NFC không thay thế ký.
4. **Nếu không có Mac trước hạn demo:** trạng thái chính thức là “NFC chưa được tích hợp/kiểm thử”, iPhone Safari vẫn demo toàn bộ luồng Web với CCCD mock. Không hứa NFC thật ở buổi nộp bài.

## 5. Thiết kế VietQR và thử trên một iPhone

- B cần trả tiền cho **A**, nên QR/chi tiết nhận tiền phải lấy từ draft đã khóa, cùng một payload ở màn A và B. Đổi số tiền/tài khoản sau khi A ký đòi phiên và chữ ký mới. A cần tự đối chiếu tiền trong app ngân hàng trước khi xác nhận thủ công.
- Kiểm format theo [EMVCo Merchant-Presented QR](https://www.emvco.com/emv-technologies/qr-codes/) và đối chiếu hành vi app ngân hàng thật; test hiện tại chỉ kiểm vài substring/CRC dạng regex nên chưa chứng minh QR liên thông. Nhóm đã có tài khoản nhận tiền và app ngân hàng cho lượt xem trước; không cần gửi số tài khoản cho người làm app trước khi kiểm tại thiết bị. Che số tài khoản trong screenshot, không đưa vào test fixture hoặc Git.
- Cung cấp nút lưu/chia sẻ ảnh QR và copy tài khoản/số tiền/nội dung để B chuyển trong app ngân hàng trên cùng iPhone. Không tự mở đường dẫn ngân hàng giả định là chuẩn chung. Nếu app ngân hàng không hỗ trợ nhập QR từ ảnh, nhập tay là fallback minh bạch.
- UI phân biệt `QR đã tạo` → `B tự báo đã chuyển` → `A tự xác nhận đã nhận`; không có trạng thái “ngân hàng đã xác minh” khi chưa có bank API. Trong test chỉ xem trước người nhận/số tiền, không cần chuyển tiền thật.

## 6. Proof/RPC và hợp đồng bàn giao

App chỉ gọi endpoint proof/status và RPC **read-only**. `dateKey` lấy từ SCT/status đã đối chiếu, không tự suy từ ngày điện thoại. Proof phải ràng buộc `agreementHash` của PDF, root/dateKey của response và root đã ghi trên registry; service chỉ báo `batched` vẫn chưa đủ. RPC sai chain, lỗi CORS, timeout hoặc contract chưa deploy => `chưa kiểm được`; dữ liệu mâu thuẫn => `không hợp lệ`. Không xóa SCT/PDF/ZIP local khi proof lỗi.

| Cần từ nhóm khác trước 05/11 | Vì sao cần | Nếu chưa có |
| --- | --- | --- |
| Contracts: address/ABI/chain ID của deployment Sepolia, signer đang hoạt động, deploy tx, một root/dateKey đã anchor | Pin policy EIP-712 và RPC `eth_call` đúng contract | Chạy fixture, không hiện verified on-chain |
| Service: HTTPS test URL + CORS cho origin staging, response 201/200/status/proof và mã lỗi; fixture 1/2/3 leaf, một proof thật | Đọc từ iPhone Safari và kiểm Merkle/ZIP thực | Chạy adapter fixture, không chờ mạng vô hạn |
| Cả hai: hash/PDF/SCT/proof/root/tx của một hồ sơ đã anchor và một hồ sơ pending | Kịch bản trình diễn trước/sau anchor | Demo offline/SCT fixture, ghi blocker testnet |

Không tự sửa repo `contracts/` hoặc `service/`; mọi thiếu sót API được ghi vào `docs/integration-handoff.md` để thành viên phụ trách bổ sung.

**Điểm sửa dự kiến trong app:** `lib/features/payment/vietqr_service.dart` và hai màn A/B cho QR; `lib/features/identity/` cùng `IdentityEvidence` cho NFC readiness; `lib/features/notary/notary_client.dart` hoặc proof client mới cho status/proof; `lib/features/artifacts/evidence_manifest.dart`, `artifact_service.dart`, `verify_bundle_page.dart` cho proof/ZIP; `lib/core/config/app_config.dart` cho endpoint/deployment. Test đi cùng từng lớp, không sửa giao thức service/contracts trong app để che lỗi tích hợp.

## 7. Ma trận kiểm tra và quyết định cắt phạm vi

| Thiết bị | Ca bắt buộc | Bằng chứng |
| --- | --- | --- |
| Windows Chrome/Edge | Tạo A, nhận B, VietQR, ZIP xuất/nhập, sai SCT/proof, màn 768/1280 | Test automation + một lượt browser thật |
| iPhone Safari qua HTTPS | Mở invite, đọc/ký mock, QR trên cùng điện thoại, báo chuyển demo, refresh, xem kết quả, thử tải/nhập ZIP; màn hẹp/touch | Ghi model/iOS/Safari và pass/fail từng bước |
| iOS native NFC | **Ngoài tiêu chí tuần 2 khi không có Mac** | Chỉ kết luận sau Xcode/signing/entitlement/SDK và thử trên iPhone vật lý |

**Ưu tiên khi trễ:** giữ luồng Windows↔iPhone/VietQR và một đường chứng minh proof/RPC bằng fixture đã anchor; cắt NFC native, Drive/cloud, hình ảnh đính kèm, polish không ảnh hưởng thao tác. Nếu hợp đồng/service chưa deploy, không dùng chữ “on-chain verified” trong demo. Sau tuần 2, phần native NFC là milestone riêng khi có Mac/SDK; signing envelope v2 và lưu phiên bền vững vẫn thuộc giai đoạn sau demo.

## Nguồn nền tảng đã đối chiếu

- [Flutter: môi trường build các nền tảng](https://docs.flutter.dev/platform-integration) và [hỗ trợ Safari/Web](https://docs.flutter.dev/reference/supported-platforms).
- [Apple Core NFC](https://developer.apple.com/documentation/corenfc/), [NFCTagReaderSession](https://developer.apple.com/documentation/corenfc/nfctagreadersession) và [thiết lập iOS/Xcode](https://docs.flutter.dev/platform-integration/ios/setup).
- [NAPAS 247 bằng VietQR](https://napas.com.vn/dich-vu-chuyen-tien-nhanh-napas-247) và [EMVCo QR Merchant-Presented](https://www.emvco.com/emv-technologies/qr-codes/).
