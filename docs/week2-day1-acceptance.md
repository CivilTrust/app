# Nghiệm thu phần việc 02/11 — nền tảng thử Windows/iPhone

Triển khai ngày 26/10/2026 theo đầu việc 02/11 trong kế hoạch tuần 2. Baseline trước thay đổi: `b69a72f` (code chức năng tuần 1 tại `ddfef3e`, biên bản `453399c`). Chỉ sửa trong `app/`; không sửa hoặc commit thêm các file `plan.md`/kế hoạch tuần 2, không sửa `contracts/` và `service/`.

## Phạm vi đã triển khai

1. **Profile mạng:** `APP_ENV=local|staging`, endpoint coordinator/notary hỗ trợ root-relative; staging kiểm HTTPS, loopback, credential/query/fragment. Trang HTTPS không được dùng coordinator HTTP. Cấu hình coordinator lỗi chặn bước tạo/tham gia phiên và hiển thị kiểm tra môi trường; màn nhập ZIP vẫn truy cập được.
2. **Dịch vụ chưa sẵn sàng:** `NOTARY_ENABLED=false` bỏ qua submit/status notary, vẫn tạo ZIP offline. Không thay bằng phản hồi giả hoặc kết luận có SCT. Bật notary sau khi thành viên cung cấp HTTPS URL/CORS; chữ ký SCT vẫn phải qua policy deployment đã có từ tuần 1.
3. **Chẩn đoán trước demo:** tab Thông tin kiểm URL và health theo yêu cầu, timeout 8 giây, phân biệt healthy/lỗi/disabled. Coordinator health dùng header mẫu cố định để kiểm đường truy cập của API, không tạo phiên, không gửi PDF/hash/PII/capability; lỗi không in raw response/exception chứa URL nhạy cảm. Kết quả healthy không được coi là đã kiểm toàn bộ A/B hoặc on-chain.
4. **CORS và server demo:** allowlist origin chính xác, staging bắt buộc HTTPS allowlist; kiểm OPTIONS method/header, origin ngoài danh sách trả 403 trước mutation. Server demo bind loopback, chỉ phục vụ `build/web` và `/coordinator/*`, kiểm traversal/symlink, không expose workspace/service/internal API. Coordinator giới hạn 200 phiên và thu hồi phiên hết hạn khi tạo mới; đây vẫn là demo in-memory, chưa phải backend production.
5. **URL dùng trên điện thoại:** script build staging, start server+tunnel ẩn, lưu PID/start time vào `.demo/` đã ignore; script stop chỉ dùng PID/start time khớp. Marker/hash build tránh `SkipBuild` dùng nhầm bản local. Không cài service thường trú, không thay firewall và không đưa credentials vào source/build.
6. **Invite/NFC:** link mới chỉ mang capability trong fragment, không giữ query/fragment cũ; Web dùng no-referrer. Trang Thông tin ghi rõ mock/NFC chưa tích hợp; chưa có Mac/Xcode/SDK/AID/trust anchor để xác minh chip. Màn đang tải Web bổ sung sau khi quan sát lần tải đầu qua tunnel chậm.

## Kiểm thử đã đạt

| Gate | Kết quả |
| --- | --- |
| `dart analyze` | Không có issue |
| `flutter test --no-pub` | 50 test đạt; 1 live test skip theo cấu hình mặc định |
| `coordinator/npm test` | 7/7 đạt, gồm CORS, health, static traversal, giới hạn phiên và lifecycle |
| Live test với `LIVE_COORDINATOR_URL=<URL HTTPS>/coordinator` | 1/1 đạt: tạo/đọc/cập nhật/đóng phiên mã hóa A/B qua tunnel thật |
| `build-phone-demo.ps1` | Web build staging đạt; Wasm dry run đạt; notary disabled |
| Public HTTPS kiểm bằng HTTP client | Web 200, health healthy; OPTIONS PUT + Authorization/Content-Type trả 204 với origin chính xác; origin lạ trả 403 |
| Browser in-app | Bản Web nạp qua URL công khai, tab Thông tin chạy health và hiện Coordinator hợp lệ/Notary disabled/NFC chưa sẵn sàng |
| iPhone Safari | Người dùng trực tiếp báo Coordinator health hợp lệ và Notary disabled trên chính URL đã mở; chưa cung cấp model/iOS |
| PowerShell | Parser ba script không lỗi; start demo chạy thành công; guard PID/start time của hai process khớp thực tế. Chưa gọi stop khi người dùng đang thử URL để giữ phiên/tunnel hoạt động. |

URL/PID/log của lần chạy được lưu tại `.demo/state.json` và log trong `.demo/`, không đưa vào Git. Script và hướng dẫn chạy lại ở `docs/phone-demo.md`.

## Phần chưa nghiệm thu và việc tiếp theo

- Chưa chạy toàn bộ A/B, ký mock, thanh toán mô phỏng, export/import ZIP trên **hai thiết bị Windows/iPhone** trong lượt này. Health từ Safari và test API HTTPS là bằng chứng kết nối, không thay thế ma trận UI hai thiết bị của ngày 04/11.
- Chưa nghiệm thu QR bằng app ngân hàng hoặc các thao tác lưu/chia sẻ QR trên một iPhone; thuộc ngày 03/11. Không có chuyển tiền thật trong lượt này.
- Chưa có endpoint notary/deployment testnet/ABI/signer/proof thật; không có kiểm Merkle/RPC mới trong ngày 02/11. Không hiển thị on-chain verified.
- NFC thật vẫn bị chặn bởi thiếu Mac/Xcode và giao thức/SDK/trust anchors; có iPhone/CCCD không tự hoàn thành các đầu vào này.
- URL Quick Tunnel tạm hoạt động khi máy Windows và process đang chạy; không có SLA/hostname ổn định. Người dùng có thể dừng bằng `stop-phone-demo.ps1`. Không dùng dữ liệu hồ sơ thật trên bản demo công khai.
