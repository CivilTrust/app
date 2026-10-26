# Tuần 1, ngày 1 — baseline app

Ghi nhận ngày 25/10/2026 trên Windows, trước mốc kế hoạch 26/10. Repo `app/` bắt đầu sạch ở commit `e42e362` (`docs: detail app week-one SCT workplan`). Chỉ thay đổi trong `app/`.

## Kết quả đã kiểm

| Lệnh | Kết quả |
| --- | --- |
| `flutter --version` | Flutter 3.47.7, Dart 3.13.5 |
| `flutter analyze` | Pass, `No issues found` sau thay đổi ngày 2 |
| `flutter test` | Pass 28 test; live coordinator test được skip khi thiếu `--dart-define=LIVE_COORDINATOR_URL=...` |
| `flutter build web` | Pass, tạo `build/web` |
| `npm test` tại `coordinator/` | Pass 4/4 khi cho phép loopback; sandbox mặc định trả `EACCES 127.0.0.1` |
| `flutter test --dart-define=LIVE_COORDINATOR_URL=http://127.0.0.1:8788 test/live_coordinator_test.dart` | Pass 1/1 với coordinator local đang chạy |

`flutter analyze` và `flutter test` tự chạy `pub get`; thông báo 15 package có bản mới không tương thích constraint hiện tại, không phải lỗi kiểm thử. Test PDF dùng Helvetica giả lập nên log cảnh báo thiếu glyph tiếng Việt; cần kiểm PDF render thực tế với Noto Sans trong lượt thử browser.

## Cấu hình và phạm vi xác nhận

| Thành phần | Đang dùng | Lưu ý |
| --- | --- | --- |
| Coordinator | `http://localhost:8788` | In-memory; restart mất phiên |
| Notary URL trong app/script | `http://localhost:8787` | Service Bun hiện mặc định port `3000`; đặt `CIVILTRUST_NOTARY_URL=http://localhost:3000` hoặc `--dart-define=NOTARY_URL=...` |
| Chain ID | `421614` | Chưa có deployment address/signer để kiểm chứng SCT/on-chain |
| `REGISTRY_CONTRACT` | zero address | Phải thay bằng address testnet trước khi kiểm RPC |

Luồng ZIP offline được test tự động: hai chữ ký mock và xác nhận thanh toán tạo `agreement.pdf`, `evidence.civiltrust.json`; import ZIP đối chiếu hash PDF và phát hiện PDF bị sửa. Test mới xác nhận thêm SCT chỉ đổi sidecar, giữ nguyên byte PDF và `documentHash`.

## Nghiệm thu UI bổ sung ngày 26/10/2026

Đã chạy luồng localhost với ba tab browser cô lập A, B và người kiểm chứng trên bản Web build mới, dùng coordinator local và dữ liệu CCCD/tài khoản **mô phỏng**. A tạo hợp đồng đặt cọc xe máy: tổng giá trị 20.000.000 VND, tiền cọc 2.000.000 VND, hạn 31/10/2026; khóa nội dung và ký Ed25519 mock. Link mời mở được ở tab B; B đọc nội dung, nạp danh tính mock, ký cùng digest rồi đánh dấu đã chuyển tiền **chỉ để kiểm luồng, không chuyển tiền thật**. A làm mới, thấy hai trạng thái của B, xác nhận thủ công và tạo hồ sơ offline. B làm mới và thấy A đã xác nhận. Màn A hiển thị VietQR đúng 2.000.000 VND.

ZIP tải từ UI chứa `agreement.pdf` và `evidence.civiltrust.json`. Import ZIP mới ở tab kiểm chứng độc lập cho kết quả: PDF hash, canonical evidence hash và cả hai chữ ký Ed25519 mock đều hợp lệ. Xác nhận nhận tiền **có dữ liệu nhưng chưa được ngân hàng kiểm chứng**. Không có SCT hoặc Merkle proof vì notary không chạy; UI cũng không báo đã xác thực on-chain. PDF thật được render kiểm tra cả 2 trang A4: dấu tiếng Việt đọc được, nhãn `Số tiền đặt cọc: 2.000.000 VNĐ` không nhầm với tổng giá trị giao dịch, thông báo bản demo hiển thị và khối danh tính/chữ ký B không bị tách qua trang.

Trình duyệt kiểm thử cô lập vẫn không đọc được clipboard sau nút copy, nên UI đã bổ sung ô link mời chỉ đọc để chọn/sao chép thủ công; không đủ bằng chứng kết luận nút copy lỗi trên Chrome thông thường. Ba tab cô lập **không thay thế** kiểm thử hai profile Chrome hoặc hai thiết bị thật. PDF vẫn ghi phần định danh B trong điều khoản đã khóa dưới dạng placeholder, rồi ghi danh tính B ở khối chữ ký: đây là hệ quả của việc A ký nội dung trước khi B xác minh, cần chốt mô hình dữ liệu cho bản sau. `localhost` trên điện thoại trỏ về điện thoại, nên thử iPhone Safari chỉ sau khi có endpoint HTTPS truy cập được.

## Mốc kiểm tiếp theo

1. Chạy lại trên hai profile Chrome hoặc hai thiết bị thật; kiểm thao tác copy/paste invite, session/capability, responsive và tải ZIP. Dùng bản demo không chứa PII thật; chỉ xác nhận nhận tiền sau khi có giao dịch testnet/ngân hàng phù hợp, không dùng kết quả mô phỏng làm bằng chứng thanh toán.
2. Chạy với service thật ở đúng port; xác nhận cả response `201` và submit lặp `200` được lưu SCT nhưng UI vẫn chỉ báo đã nhận, chưa báo đã tự kiểm chữ ký.
3. Khi contracts/service có deployment testnet và Merkle proof, kiểm chứng từ ZIP tới chữ ký SCT, proof và on-chain; không gắn nhãn xác thực pháp lý vượt quá lớp bằng chứng đã kiểm.
