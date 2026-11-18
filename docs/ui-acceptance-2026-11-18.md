# Nghiệm thu cải thiện giao diện và trải nghiệm — 18/11/2026

Phạm vi: chỉ `app/` (Flutter client và coordinator nội bộ của app). Không sửa `contracts/` hoặc `service/`. Không đổi giao thức ký, hash PDF, schema evidence hay API coordinator. Nhánh `ui/foundation-forms`, tách từ `8dd2859`.

## 1. Đã triển khai

| Giai đoạn | Commit | Nội dung chính |
| --- | --- | --- |
| 1 + 3 (form) | `ba0d56b` | Bộ màu navy/teal và các tông trạng thái (thông tin, thành công, cảnh báo, lỗi, mô phỏng); điều hướng dưới trên điện thoại, thanh bên từ 840px và giữ nguyên trạng thái trang khi đổi bố cục; lịch chọn ngày tiếng Việt; bật cây trợ năng cho bản Web; ô tiền có dấu phân cách và số tiền bằng chữ; chọn ngày có giới hạn; chọn ngân hàng có tìm kiếm; lãi suất 0–20%/năm, người ký đủ 18 tuổi, giới hạn độ dài; màn "chưa thể tạo hợp đồng" thay cho trang chẩn đoán |
| 2 | `67832b8` | Trang chủ; Điều khoản sử dụng, Chính sách quyền riêng tư (Luật 91/2025/QH15) và câu hỏi thường gặp ở dạng dự thảo; thông báo xử lý dữ liệu trước mỗi lần đọc danh tính; hộp tạo kho có thanh độ mạnh mật khẩu và ô xác nhận không khôi phục được mật khẩu |
| 4 | `eface61` | Màn Hồ sơ chia nhóm Cần xử lý / Đang chờ / Đã xong / Bản nháp, có tìm kiếm; mã hồ sơ CT-XXXXXXXX trùng tiền tố nội dung chuyển khoản; thẻ "Việc bạn cần làm" và tiến trình 7 bước; QR lời mời; bắt đọc hết toàn văn trước khi ký; hộp xác nhận trước mọi thao tác không hoàn tác |
| 5 | `504db5c` | Theo dõi thay đổi chỉ đọc (~45 giây, chỉ coordinator đã cấu hình, không ghi kho, dừng khi ẩn/khóa); chuông thông báo, toast có nút Mở, nhãn "Có cập nhật mới" |
| 6 | commit này | Test trợ năng theo chuẩn Flutter, test cỡ chữ 200%, sửa tràn bố cục, nén gzip ở server demo, biên bản này |

Các ràng buộc giữ nguyên:
- `fields` của bản nháp vẫn lưu tiền dạng chữ số và ngày dạng `dd/mm/yyyy`; nhãn trường chỉ dùng cho giao diện, nên digest hồ sơ v1 không đổi.
- Validator mới chỉ áp dụng khi soạn bản nháp, không đánh giá lại hồ sơ đã ký.
- Bộ theo dõi thay đổi không gửi quyền truy cập tới coordinator khác với cấu hình.

## 2. Kết quả kiểm tra

| Phép kiểm | Kết quả |
| --- | --- |
| `flutter analyze --no-pub` | Không có issue |
| `flutter test --no-pub` với `LIVE_COORDINATOR_URL`/`LIVE_WORKSPACE_URL` trỏ coordinator loopback | **196/196 đạt**, không bỏ qua test nào (baseline trước khi cải thiện: 134 đạt + 6 bỏ qua) |
| Coordinator `npm test` | 12/12 đạt, gồm kiểm tra nén gzip và trường hợp không yêu cầu nén |
| Chuẩn trợ năng Flutter (vùng chạm Android/iOS, nút có nhãn, tương phản chữ) | Đạt trên Trang chủ, chọn mẫu, Hồ sơ (kho khóa), Kiểm chứng, Chính sách quyền riêng tư ở 375×812 |
| Cỡ chữ 200% | 5 tab chính và bước danh tính → điều khoản không tràn bố cục, sau khi sửa dòng "Bước x/6" |
| Flutter Web release (local) | Build đạt; `main.dart.js` 5,3 MB, truyền đi 1,55 MB khi nén gzip |
| Duyệt thử bằng trình duyệt 375×812 | Tạo kho → tạo hợp đồng đặt cọc vai A → chi tiết → khóa nội dung (hộp xác nhận) → đọc toàn văn → Hồ sơ hiển thị "Cần xử lý" |

## 3. Chưa nghiệm thu và giới hạn

- Chưa thử trên iPhone/Safari thật cho các thay đổi giao diện này. Chưa thử hai người thật nhận thông báo của nhau trên hai thiết bị.
- Không có thông báo khi app ở nền: kho tự khóa khi tab bị ẩn (quy tắc bảo mật có sẵn). Web Push cần sửa coordinator, để sau.
- Văn bản pháp lý là bản dự thảo, chưa được rà soát pháp lý, chưa có email liên hệ chính thức của bên kiểm soát dữ liệu.
- Danh sách ngân hàng và mã BIN cần đối chiếu danh sách NAPAS trước khi dùng thật.
- Chưa có router theo URL. Nút back trên thanh tiêu đề của màn chi tiết đưa về tab trước đó.
- Chưa có dark mode và font chữ riêng đóng gói.
- CanvasKit tải từ CDN của Google theo mặc định của Flutter. Nếu cần chạy hoàn toàn không phụ thuộc bên ngoài, build với `--no-web-resources-cdn` (tệp tải lần đầu lớn hơn).
- Danh tính và chữ ký vẫn là mô phỏng, không phải CCCD/NFC thật.
