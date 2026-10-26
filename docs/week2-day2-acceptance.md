# Công việc 03/11 — VietQR và thao tác trên một iPhone

Thực hiện sớm ngày 26/10/2026 từ baseline `c0dfa5f`. Phạm vi chỉ thuộc `app/`: payment UI/model/export, validation trong màn hợp đồng, test, dependency và hướng dẫn vận hành. Không sửa coordinator/service/contracts, không sửa hoặc commit thêm file kế hoạch. Không thay schema SCT, evidence hoặc quy ước neo hash PDF.

## Phân tích và thứ tự đã triển khai

1. **Sửa payload trước UX:** builder cũ thiếu `38/02=QRIBFTTA` và chỉ có test substring/CRC dạng regex. Bản mới thêm service code account-transfer, kiểm BIN 6 chữ số, tài khoản 4–19 chữ/số, tiền dương tối đa 13 chữ số, reference ASCII 1–25 ký tự. Không cắt ngầm tài khoản/reference, không tự bỏ dấu hoặc sửa nội dung đã xem lại. Đây là giới hạn profile app, không chứng nhận tài khoản/BIN tồn tại hay ngân hàng chấp nhận mọi số tiền.
2. **Khóa cùng bộ thông tin A/B:** `PaymentDetails` đọc từ draft; cả hai màn dùng `PaymentQrCard`. Tên hiển thị là do A cung cấp, không giả định bank lookup đã xác nhận. UI cho copy từng trường và bộ thông tin, tải PNG hoặc chia sẻ ảnh. Mọi thao tác này không gọi bank API và không đổi trạng thái thanh toán.
3. **Tránh reference trùng:** trước đây tám ký tự đầu ID là timestamp nên nhiều hồ sơ có reference giống nhau. Hồ sơ mới dùng `CIVILTRUST` + 12 ký tự hex dẫn xuất từ toàn bộ ID, lưu `paymentPurpose`/`paymentQrProfile=vietqr-account/2` trong `fields` trước khi A/B ký. Reference phục vụ đối chiếu, không phải chứng từ ngân hàng hoặc cam kết duy nhất tuyệt đối. A xem recipient/reference ở bước review, B xem trước khi ký; sửa thông tin phải review/consent lại. Snapshot review được giữ nguyên khi tạo chữ ký.
4. **Tương thích hồ sơ cũ:** không ghi thêm/sửa trường trên draft/PDF đã ký; giữ nguyên reference cũ và cảnh báo có thể trùng. Metadata profile mới không hợp lệ hoặc tài khoản cũ quá dài sẽ báo không hỗ trợ, không tự cắt hoặc mở nút báo chuyển tiền từ card lỗi. Reader ZIP tuần 1 vẫn đọc các `fields` mở rộng và xác minh digest như trước.
5. **Ảnh QR tách biệt:** PNG có nền trắng và quiet zone bốn module, kích thước pixel nguyên mỗi module. UI dùng đúng PNG được xuất; ảnh không chụp trang chứa invite, CCCD hoặc điều khoản. PNG được chuẩn bị trước thao tác share để giữ user activation. Tên file dẫn xuất từ ID, không đưa số tài khoản/họ tên vào filename. Share bị hủy/không hỗ trợ không tự chuyển sang download; kết quả không rõ chỉ được ghi là đã yêu cầu thao tác. Không ghi raw exception hoặc share target vào UI/log app.
6. **Thử ngân hàng không tạo phiên:** thêm `VietQrPreviewPage` từ mục Thông tin. Tài khoản nhóm kiểm soát được nhập ngay trên thiết bị, giữ trong state/controller của trang, không tạo phiên hoặc gửi đến coordinator/notary. Sửa input ẩn ảnh cũ ngay. Chỉ xem trước ngân hàng, không chuyển tiền; lưu/chia sẻ ảnh do người dùng chủ động chọn.

## Kiểm thử và bằng chứng

| Hạng mục | Kết quả |
| --- | --- |
| Phân tích tĩnh | `dart analyze`: không có issue |
| Hồi quy app | `flutter test --no-pub`: **65 đạt, 1 live test skip** theo cấu hình mặc định |
| Coordinator | `npm test`: **7/7 đạt**, không thay code coordinator |
| Web staging | `build-phone-demo.ps1`: thành công; Wasm dry run thành công; URL/coordinator giữ cùng origin, notary disabled |
| Payload | Golden tự mã hóa tay với dữ liệu tổng hợp; CRC độc lập bằng Python `binascii.crc_hqx` cho ra `55EF`; decoder TLV/CRC test-only dùng thuật toán nibble-table khác builder. Kiểm nested bank/service/currency/amount/purpose, giới hạn trường và dữ liệu bị sửa |
| Ảnh PNG | ZXing `zxing2` giải mã độc lập đúng payload; kiểm nền trắng/quiet zone và không chứa invite hoặc tên khai báo |
| Chữ ký | Đổi BIN/tài khoản/tên/reference/profile trong draft làm SessionValidator từ chối chữ ký; A/B round-trip cùng instructions cho hai loại mẫu |
| UI test | Màn 375px, copy số tiền nguyên đồng, xuất/chia sẻ bằng adapter fake, hủy/lỗi share, lỗi render, render đến muộn, ẩn payment action khi dữ liệu sai, review/sửa yêu cầu consent mới, local preview ẩn QR khi input đổi |
| Browser thật | Mở bản HTTPS, vào local preview, tạo dữ liệu tổng hợp BIN `970436`, tài khoản giả lập, 2.000.000 VND; tải PNG **684×684** từ nút thật. ZXing/TLV/CRC đọc lại chính file tải được và khớp input/reference. Không tạo phiên trong lượt local preview này |
| iPhone thật | Người dùng trực tiếp xác nhận **iPhone 12** tải/chia sẻ ảnh và màn xem trước ngân hàng đều đúng. Chưa cung cấp iOS hoặc tên app ngân hàng; không ghi nhận đã chuyển tiền |

Dependency runtime thêm `share_plus 13.3.1` để dùng share sheet và fallback rõ ràng; `zxing2 0.2.4`/`image 4.10.2` là dev dependency cho đọc PNG độc lập. Các dependency hiện có không được nâng phiên bản ngoài yêu cầu; `pubspec.lock` ghi phiên bản đã kiểm.

## Nguồn tham chiếu và giới hạn kết luận

- Cấu trúc account-transfer được đối chiếu nguồn gốc phần mềm [sunary/vietqr](https://github.com/sunary/vietqr/blob/master/const.go) và [subiz/vietqr](https://github.com/subiz/vietqr), gồm `A000000727`, nested bank/account và `QRIBFTTA`. Golden test dùng dữ liệu tổng hợp, không sao chép tài khoản của ví dụ công khai.
- [share_plus](https://pub.dev/packages/share_plus) mô tả Web Share API và khả năng fallback/download; app tắt auto-download fallback để hủy chia sẻ không tạo tác động khác.
- [zxing2](https://pub.dev/packages/zxing2) cung cấp bộ đọc QR độc lập với renderer `qr_flutter`.
- Đây là nghiệm thu profile app + một lượt xem trước ngân hàng trên iPhone 12, **không phải chứng nhận liên thông toàn bộ NAPAS/ngân hàng**. Hạn mức và tài khoản do ngân hàng kiểm tra. UI tiếp tục phân biệt QR được tạo, B tự báo chuyển, A tự xác nhận nhận tiền.
- Chưa nghiệm thu đầy đủ A/B, payment mock và ZIP trên Windows ↔ iPhone trong lượt ngày 03/11; đó vẫn là ca xuyên suốt ngày 04/11. iOS native, NFC thật và proof/RPC chưa nằm trong thay đổi này.
