# Nghiệm thu app tuần 1 — 26/10/2026

Phạm vi: commit `ddfef3e` trong `app/`, trên Windows; dữ liệu danh tính, tài khoản và chuyển khoản đều **mô phỏng**. Không sửa `contracts/` hoặc `service/`.

## Gate tự động

| Kiểm tra | Kết quả |
| --- | --- |
| `dart analyze` | Pass, `No issues found!` |
| `flutter test --no-pub --reporter compact` | Pass 41 test; 1 live test skip khi không đặt `LIVE_COORDINATOR_URL` |
| `coordinator/npm test` | Pass 4/4 |
| `flutter test --no-pub --dart-define=LIVE_COORDINATOR_URL=http://127.0.0.1:8788 test/live_coordinator_test.dart` | Pass 1/1 với coordinator local |
| `flutter build web --no-pub` | Pass; Wasm dry run thành công |

Flutter dùng cache SDK ngoài workspace và coordinator cần loopback localhost; các gate đã chạy với quyền môi trường phù hợp. Log cảnh báo Helvetica thiếu glyph trong fixture PDF của unit test không ảnh hưởng bản Web dùng Noto Sans; PDF không đổi ở commit tuần 1 này.

## Chạy thử Web

Chạy bản build Web tại `http://127.0.0.1:8085` với coordinator local `:8788`, notary `:8787` không chạy. Ba tab trong in-app browser giữ vai A, B và người kiểm chứng. Đây là kiểm thử ba tab độc lập, **chưa phải hai Chrome profile hay hai thiết bị vật lý**.

1. A chọn mẫu đặt cọc, nạp danh tính mock, điền tài sản mô phỏng, tổng giá trị 20.000.000 VND, tiền cọc 2.000.000 VND, hạn 30/11/2026, tài khoản giả lập; xem lại và ký digest mock. QR thể hiện đúng tiền cọc 2.000.000 VND.
2. B mở link capability, đọc nội dung, nạp danh tính mock, ký cùng phiên rồi đánh dấu chuyển khoản **mô phỏng**. A làm mới thấy B đã ký và báo chuyển.
3. A ghi rõ `DEMO - không có giao dịch thật`, hoàn tất và tải ZIP. App báo notary không sẵn sàng nhưng vẫn xuất hồ sơ; màn hoàn tất hiện `Chưa có SCT` và `On-chain chưa kiểm tra`.
4. Tab kiểm chứng độc lập nhập ZIP vừa tải: hash PDF, canonical evidence và chữ ký Ed25519 demo A/B đều hợp lệ; xác nhận nhận tiền chỉ ở mức có dữ liệu thủ công; SCT và Merkle proof đều vắng; blockchain chưa cấu hình registry. ZIP chứa đúng `agreement.pdf` và `evidence.civiltrust.json`; PDF bắt đầu bằng `%PDF-`, manifest mang hash `0x0cdc3623f965c41814721fdcb98145dcf6f1482c0e587ba5fbfa1c14629ca378`.
5. Tạo bản ZIP kiểm thử chỉ thêm SCT fixture Viem vào sidecar, với `agreementHash` không khớp PDF vừa tạo. Tab kiểm chứng vẫn xác nhận PDF/evidence/chữ ký demo nhưng đánh riêng SCT là `Không hợp lệ` với lý do hash không khớp. Điều này kiểm nhánh từ chối SCT sai mà không làm hỏng hồ sơ local.

## Kết luận và giới hạn

**Đạt nghiệm thu phần app tuần 1 ở mức offline và SCT verifier theo fixture.** Code tạo/nhập ZIP và trạng thái UI đúng khi service vắng hoặc SCT sai. Unit test Viem đã kiểm trường hợp SCT hợp lệ với policy được cấu hình, nhưng lượt Web này chưa có SCT thật để nghiệm thu nhãn `SCT đã tự kiểm chữ ký` từ service.

Chưa nghiệm thu end-to-end testnet: `contracts/deployments/arbitrum-sepolia.json` vẫn để `CivilTrustRegistry` rỗng; notary ở endpoint app đang cấu hình không chạy; chưa có public signer/ABI/SCT/proof/transaction của deployment thật. Hai Chrome profile hoặc hai thiết bị thật, PDF render của hồ sơ mới này, và on-chain verification cũng chưa được chạy trong lượt này. Trước demo, chạy lại với đầu vào bàn giao trong `docs/integration-handoff.md`; không gắn nhãn đã neo cho tới khi app kiểm Merkle và RPC ở tuần 2.
