# Hồ sơ hợp đồng: creator độc lập, lưu và khôi phục

Chỉ thay đổi `app/`, chưa thay contracts/service. Không thêm tài khoản đăng nhập. File kế hoạch không đưa vào commit.

## Giai đoạn 1 — mô hình vai trò

Đã tách PartyRole khỏi quyền owner và định nghĩa state machine: A xác nhận thông tin nhận tiền, người tạo ký trước (A hoặc B), người còn lại ký; B báo chuyển; chỉ A xác nhận nhận. Event/action key có thể khôi phục từ seed bên trong kho mã hóa, không phải xác thực CCCD. Test domain/action-key: 5/5 đạt trước commit.

## Giai đoạn 2 — nền lưu trữ

- Coordinator dùng SQLite khi chạy server/demo; tests có memory adapter. SQLite giữ ciphertext và token hash, WAL và compare-and-swap theo version. Default DB ở `.demo/coordinator.sqlite` được ignore, không tự xóa khi stop demo. Cần Node.js >=24; local đã có 24.18.0. Đây chưa phải dịch vụ production/multi-node hoặc chính sách sao lưu tự động.
- Kho thiết bị dùng AES-256-GCM và PBKDF2-HMAC-SHA256 600.000 vòng, salt ngẫu nhiên 16 byte; mật khẩu 12–256 ký tự. Không lưu mật khẩu hoặc khóa mở kho cạnh ciphertext. IndexedDB trên Web có CAS trong transaction; native dùng file ciphertext và file lock. Khóa được giữ trong RAM khi mở, xóa buffer khi khóa; không tuyên bố chống XSS khi kho đang mở hoặc bảo đảm xóa mọi bản sao trong runtime.
- Có export/import gói khôi phục mã hóa. Nhập kiểm mật khẩu trước khi merge, không ghi đè hồ sơ hiện có bằng backup cũ. Không có quên mật khẩu hoặc tự đồng bộ khác thiết bị; cần giữ mật khẩu và backup riêng an toàn. Đây là gói quyền truy cập, không phải ZIP để gửi bên kiểm chứng.
- Safari/Web storage vẫn có thể bị xóa hoặc tách theo origin; URL ổn định và backup vẫn cần thiết. Chưa test iPhone vật lý trong giai đoạn này.
- Tests: SQLite/memory/CAS và coordinator 9/9; vault mã hóa/restore/wrong-password/import/CAS 2/2. Thêm test file native cho rename/reopen/conflict trong lượt kiểm giai đoạn này.
