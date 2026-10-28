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

## Giai đoạn 3 — workflow và quyền theo vai trò

API `/v2/sessions` tách khỏi legacy `/v1`. Phiên lưu role người tạo, server ánh xạ owner/participant thành A/B; hành động có chữ ký action key và ràng buộc session/version/digest/ciphertext. A duyệt thông tin nhận, người tạo ký trước, bên còn lại ký; B báo chuyển, A xác nhận nhận. Sau khóa không thay draft digest. Chuỗi sự kiện được app tự kiểm và khóa hành động được bind trong identity envelope v2. V1 không thể ghi đè phiên v2 qua endpoint cũ.

Client lưu capability, khóa và mã tạo phiên trước POST; tạo lại cùng mã/key/token là idempotent, không tạo hợp đồng trùng sau mất response. Mỗi thao tác lưu signed intent trước mạng; lỗi mơ hồ yêu cầu làm mới, không tự ký lại. Hồ sơ nhập từ endpoint khác không tự gửi token sang URL mới.

Tests: coordinator 11/11, gồm A/B creator, sai vai trò, stale version, frozen digest và v1 bypass; Flutter validator + live HTTP A/B/vault-reopen 5/5 đạt. Đây vẫn là demo capability + mock identity, không phải bằng chứng hai chủ thể thật hay NFC đã tích hợp. Người sở hữu bearer capability có quyền tương ứng; trusted CCCD verifier vẫn là blocker riêng.

## Giai đoạn 4 — giao diện và hồ sơ nguyên bản

App có chọn vai trò A/B, lưu bản nháp (tự lưu khi kho mở), tiếp tục bản nháp bằng đọc danh tính mới; màn Hồ sơ và chi tiết dùng chung, duyệt tài khoản A trước khóa, ký đúng vai trò, báo chuyển B/xác nhận A. Tạo revision là đề xuất mới với ID/ceremony mới, giữ bản đã ký bất biến. Không thêm tài khoản đăng nhập.

A lưu nguyên ZIP trong vault trước notary/publish; coordinator giữ encrypted artifact nguyên bản, B tải được cùng bytes, PDF hash không đổi. Quyền publish chỉ A sau xác nhận nhận; owner B không được publish thay A. Phiên mới active 7 ngày; sau publish giữ quyền tải 30 ngày trên server, không phải lưu trữ vĩnh viễn. Bản lưu vault/backup vẫn là phần cần thiết. ZIP demo tối đa 5 MiB, kiểm giới hạn giải nén; không đẩy dữ liệu CCCD thật vào luồng này.

Test live Dart/Node cho hai hướng creator đã đi qua xác nhận tiền, publish, tải lại bởi B và mở lại ZIP từ vault: 2/2 đạt, assert cùng bytes PDF/ZIP và không load font để tái tạo. Widget role B/narrow viewport và luồng review/payment đã đạt sau sửa dropdown expanded và cập nhật thao tác cuộn theo bố cục mới. Web QA release build đạt. Nghiệm thu trình duyệt và kiểm lỗi gián đoạn được ghi tiếp ở giai đoạn 5.
