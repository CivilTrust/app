# Tuần 1 — nối SCT vào app và bàn giao tích hợp

Phạm vi chỉ ở `app/`. App đã có parser SCT v1.3.0, verifier EIP-712 thuần Dart, và hiển thị kết quả trong luồng tạo hợp đồng lẫn nhập ZIP. `contracts/` và `service/` do thành viên khác phụ trách; chưa có deployment/SCT thật để kết luận end-to-end trên Arbitrum Sepolia.

## Luồng đã hoàn thiện trong app

1. A và B ký digest của draft bằng chữ ký demo; A xác nhận thủ công việc nhận tiền. App tạo `agreement.pdf` cuối và tính `agreementHash = keccak256(bytes PDF)`.
2. App gửi **chỉ hash PDF** đến notary. Nếu service lỗi, ZIP vẫn được xuất không có SCT. Nếu service trả SCT typed hợp lệ về cấu trúc/hash, app gắn SCT vào `evidence.civiltrust.json` và giữ nguyên byte PDF.
3. App phục hồi signer từ chữ ký EIP-712, đối chiếu hash PDF, domain chain/registry và tập public signer được cấu hình qua `REGISTRY_CONTRACT`, `CHAIN_ID`, `SCT_BATCH_SIGNER`, `SCT_RECEIPT_SIGNER`. Field `sct.signer` không tự tạo trust.
4. Màn hoàn tất chỉ ghi “SCT đã tự kiểm chữ ký” nếu đủ cấu hình tin cậy và phép kiểm qua. Nếu chữ ký sai thì ghi không hợp lệ; nếu thiếu deployment/signer thì ghi chưa thể kết luận; nếu service vắng thì ghi chưa có SCT.
5. Màn Kiểm chứng nhập ZIP, kiểm toàn vẹn PDF/evidence/chữ ký A-B như trước, rồi **tự chạy lại** verifier SCT từ sidecar với hash PDF đã kiểm. Không đọc một cờ `verified` từ JSON. Merkle proof và blockchain có dòng riêng, không được suy diễn từ SCT.

## Ranh giới mức chứng cứ

| Kết quả | Ý nghĩa hiển thị | Chưa được kết luận |
| --- | --- | --- |
| Không có SCT | ZIP local/offline vẫn hợp lệ ở lớp PDF và chữ ký demo | Notary chưa cấp receipt |
| `notConfigured` | Signature phục hồi được nhưng thiếu địa chỉ deployment/signer tin cậy | Không được gọi SCT hợp lệ |
| `invalid` | Hash/domain/signature/signer không khớp hoặc dữ liệu hỏng | Không dùng SCT làm bằng chứng |
| `unsupported` | SCT mới hơn hoặc schema ngoài v1.3.0 | Cần nâng app có version migration |
| `valid` | PDF hash, EIP-712 và signer cấu hình khớp | Chưa chứng minh batch, Merkle root, transaction hay trạng thái on-chain |

`valid` phụ thuộc cấu hình build. Chỉ điền signer/address từ deployment đã xác minh; không dùng địa chỉ fixture trong bản demo. Compile-time `--dart-define` chứa **public addresses**, không chứa private key. Nếu signer rotation, app phải cập nhật danh sách đáng tin theo quy tắc của deployment; bản v1 hiện có hai slot public signer.

## Dữ liệu cần thành viên khác bàn giao để lên tuần 2

| Chủ sở hữu | Đầu vào cần giao | Vì sao app cần |
| --- | --- | --- |
| Contracts | Registry address, chain ID, ABI đúng commit/deployment, deploy tx/explorer, public `batchSigner`/`receiptSigner`, quy tắc rotate và vai trò mỗi signer | Pin policy SCT; sau đó gọi read-only RPC `verifyReceipt`/`verifyAgreement` |
| Service | URL testnet + CORS cho Web, response `submit` 201/200 cùng SCT thật, `status`/`proof` và mã lỗi cụ thể | Kiểm parser thực và trạng thái pending/batched; chuẩn bị proof client |
| Cả hai | Một PDF/hash/SCT/proof/root/dateKey/tx đã anchor, vector sai hash/domain/signature, proof 1/2/3 lá | Test xuyên lớp Viem → Dart → Merkle → RPC và demo không phụ thuộc cron |

Điểm phải chốt chung: nhánh submit idempotent `200` có luôn `sct.signer` hay không; signer nào được phép ký receipt trước/sau batch; `dateKey` ở quiet window; ý nghĩa từng `404` của proof. App hiện chấp nhận `sct.signer` vắng và tin vào địa chỉ **phục hồi từ signature** khi policy cho phép.

## Nghiệm thu tuần 1 và việc còn chặn

- Test fixture Viem xác nhận digest, ECDSA recovery và các đột biến hash/payload/domain/signature; test UI mapping kiểm không có SCT, thiếu config, hợp lệ, sai và version mới.
- Kiểm tra tại máy Windows: `dart analyze` không có issue; `flutter test --no-pub` đạt **41 test, 1 live test skip** vì chưa đặt `LIVE_COORDINATOR_URL`; `flutter build web --no-pub` thành công (Wasm dry run thành công); `coordinator npm test` đạt **4/4**. Các test Flutter/coordinator cần quyền ghi cache SDK và kết nối localhost; lần chạy trong sandbox bị chặn môi trường, lần chạy lại với quyền phù hợp đã đạt.
- Luồng offline tạo PDF/ZIP và kiểm hash đã có test artifact; hai browser A/B đã được thử ở baseline ngày 1. Sau thay đổi ngày 5 chưa thử thủ công lại toàn bộ hai browser với service thật; chỉ nghiệm thu đầu cuối khi nhóm bàn giao endpoint và signer. Đây là bước chạy lại cụ thể trước demo, không được xem là đã qua.
- Chưa có proof/RPC verifier. Trong tuần 2, thêm proof adapter, Merkle local và RPC read-only; chỉ nâng kết quả on-chain khi cả phép kiểm cục bộ và RPC thực sự thành công. Không cần sửa `agreement.pdf` để thêm proof.
- Máy hiện dùng Windows, nên demo ưu tiên Flutter Web hai profile. iOS native cần Mac/Xcode và không nằm trong nghiệm thu tuần 1.
