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

**Nghiệm thu UI một phần:** trên bản Web localhost, A chọn mẫu đặt cọc, dùng danh tính mock, điền điều khoản, khóa và ký thành công. Màn A hiển thị link invite và VietQR đúng số tiền mô phỏng. Nút sao chép báo thành công nhưng clipboard trong trình duyệt cô lập của công cụ kiểm thử vẫn rỗng; Chrome thường không được công cụ này kết nối. Vì vậy chưa hoàn tất thao tác B, xác nhận A, tải ZIP hoặc kiểm font PDF qua UI; chưa có ZIP mẫu từ thao tác UI để bàn giao. Đây là giới hạn môi trường kiểm UI, chưa đủ bằng chứng kết luận nút copy lỗi trên Chrome thật. Live coordinator test chứng minh hai client Dart trao đổi được phiên, nhưng không thay thế thao tác UI. Cần chạy checklist trong `README.md` với hai browser profile và giữ ZIP demo không chứa PII thật. `localhost` trên điện thoại trỏ về điện thoại, nên thử iPhone Safari chỉ sau khi có endpoint HTTPS truy cập được.

## Mốc kiểm tiếp theo

1. Hai profile: A tạo và ký, B mở invite và ký/báo chuyển, A xác nhận sau khi tự xem app ngân hàng, tải ZIP.
2. Import ZIP trên browser độc lập; xác nhận `agreement.pdf` và `evidence.civiltrust.json` có mặt, hash PDF trùng `documentHash`.
3. Chạy lại với service thật ở đúng port; xác nhận cả response `201` và submit lặp `200` được lưu SCT nhưng UI vẫn chỉ báo đã nhận, chưa báo đã tự kiểm chữ ký.
