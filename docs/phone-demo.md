# Chạy thử CivilTrust trên Windows và iPhone

Đây là bản demo Web dùng danh tính/chữ ký mock. Không đưa CCCD thật hoặc tài khoản thật vào **phiên ký demo công khai**, không chuyển tiền thật trong lượt thử. Riêng màn **Thông tin → Thử VietQR cục bộ** cho phép tự nhập tài khoản nhóm kiểm soát ngay trên thiết bị để đối chiếu màn xem trước ngân hàng: dữ liệu nhập chỉ ở trang đó, không tạo phiên hoặc gọi coordinator/notary. Không gửi số tài khoản thật vào chat, ảnh chụp báo cáo hoặc Git. NFC native, proof/RPC và notary thật chưa được nghiệm thu ở bước cấu hình ngày 02/11.

## Tạo URL HTTPS tạm

Từ thư mục `app/` trên Windows có Flutter, Node.js 20+ và `cloudflared` trong PATH:

```powershell
./start-phone-demo.ps1
```

Script build Web với `APP_ENV=staging`, `COORDINATOR_URL=/coordinator`, `NOTARY_ENABLED=false`, sau đó mở server trên `127.0.0.1:8790` và Cloudflare Quick Tunnel. URL `https://….trycloudflare.com` được in ra; Web và coordinator dùng cùng origin nên iPhone không gọi nhầm localhost của chính điện thoại. Không cần cài chứng chỉ tự ký, mở firewall hoặc cài Windows service.

URL chỉ có hiệu lực khi Windows không ngủ và hai tiến trình demo còn chạy; không có bảo đảm uptime và URL thay đổi khi mở tunnel mới. [Cloudflare xác định Quick Tunnel là môi trường thử nghiệm](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/). Bất kỳ ai có URL đều có thể mở bản demo; đây không phải nơi lưu hồ sơ thật. Coordinator chỉ lưu ciphertext nhưng vẫn là storage in-memory, tối đa 200 phiên cùng lúc; restart mất phiên. CORS không phải cơ chế xác thực: từng phiên vẫn cần capability riêng.

Nếu đã build bằng đúng script và chưa thay đổi bản build:

```powershell
./start-phone-demo.ps1 -SkipBuild
```

Script kiểm marker/hash build để không dùng nhầm bản local còn trỏ `localhost`. `.demo/state.json` lưu URL/PID/start time cho lần chạy hiện tại, `.demo/*.log` để kiểm lỗi tunnel; toàn bộ `.demo/` và build được Git ignore. Không thêm capability/session token vào log.

## Dừng và mở lại

```powershell
./stop-phone-demo.ps1
```

Script chỉ dừng PID có tên và start time khớp state đã ghi, tránh dừng process khác khi PID bị tái sử dụng. State cũ cũng được xóa khi các process đã tự thoát; log vẫn giữ để đọc lỗi. Sau đó chạy lại `start-phone-demo.ps1` để có URL mới. Không chia sẻ invite của URL cũ khi đã restart.

Nếu dùng một `PORT` khác: `./start-phone-demo.ps1 -Port 8791`. Port đã có ứng dụng khác sẽ bị từ chối, không tự dừng ứng dụng đó.

## Kiểm nhanh trên hai thiết bị

1. Mở cùng URL HTTPS trên Chrome/Edge Windows và Safari iPhone. Lần đầu có thể tải Flutter lâu; màn nạp hiển thị trong lúc chờ.
2. Vào **Thông tin → Kiểm tra kết nối**. Coordinator cần trả health hợp lệ; notary của build mặc định phải hiển thị đã tắt. Health không đồng nghĩa toàn bộ ký/ZIP hoặc blockchain đã được kiểm.
3. Windows tạo A, dùng CCCD mock và tài khoản giả lập; copy link mời mở trên iPhone. Không dùng URL localhost khi gửi sang điện thoại. Link chứa khóa giải mã/capability trong fragment nên chỉ gửi riêng cho người đóng vai B; không đăng ảnh chụp link.
4. B đọc/ký mock và báo chuyển khoản mô phỏng; A làm mới và ghi chú `DEMO - không có giao dịch thật` trước khi xác nhận. App vẫn xuất ZIP mà không gọi notary ở build offline.
5. Đổi vai Windows/iPhone; kiểm link, date picker, tải ZIP và nhập ZIP ở trình duyệt độc lập. Ghi pass/fail từng bước; không suy ra Safari đã qua từ widget test trên Windows.

Ghi cho mỗi lượt: commit/build, model iPhone, iOS/Safari, Chrome/Edge Windows, mạng Wi-Fi/di động và lỗi cụ thể. Ảnh chụp phải che capability và mọi dữ liệu thật. Chưa có Mac/Xcode/SDK CCCD nên NFC thật vẫn chưa được tích hợp; có thẻ CCCD không tự làm adapter native hoạt động.

## VietQR trên một iPhone

Từ bản công việc 03/11, màn A/B dùng chung thông tin đã khóa: BIN, tài khoản, tên người nhận do A cung cấp, số tiền và nội dung chuyển khoản. Nút **Sao chép Số tiền** sao chép số nguyên đồng, không có dấu phân cách. **Tải ảnh QR** xuất PNG riêng với nền trắng/quiet zone; **Chia sẻ ảnh QR** mở share sheet khi thiết bị hỗ trợ. Nếu chia sẻ không hỗ trợ, chọn tải hoặc nhập thông tin bằng tay; hủy chia sẻ không tự tải ảnh hoặc đánh dấu đã chuyển tiền.

Để kiểm ngân hàng mà không tạo hợp đồng: vào **Thông tin → Thử VietQR cục bộ**, nhập BIN/tài khoản nhóm kiểm soát, tên khai báo và số tiền thử; tạo QR rồi lưu/chia sẻ ảnh. Mở chức năng đọc ảnh QR của app ngân hàng, đối chiếu tên người nhận ngân hàng trả về, số tiền và nội dung rồi dừng trước bước xác nhận chuyển tiền. Nếu không đọc được ảnh, thử quét QR từ màn Windows hoặc nhập tay. Việc đổi đầu vào sẽ ẩn QR cũ cho tới khi tạo lại, tránh dùng nhầm tài khoản trước đó. Số tài khoản có trong PNG là dữ liệu cần thiết cho QR chuyển tiền; chỉ chia sẻ theo mục đích của bạn.

Phiên mới dùng nội dung chuyển khoản dẫn xuất từ toàn bộ ID, lưu cùng profile `vietqr-account/2` trong draft trước khi A/B ký. Đây là version của app, không phải công bố version chuẩn NAPAS. Phiên cũ vẫn giữ reference từng dùng; số tài khoản cũ vượt giới hạn profile sẽ được báo không hỗ trợ thay vì cắt/sửa trong hồ sơ đã ký. Đọc được QR không phải bằng chứng đã nhận tiền.

## Khi nhận được service HTTPS từ thành viên phụ trách

```powershell
./build-phone-demo.ps1 -NotaryUrl https://notary.example.test
```

Đây là URL ví dụ, phải thay bằng endpoint thật có CORS cho origin Web. Nếu bật notary, kiểm health từ Safari rồi nghiệm thu submit/SCT riêng; địa chỉ registry/signer tin cậy vẫn cần cấu hình đúng deployment trước khi gọi SCT hợp lệ. App không proxy/expose service, cluster API hoặc contracts qua demo server.

Nếu triển khai tách Web và coordinator, truyền `ALLOWED_ORIGINS` là danh sách **origin chính xác**, ví dụ `https://app.example.test`, khi chạy coordinator. `APP_ENV=staging` ở server sẽ từ chối thiếu danh sách hoặc origin HTTP; local không cấu hình chỉ chấp nhận Origin HTTP loopback. OPTIONS cho phép các method/header mà API phiên thực sự dùng, không phản chiếu origin bất kỳ.
