# B tạo đề xuất, A bổ sung và ký trước — 29/10/2026

## Phạm vi và quyết định

Chỉ sửa `app/`, gồm coordinator nội bộ app; không sửa contracts/service. Danh tính và chữ ký vẫn là mock theo luồng A hiện có. Không tích hợp NFC thật, không gọi ngân hàng hoặc chuyển tiền. Các file kế hoạch không đưa vào commit.

Profile mới `payer-proposal/1` chỉ áp dụng cho B tạo mới. A tạo vẫn dùng `creator-independent/1`; B tạo cũ cũng giữ nguyên profile/thứ tự ký. Không thay hash, migrate hoặc đổi quy tắc của hồ sơ đang có. UI hồ sơ B cũ giải thích vì sao B vẫn ký trước. Cả app/coordinator và hai bên phải dùng bản mới để mở profile mới; không fallback sang quy tắc cũ khi không nhận diện profile.

## Luồng người dùng đã triển khai

1. B chọn mẫu, đọc danh tính mock, nhập điều khoản/số tiền/thời hạn. Form không yêu cầu danh tính A hoặc tài khoản nhận. Kể cả sao chép revision cũ, thông tin ngân hàng không được gửi vào đề xuất B mới.
2. B xem lại và tạo đề xuất chưa ký; capability/key được giữ trong kho mã hóa trước request. Gửi lời mời riêng cho A.
3. A đọc điều khoản, có thể gửi phản hồi đề nghị chỉnh sửa hoặc từ chối. Hai nhánh này chốt đề xuất hiện tại, không sửa lịch sử; B dùng nút tạo đề xuất mới từ nội dung cũ, với ID/ceremony mới và liên kết bản thay thế.
4. Nếu tiếp tục, A đồng ý đọc mock, xem danh tính A vừa đọc rồi điền tài khoản. Tên được gợi ý từ danh tính mock nhưng không được coi là tài khoản đã xác thực ngân hàng. A kiểm tra và khóa bản cuối, rồi đọc danh tính mới/ký như luồng A tạo. Khóa và ký là hai bước rõ ràng: nếu ký lỗi, bản khóa chưa được coi đã ký.
5. B nhận bản A đã ký; màn chi tiết hiển thị danh tính A bổ sung, tài khoản và yêu cầu kiểm tra trước khi ký. Digest điều khoản đề xuất và lịch sử event được so với bản cục bộ, chặn thay điều khoản trong bước A bổ sung. Chỉ B ký sau A trong profile mới.
6. Ngay khi đủ chữ ký, B tự lưu PDF/ZIP gốc vào vault trước upload. `publishSignedArtifact` lưu nguyên bản trên coordinator, chỉ cho B và chỉ một lần. Nếu lưu/upload lỗi, không ký lại: làm mới rồi dùng nút lưu/khôi phục. Không cho báo chuyển trước khi nguyên bản đã được server lưu.
7. VietQR mở sau đủ chữ ký. B chuyển tiền ngoài app, quay lại xác nhận tự khai đã chuyển; mã tham chiếu và chứng từ là tùy chọn. Tệp PNG/JPEG/PDF tối đa 1 MiB, kiểm magic/MIME/hash, cho xem trước ảnh hoặc tải PDF. Người gửi phải xác nhận đã kiểm/loại bỏ thông tin nhạy cảm trước gửi tệp. Đây không phải tính năng tự che dữ liệu hoặc kiểm tính thật của chứng từ.
8. Thông báo/chứng từ nằm trong encrypted session, gắn với ID và signed event của B. B lưu gói bằng chứng mới; ảnh chuyển khoản không tự đổi trạng thái sang nhận tiền. Không đính kèm vẫn báo rõ chưa có chứng từ.
9. A xem chứng từ, kiểm app ngân hàng của mình rồi tự xác nhận nhận tiền. Có lựa chọn phản hồi chưa thấy tiền/có sai lệch; phản hồi này giữ `paymentPending`, không tự coi đã nhận đủ hay quy kết B gian lận. Hiện hỗ trợ một phản hồi sai lệch, không phải hệ thống đối soát nhiều lần/trả góp.
10. Sau A xác nhận, app tự lưu/công bố gói cuối. B làm mới để lấy cùng gói cuối. Lỗi công bố không làm mất xác nhận đã đồng bộ; dùng làm mới/lưu lại, không xác nhận tiền lần hai.

## Tài liệu và bằng chứng

- Chữ ký A/B tiếp tục ràng buộc digest bản nội dung đã khóa bằng envelope v2; không tuyên bố chữ ký số pháp lý hoặc chữ ký trực tiếp trên bytes PDF.
- Evidence schema mới `civiltrust-evidence/3.0`: snapshot đủ hai chữ ký có hash riêng; `agreement.pdf` tạo từ snapshot đó một lần. PDF chứa tài khoản nhận và ghi rõ không xác nhận tiền đã đến.
- Gói trước thanh toán, B báo chuyển và A xác nhận có thể khác ZIP/evidence hash, nhưng giữ cùng PDF bytes/documentHash. Chứng từ nằm trong sidecar JSON mã hóa khi truyền/lưu; khi người dùng xuất ZIP, sidecar chứa chứng từ đọc được và cần được coi là dữ liệu nhạy cảm.
- Gói cuối đã publish không bị tạo lại khi refresh/lưu lại; không làm mất SCT đã đính kèm. Có bản gốc trong `signedArchive`, bản hiện tại trong `archive`; các signed events giữ lịch sử thông báo/xác nhận. Không có ba bản PDF khác nhau cho ba mốc.
- Notary vẫn tắt nếu cấu hình tắt. Nếu bật, A yêu cầu SCT khi công bố cuối cho hash PDF nguyên bản; verifier/trust policy vẫn được áp dụng. Không có SCT/proof thì ghi đúng chưa có. Không tự bổ sung hoặc tự xác nhận Merkle/RPC.
- Chứng từ do B cung cấp và xác nhận A là hai lớp riêng; UI kiểm chứng ZIP hiển thị riêng trạng thái này với SCT/proof. Kho backup quyền truy cập vẫn là file riêng, không gửi cho đối tác.

## Kiểm thử và giới hạn nghiệm thu

- Toàn bộ Flutter: **140/140 đạt** với `LIVE_COORDINATOR_URL` và `LIVE_WORKSPACE_URL` trỏ server loopback thật; không bỏ qua live tests. Bao gồm hồi quy A tạo, B cũ và B mới.
- Coordinator Node: **12/12 đạt**, gồm pin profile, chặn B ký trước trong profile mới, quyền A/B, bản signed artifact chỉ công bố một lần, chặn chuyển trước lưu bản gốc và không cho B xác nhận nhận tiền.
- `flutter analyze --no-pub`: **No issues found**. Web release build đạt; kiểm whitespace diff đạt. Không cài đặt/nâng Flutter hoặc dependency mới trong lượt này.
- Live B mới kiểm đề xuất không ngân hàng, A bổ sung/ký trước, phục hồi sau mất phản hồi publish/reportTransfer, giữ PDF/hash qua đủ chữ ký → báo chuyển → báo sai lệch → nhận tiền → gói cuối, tải lại từ A/B và mở lại vault. Font fixture chỉ được tải hai lần để tạo một PDF, không render lại mỗi mốc.
- Có kiểm tamper reference/hash chứng từ, sai hợp đồng, tệp sai magic/quá dung lượng; digest điều khoản không đổi khi A chỉ bổ sung tài khoản và phải đổi nếu điều khoản bị sửa. Đề nghị sửa/từ chối được kiểm qua HTTP.
- Widget 375×812: B đọc mock và đi tới review chỉ với điều khoản, không có trường tên tài khoản/số tài khoản hoặc yêu cầu danh tính A. Các widget A/review/VietQR cũ vẫn chạy.
- Web release build phục vụ QA trên localhost; không tự mở tunnel hoặc phát hành. Browser kiểm B chọn vai trò, đọc mock, form điều khoản không có trường tài khoản A. Kiểm trên laptop không thay nghiệm thu Safari/iPhone hay Android vật lý.
- PDF tests dùng font fixture để kiểm bytes/hash/evidence, không phải nghiệm thu bố cục tiếng Việt trên thiết bị. NFC thật, ngân hàng, testnet live và pháp lý không được tính pass từ các test mock này.

## Bàn giao tích hợp

Contracts/service vẫn nhận PDF hash. Profile/evidence mới cần được thống nhất nếu hệ thống khác muốn đọc sidecar; không tự cho rằng parser cũ hiểu schema v3. Nền NFC thật vẫn bị gate cho đến khi SDK/verifier và privacy policy sẵn sàng; mock không tự chuyển thành xác thực CCCD. Không thêm secret/vendor key vào Flutter defines. Giữ HTTPS ổn định, database, vault password và backup theo runbook hiện có.
