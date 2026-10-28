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

## Giai đoạn 5 — gia cố lỗi mạng, quyền truy cập và nghiệm thu

- Tạo phiên lưu toàn bộ capability/key vào kho trước POST. UI gắn `sourceFormId` để thử lại cùng bản nháp tiếp tục đúng ID, kể cả server đã tạo nhưng response bị mất. Không tự thay nội dung đã gửi bằng các chỉnh sửa mới trên form: muốn thay nội dung phải tạo đề xuất mới.
- Mỗi request coordinator giới hạn chờ 20 giây. Timeout không có nghĩa server chưa xử lý; thao tác đã ký đang chờ phải Làm mới trước khi tiếp tục. Test HTTP cố tình bỏ response sau khi server đã nhận create/publish, kiểm không tạo trùng và giữ nguyên ZIP/PDF.
- Khi kho khóa, màn tạo/chi tiết che dữ liệu và xóa consent/danh tính tạm. Hàng đợi lưu không được chuyển thao tác cũ sang phiên mở kho mới. Kiểm xung đột hai kho đang mở giữ nguyên bản mới hơn, không ghi đè im lặng.
- Gói khôi phục cũ không rollback snapshot. Nếu thiết bị đã nhận phiên nhưng thiếu khóa thao tác, có thể nhập backup gốc để phục hồi đúng seed đã đăng ký; version hiện tại vẫn giữ nguyên. Test kiểm khóa khôi phục khớp public key của vai trò B và version 9 không bị hạ xuống 1.
- Hồ sơ từ URL khác không tự gửi capability tới endpoint đang cấu hình, kể cả khi tải ZIP hoặc thử lại create. Có nút đổi coordinator với xác nhận rõ ràng; chỉ chấp nhận HTTPS hoặc loopback phát triển, kiểm đúng ID/vai trò/version/frozen digest trước khi lưu endpoint mới. Người dùng vẫn phải xác minh server thuộc nhóm: kiểm mã hóa không thay thế việc xác minh chủ server trước khi gửi token.
- Hồ sơ đã publish chỉ lấy lại bản đã lưu, không gọi lại notary/tạo ZIP mới khi bấm lại. Notary tắt vẫn tạo ZIP offline, không tự nhận có SCT/proof/on-chain.

### Kết quả kiểm tra

1. `npm test` tại coordinator: **11/11 đạt**, gồm SQLite reopen/CAS và workflow A/B.
2. Toàn bộ `flutter test` với cả `LIVE_COORDINATOR_URL` và `LIVE_WORKSPACE_URL` trỏ tới server loopback thật: **134/134 đạt**, không bỏ qua các live tests. Có kiểm tương thích luồng legacy.
3. `flutter analyze --no-pub`: **No issues found**.
4. Flutter Web release staging: build phục vụ kiểm tra tại `build/workspace-qa`; không tự khởi tạo tunnel công khai.
5. Nghiệm thu trình duyệt trên laptop: tạo kho mã hóa, chọn creator B, lưu bản nháp loan, đóng tab, mở tab mới cùng origin, nhập lại mật khẩu và thấy bản nháp trong Hồ sơ. Đây là kiểm IndexedDB thật, không chỉ test bộ nhớ. Ảnh bằng chứng local: `.demo/workspace-history-restored.png` (không commit).

Chưa nghiệm thu luồng mới trên iPhone vật lý. Kiểm trình duyệt trên laptop không thay cho Safari/iOS; hai hướng ký/thanh toán/publish đã được kiểm bằng test HTTP với danh tính và dữ liệu tổng hợp, không chuyển tiền thật. Không có bằng chứng NFC thật hoặc xác thực pháp lý hai người trong giai đoạn này.

### Cách sử dụng sau khi đóng tab

1. Mở đúng URL/origin cũ bằng cùng trình duyệt → **Hồ sơ** → mở kho bằng mật khẩu đã tạo.
2. Chọn hợp đồng để xem trạng thái cục bộ; **Làm mới** lấy trạng thái server và kiểm chuỗi sự kiện. Khi mất mạng có thể xem bản lưu, nhưng không coi trạng thái cache là mới nhất.
3. Xuất **gói khôi phục mã hóa** và giữ mật khẩu riêng, nhất là trước khi đổi URL tunnel, xóa dữ liệu site hoặc đổi thiết bị. Không gửi gói này cho bên đối tác. ZIP bằng chứng là tệp khác.
4. Đổi URL tunnel: nhập gói khôi phục ở origin mới; nhóm phải giữ database của coordinator. Xác nhận đổi endpoint trong chi tiết rồi đồng bộ. Nếu database mất/phiên hết TTL, chỉ backup không thể dựng lại phiên server để tiếp tục ký.
5. Người tạo B có quyền mời A nhưng không có quyền xác nhận nhận tiền thay A. A vẫn duyệt thông tin nhận tiền trước khóa; người tạo ký trước, người còn lại ký sau. B báo chuyển và A tự xác nhận nhận; không coi đây là xác nhận từ ngân hàng.

### Phần bàn giao và giới hạn

Chỉ commit mã nguồn/tests/tài liệu nghiệm thu trong `app/`; các file kế hoạch giữ ngoài commit. Contracts/service không bị sửa. Tích hợp sau này cần trusted identity verifier/SDK CCCD, Apple signing/native build để test NFC trên iPhone, notary/proof/RPC thật, hosting HTTPS ổn định và chính sách lưu trữ/backup production. Không cần đổi vai trò A/B hoặc tạo lại PDF đã công bố khi bổ sung các dịch vụ đó; khả năng tương thích giao thức phải được nhóm kiểm trước khi bật.
