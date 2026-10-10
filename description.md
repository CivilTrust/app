<!--
BẢN MÔ TẢ GỐC ĐƯỢC GIỮ LẠI TRONG COMMENT ĐỂ ĐỐI CHIẾU KHI REVIEW.
Bản này chứa nhiều giả định chưa được mã nguồn hiện tại chứng minh; đặc tả có hiệu lực bắt đầu sau comment này.

Overview
TÀI LIỆU ĐẶC TẢ KIẾN TRÚC DỰ ÁN: CIVILTRUST (GIAO KÈO SỐ)
Phiên bản: 3.1 (Kiến trúc Set-and-Forget / Public Good Edition)
Đồng bộ mã nguồn (07/10/2026): contracts v1.4.0 (FROST2+ Threshold Schnorr) · service v1.3.0 · app chưa có mã nguồn · tài liệu tham chiếu: docs/frost2plus-architecture-v140.md, ADR-0001 → ADR-0013.
Mục tiêu vận hành: Hệ thống tự chạy 100% không cần quản trị (Idle), chi phí cố định ~74.000đ/tháng, không thành lập công ty, không phụ thuộc API trung gian, bảo mật dữ liệu tuyệt đối theo Nghị định 13/2023/NĐ-CP.

1. TỔNG QUAN DỰ ÁN (EXECUTIVE SUMMARY)
   Tên dự án: CivilTrust – Nền tảng Xác thực & Lưu vết Thỏa thuận Dân sự P2P.
   Định vị sản phẩm: Tiện ích số công cộng (Free Public Utility / Open-source Tool) giúp người dân tự tạo lập chứng cứ pháp lý số chống chối bỏ cho các giao dịch đời sống (thuê trọ, vay mượn cá nhân, cọc mua bán, bàn giao tài sản).
   Triết lý sản phẩm cốt lõi:
   Tiền mặt VND đi qua app Ngân hàng (VietQR): Không phát hành token, không custody (giữ tiền) của người dùng, không dính dáng quy định tiền mã hóa.
   File PDF là Chứng cứ Tự thân (Self-Contained Artifact): Giá trị pháp lý nằm ngay trong tệp tài liệu số mang chữ ký phần cứng FaceID (WebAuthn trên đường cong NIST P-256) của hai bên theo Luật Giao dịch điện tử 2023, kèm biên nhận SCT (Signed Commitment Token) nhúng trong QR/metadata (ct:sct:v1:...).
   Đóng dấu hàng loạt 1 lần/ngày (Daily Merkle Anchor): Không gửi giao dịch lắt nhắt lên chain. Gom toàn bộ giao kèo trong ngày thành 1 Cây Merkle và đóng dấu đúng 1 giao dịch duy nhất vào 23:59 UTC trên Arbitrum One (~100.000 gas ≈ 800 VNĐ/ngày ≈ ~24.000đ/tháng tiền gas, bất kể số lượng hợp đồng).
   Kiến trúc Tự thân (Zero-Middleman): Tận dụng tính năng có sẵn của hệ điều hành điện thoại (Native OS Share, Camera QR, NFC CCCD). Không dùng Zalo API, không mua SMS Brandname, không thuê cổng SePay/Casso.
   Zero-PII & Lưu trữ Nội địa An toàn: Tầng service tuyệt đối chỉ xử lý mã băm 32-byte (keccak256(PDF)) — không tên, không CCCD, không nội dung tài liệu. Dữ liệu nhạy cảm (ảnh/PDF) thuộc tầng media lưu tại Data Center trong nước (Viettel IDC), tuân thủ Nghị định 13/2023/NĐ-CP.
   Mô hình Set-and-Forget (Làm xong vứt đấy): Deploy lên hạ tầng Serverless Cloudflare (0đ) + Arbitrum (~800đ/ngày tiền gas). Tác giả không tốn công quản trị, không sợ biến động chi phí.
   Không Điểm Chết Đơn Lẻ (v1.4.0): Hạ tầng ký notary nâng cấp từ 1 private key lên cụm ngưỡng FROST2+ 2-of-3 (chuẩn TS-SUF-4), chữ ký Schnorr gộp 64-byte cố định, xác minh on-chain bằng kỹ thuật Alt-Schnorr (0 gas qua eth_call).
2. ĐỐI TƯỢNG & TÌNH HUỐNG SỬ DỤNG (USE CASES)
   Thuê trọ / Bàn giao mặt bằng: Người thuê và chủ nhà ký xác nhận hiện trạng phòng (ảnh tường nứt, đồ đạc cũ, chỉ số công tơ điện nước) + Điều kiện hoàn cọc.
   Cho vay mượn cá nhân (Giấy nợ số - IOU): Xác nhận việc vay tiền, số tiền, ngày hẹn trả, lãi suất (nếu có), đính kèm mã chuyển khoản ngân hàng thật.
   Mua bán đồ cũ P2P có cọc (Chợ Tốt, Facebook Marketplace): Khóa thỏa thuận cọc chuyển hàng, tránh tình trạng bom hàng hoặc lừa tiền cọc.
   Mượn tài sản / Thuê xe tự lái: Ghi nhận hiện trạng vết xước, số km trên đồng hồ trước khi lăn bánh.
3. THIẾT KẾ TRẢI NGHIỆM NGƯỜI DÙNG TỰ THÂN (ZERO-MIDDLEMAN UX)
   Toàn bộ quy trình diễn ra trực tiếp giữa 2 người dùng (P2P), đồng bộ trạng thái tinh gọn:
   [BƯỚC 1: KHỞI TẠO] ──► [BƯỚC 2: KÝ SỐ P2P] ──► [BƯỚC 3: ĐỒNG BỘ TRẠNG THÁI] ──► [BƯỚC 4: DÒNG TIỀN THỰC] ──► [BƯỚC 5: TẢI PDF TỰ THÂN]
   Chụp 3-5 ảnh WebP      Native Share / QR        B gửi 1 POST                    Chuyển khoản VietQR        PDF + QR SCT nhúng sẵn

+ Đọc NFC CCCD         FaceID (Passkey P-256)   /api/v1/agreements/submit       Xác nhận "Đã nhận tiền"    (23:59 UTC chốt Merkle Root)
  (tùy chọn chính danh)  (chữ ký phần cứng)       A gọi GET .../status/:hash      (chữ ký FaceID 2 chiều)    Khôi phục qua /recover nếu cần

  Bước 1: Khởi tạo Thỏa thuận & Nén Ảnh Cục bộ (1 phút)
  Bên A mở Web App (PWA) trên trình duyệt điện thoại:
  Nhập tóm tắt điều khoản (ví dụ: "A nhận cọc thuê phòng 302 giá 2.000.000đ của B, báo trước 30 ngày hoàn cọc").
  Chụp tối đa 3 – 5 ảnh hiện trường trực tiếp từ camera app (Cấm tuyệt đối tải video để tránh đầy bộ nhớ).
  Thuật toán nén ảnh Client-side: PWA tự động resize ảnh về chuẩn HD (1280x720) và chuyển đổi sang định dạng WebP (chất lượng 0.7). Mỗi ảnh chỉ tốn ~80KB – 120KB. Toàn bộ file PDF gồm text và 5 ảnh chưa tới 1MB.
  (Tùy chọn chính danh): Áp thẻ CCCD gắn chip vào lưng máy để đọc NFC (chuẩn ICAO 9303), lấy chữ ký số của Cục C06 - Bộ Công An. Toàn bộ xử lý chính danh diễn ra phía client bằng WebCrypto — không có bất kỳ PII nào được gửi lên blockchain hay server (ADR-0011).
  Bước 2: Ký số Hai chiều & Chia sẻ P2P Không Tốn Phí
  Bên A quét FaceID: Chip bảo mật điện thoại (Secure Enclave / TEE) tạo chữ ký mật mã phần cứng WebAuthn (NIST P-256).
  Chia sẻ trực tiếp:
  Gặp trực tiếp: Màn hình máy A hiện mã QR, máy B bật camera quét thẳng.
  Gặp từ xa: Máy A bấm nút "Gửi", gọi bảng chia sẻ hệ điều hành (Native OS Web Share Sheet). Máy A tự chọn gửi link qua Zalo, Messenger, Telegram hay SMS cá nhân.
  Bên B ký kết: Mở link trên trình duyệt, xem nội dung + ảnh hiện trường → Bấm "Đồng ý & Ký tên" → Quét FaceID trên máy B.
  Bước 3: Đồng bộ Trạng thái Tinh gọn (Event-Driven + Manual Refresh)
  Phía Máy B: Quét FaceID xong, client tổng hợp PDF hoàn tất và gửi đúng 1 request POST /api/v1/agreements/submit (agreementHash 32-byte) lên server → nhận ngay biên nhận SCT (EIP-712) trong < 50ms. Màn hình máy B hiện nút: "Báo cho Bên A qua Zalo/Tin nhắn".
  Phía Máy A (Không dùng Polling liên tục):
  Anh An gửi link xong có thể tắt màn hình đi làm việc khác.
  Khi chị Bình báo đã ký, anh An chỉ cần mở lại app CivilTrust (hoặc bấm nút "Làm mới trạng thái").
  Ứng dụng gửi đúng 1 request GET /api/v1/agreements/status/:hash để kiểm tra → Màn hình anh An lập tức chuyển sang bước nhận tiền cọc VietQR.
  Lợi ích: Không tốn tài nguyên chạy ngầm, không ngốn request của Cloudflare.
  Bước 4: Đối soát Dòng tiền Thực (Biên nhận Số 2 Chiều)
  Màn hình hiện mã VietQR động (chứa số tài khoản Bên A, số tiền cọc, và mã tham chiếu thỏa thuận).
  Bên B mở app ngân hàng quen thuộc (Vietcombank, MB, Techcombank...) quét mã và chuyển tiền VND bình thường.
  Xác nhận biên nhận tiền (P2P Mutual Receipt):
  Khi tiền về tài khoản, Bên A mở app bấm nút: "Tôi xác nhận đã nhận đủ 2.000.000đ cọc" → Quét FaceID.
  Ý nghĩa pháp lý: Chữ ký FaceID của chính chủ nhận tiền thừa nhận "Đã nhận tiền" có giá trị chứng cứ trước Tòa án mạnh hơn bất kỳ webhook tự động nào của bên thứ ba.
  Bước 5: Xuất Bản Chứng thư Tự thân & Đóng dấu Cuối ngày
  Hiệu lực tức thì: Cả hai bên tải ngay file PDF Bản Chứng Thư Dân Sự Số. File mang sẵn 2 chữ ký phần cứng P-256, mã xác nhận nhận tiền, và QR chứa biên nhận SCT (ct:sct:v1:...) — có giá trị thi hành ngay tức khắc.
  Tự phục hồi (Client-Side Data Availability): Nếu cơ sở dữ liệu server gặp sự cố, PDF/QR vẫn chứa đủ SCT để nạp lại qua POST /api/v1/agreements/recover — không cần hai bên ký lại (ADR-0012).
  Đóng dấu niêm phong thời gian: Mã băm của giao kèo được xếp hàng vào bộ nhớ đệm trong ngày. Đến 23:59 UTC, hệ thống gom toàn bộ hợp đồng trong ngày thành một Merkle Root duy nhất và ghi lên Arbitrum bằng chữ ký ngưỡng FROST2+ 2-of-3.

4. KIẾN TRÚC LƯU TRỮ NỘI ĐỊA (VIETTEL IDC OBJECT STORAGE)
   Ghi chú đồng bộ repo: Tầng service đã triển khai (service/ v1.3.0) vận hành theo Zero-PII tuyệt đối — chỉ lưu hash 32-byte trong Cloudflare D1 / SQLite. Phần lưu trữ media (ảnh/PDF) dưới đây thuộc thiết kế tầng client/PWA (repo app/ chưa có mã nguồn).
   Nhằm tuân thủ tuyệt đối Nghị định 13/2023/NĐ-CP và bảo đảm quyền riêng tư, toàn bộ dữ liệu nhạy cảm được quản lý như sau:
   [PWA nén ảnh WebP] ──► [Xin Pre-signed URL từ Worker] ──► [Upload thẳng Viettel IDC S3 (Private)]
   │
   [Thẩm phán / Người dùng quét QR xem ảnh] ◄── [Cấp Pre-signed URL 5 phút] ─┘

   Vị trí Lưu trữ Vật lý: Đặt tại Data Center của Viettel IDC (Hà Nội và Bình Dương), đạt tiêu chuẩn an toàn thông tin Cấp độ 3 và chứng chỉ ISO 27001. Không một byte ảnh nào bay ra khỏi lãnh thổ Việt Nam.
   Quyền riêng tư Tuyệt đối (Bucket Private 100%):
   Kho chứa S3 trên Viettel IDC được khóa hoàn toàn (Private). Không ai có thể dò link hay quét ID để xem lén ảnh của người khác.
   Khi người dùng hoặc Thẩm phán quét mã QR cần xem ảnh/PDF, Cloudflare Worker kiểm tra mã băm và cấp một Pre-signed URL có thời hạn đúng 5 phút. Hết 5 phút, link tự hủy.
   Quy chuẩn Dung lượng & Định dạng File:
   Cấm upload video: Video quá nặng, gây lag PWA và nhanh đầy ổ cứng.
   Ảnh chụp: Tối đa 3 – 5 ảnh, định dạng WebP, độ phân giải HD 1280x720, dung lượng ~100KB/ảnh.
   Tổng dung lượng 1 giao kèo: < 1MB.
   Nút "Lưu vào Google Drive Cá nhân":
   Trên màn hình hoàn tất, cung cấp nút "Tải về máy / Lưu vào Google Drive".
   Trách nhiệm lưu trữ gốc thuộc về người dùng (tinh thần P2P tự thân), giúp kho lưu trữ Viettel IDC 50GB của hệ thống có thể phục vụ bền vững tới 50.000 hợp đồng.
5. CƠ CHẾ ĐÓNG DẤU "DAILY MERKLE ANCHOR" (CHỐT SỔ 23:59 UTC)
   Đây là giải pháp cốt lõi giúp hệ thống triệt tiêu gánh nặng chi phí gas:
   [Hợp đồng #001] ──┐
   [Hợp đồng #002] ──┼──► [Cây Merkle Off-chain] ──► [Merkle Root 32-bytes] ──► [Arbitrum One L2]
   [Hợp đồng #... ] ──┤     (Chốt lúc 23:59 UTC)     (Ký EIP-712 BatchAttestation)  (~100.000 gas/ngày)
   [Hợp đồng #N   ] ──┘

   5.1. Cơ chế Vận hành Kinh tế
   Ban ngày, hệ thống chỉ lưu tạm mã băm agreementHash vào cơ sở dữ liệu đệm Cloudflare D1 (0đ) và nhân bản liên tục sang node backup (Bun VPS + SQLite WAL).
   Lịch trình chống split-brain (Anti-Split-Brain Schedule):
   23:55 UTC — Quiet Window Cut-off: Các submission mới tự động roll sang ngày kế tiếp (D+1) để tránh race condition vùng biên.
   23:59 UTC — Primary Anchor: Node chính gom toàn bộ hash trong ngày, dựng Merkle Tree chuẩn OpenZeppelin v5 (double-hash), ký EIP-712 BatchAttestation và phát ĐÚNG 1 GIAO DỊCH DUY NHẤT ghi chuỗi merkleRoot (32 bytes) lên Smart Contract CivilTrustRegistry.sol (v1.4.0) trên Arbitrum One.
   00:05 UTC (D+1) — Audit & Failover: Node backup (Bun VPS) truy vấn Arbitrum One kiểm tra trạng thái ngày D. Nếu node chính chưa anchor thành công, node backup tự động kích hoạt failover.
   Cơ chế bảo vệ bất biến: Guard AlreadyAnchored(dateKey) khóa vĩnh viễn write-once — mỗi ngày chỉ ghi được đúng 1 lần, không thể sửa/xóa. Relayer là permissionless (bất kỳ ai cũng có thể broadcast giao dịch hợp lệ, ví ký không cần giữ gas).
   Chi phí Gas thực tế (theo tài liệu repo):
   1 giao dịch ghi Root trên Arbitrum: ~100.000 gas ≈ 800 VNĐ.
   1 tháng (30 ngày):
   30
   ×
   800
   đ
   =
   24.000
    VNĐ / th
   a
   ˊ
   ng
   30×800đ=24.000 VNĐ / th
   a
   ˊ
   ng.
   1 năm vận hành: Tốn đúng ~288.000 VNĐ.
   Nạp sẵn 100.000 VNĐ tiền ETH vào ví Relayer ≈ chạy được ~4 tháng; nạp ~300.000 VNĐ ≈ trọn 1 năm.
   Ghi chú giờ UTC: 23:59 UTC tương đương ~07:00 sáng hôm sau theo giờ Việt Nam.
   5.2. Logic Xử lý Ngoại lệ (Fail-Safe & Retry)
   Nếu ngày hôm đó không có hợp đồng nào: Worker kiểm tra if (totalAgreementsToday == 0) return; → Bỏ qua, không gửi transaction để tiết kiệm tiền gas.
   Nếu mạng Arbitrum bị nghẽn hoặc RPC lỗi:
   Node chính kích hoạt cơ chế Retry.
   Nếu vẫn lỗi, đến 00:05 UTC node backup tự động audit và rescue bằng failover (node 2 ký và broadcast lại batch của ngày D).
   Nếu cả hai node bỏ lỡ (sự cố mạng toàn cầu), toàn bộ dữ liệu ngày hôm đó sẽ tự động gộp chung vào đợt chốt sổ của đêm hôm sau, không bao giờ bị mất dấu vết.
6. BẰNG CHỨNG PHÁP LÝ & GIẢI PHÁP CHO THẨM PHÁN / LUẬT SƯ
   6.1. Cơ sở Pháp lý Vững chắc tại Việt Nam
   Điều 22 & 23 Luật Giao dịch điện tử 2023: Công nhận chữ ký điện tử tạo bằng phương tiện do người ký kiểm soát tại thời điểm ký (Chip phần cứng FaceID NIST P-256) và có khả năng phát hiện mọi thay đổi đối với văn bản sau thời điểm ký.
   Điều 119 Bộ luật Dân sự 2015: Thừa nhận hợp đồng được xác lập thông qua hành vi thực tế (chuyển và nhận tiền VietQR có xác nhận 2 bên).
   Nghị định 13/2023/NĐ-CP: Đảm bảo 100% vì Zero-PII On-Chain. Không có Tên, SĐT, Số CCCD nào bị đưa lên mạng blockchain quốc tế; chỉ có các mã băm toán học vô nghĩa. Chính danh (CCCD/C06) xử lý hoàn toàn phía client bằng WebCrypto — các hàm xác thực PII từng có trên contract đã bị gỡ bỏ từ v1.2.0 (ADR-0011).
   Bảo vệ chữ ký notary: Biên nhận SCT dùng EIP-712 buộc chặt chainId + địa chỉ contract (chống replay cross-chain), có deadline hết hạn chữ ký. Contract không thể nâng cấp (no upgradeability) và không giữ ETH (zero custody).
   6.2. Quy trình Thẩm phán kiểm tra tranh chấp (Chỉ mất 5 giây, 0 đồng gas):
   Cách 1: Quét mã QR: Thẩm phán dùng camera điện thoại quét mã QR trên bản in giấy → Trình duyệt mở verify.civiltrust.vn (xác minh client-side bằng WebCrypto, không qua server trung gian) → Màn hình hiện TÍCH XANH xác nhận văn bản nguyên bản.
   Cách 2: Kéo thả file PDF (Giám định chống Photoshop):
   Thẩm phán truy cập trang tra cứu, kéo thả file PDF nghi vấn vào ô kiểm tra.
   Trình duyệt tự băm file ra chuỗi hash và đối chiếu với Merkle Root đã chốt sổ trên blockchain Arbitrum:
   Khớp: Báo xanh (Văn bản toàn vẹn, niêm phong đúng ngày).
   Sai lệch dù chỉ 1 pixel ảnh: Báo đỏ lập tức: "CẢNH BÁO: Tệp tin đã bị chỉnh sửa sau thời điểm niêm phong!"
   Xác minh on-chain (0 gas qua eth_call):
   verifyAgreement(dateKey, hash, merkleProof) — chứng minh văn bản nằm trong cây Merkle đã neo (chuẩn OZ v5 double-hash).
   verifyReceipt(hash, dateKey, timestamp, nonce, signature) — xác thực biên nhận SCT với batchSigner (hoặc receiptSigner ban ngày).
   verifySchnorr(messageHash, R.x, parity, z) — xác thực chữ ký ngưỡng FROST2+ 64-byte qua kỹ thuật Alt-Schnorr (lõi xác minh ~5.000 gas, 0 gas khi gọi eth_call).
   Chi phí kiểm tra: 0 đồng (Sử dụng lệnh gọi đọc eth_call miễn phí).
   6.3. Tấm khiên Bảo vệ Tác giả: Tuyên bố Miễn trừ Trách nhiệm (Disclaimer)
   Để tác giả phần mềm không bị lôi vào các vụ kiện tụng dân sự ngoài đời, trang khởi tạo thỏa thuận bắt buộc hiển thị điều khoản:
   "CivilTrust là công cụ tiện ích công nghệ tự thân, mã nguồn mở. Nền tảng KHÔNG PHẢI là văn phòng công chứng và KHÔNG đóng vai trò là bên thứ ba bảo lãnh. Người dùng tự chịu trách nhiệm về tính xác thực của nội dung giao kết. Tác giả phần mềm được miễn trừ toàn bộ trách nhiệm dân sự và liên đới phát sinh từ các tranh chấp giữa các bên."
7. KIẾN TRÚC HỆ THỐNG TRỌN GÓI & DỰ TOÁN CHI PHÍ CỐ ĐỊNH (~74K/THÁNG)
   Toàn bộ hệ thống vận hành trên sự kết hợp giữa tài nguyên miễn phí và dịch vụ giá rẻ nội địa:
   ┌────────────────────────────────────────────────────────────────────────┐
   │                   HẠ TẦNG TOÀN DIỆN CỦA CIVILTRUST                     │
   ├────────────────────────────────────────────────────────────────────────┤
   │ 1. Client Layer: Cloudflare Pages (Hosting PWA tĩnh - Miễn phí)        │
   │ 2. Compute Layer: Cloudflare Workers (API & Cronjob 23:59 - Miễn phí)   │
   │ 3. Buffer Database: Cloudflare D1 (Lưu hash tạm trong ngày - Miễn phí) │
   │ 4. Backup Auditor: Bun 1.4 VPS + SQLite (WAL) — gossip + failover 00:05│
   │ 5. Notary Signing: FROST2+ 2-of-3 (sk_1 CF · sk_2 VPS · sk_3 Cold/0đ)  │
   │ 6. Media Storage: Viettel IDC S3 Private Bucket (30.000 VNĐ / tháng)   │
   │ 7. Blockchain Layer: Arbitrum One — CivilTrustRegistry v1.4.0 (~24.000 VNĐ / tháng) │
   │ 8. Tên miền quốc tế/Việt Nam: Duy trì hàng năm (~20.000 VNĐ / tháng)   │
   └────────────────────────────────────────────────────────────────────────┘

   Tầng ký ngưỡng FROST2+ 2-of-3 (v1.4.0 — ADR-0013)
   [CLIENT: BÊN A & BÊN B] ──► POST /api/v1/agreements/submit (chỉ gửi hash 32 bytes)
   │
   ┌─────────────────────────────┴─────────────────────────────┐
   │            FROST2+ CLUSTER (Ngưỡng 2-of-3)                │
   ▼                                                           ▼
   ┌──────────────────┐    ┌───────────────────────────────┐   ┌──────────────────┐
   │  NODE 1 (Primary)│    │       COLD SHARE (sk_3)       │   │  NODE 2 (Backup) │
   │ Cloudflare Edge  │    │ Khóa Lạnh Dự Phòng Thảm Họa   │   │  Bun 1.4 VPS     │
   │ Giữ Share sk_1   │    │ (Két sắt / USB Mã Hóa / 0đ)   │   │  Giữ Share sk_2  │
   └─────────┬────────┘    └───────────────────────────────┘   └────────┬─────────┘
   └───────────────────────────┬────────────────────────────────┘
   │
   [VÒNG 1: PRE-COMPUTATION OFFLINE]
   • Sinh sẵn Pool 5.000 Token (R, S, u, V)
   • Batch Verify theo Paper FROST2+ (TS-SUF-4)
   │
   [VÒNG 2: REALTIME ONLINE SIGNING]
   • z_i = r_i + d*s_i + c*λ_i*sk_i  (CPU < 1 ms)
   • Trả về 1 chữ ký Schnorr gộp duy nhất: (R, z) 64 Bytes
   │  (< 25ms tổng RTT)
   ▼
   ┌─────────────────────────────────────────┐
   │ SCT Receipt: 1 Schnorr Signature (64B) │
   │ Nhúng vào QR Code PDF (Client-Side DA)  │
   └─────────────────────────────────────────┘
   │
   (23:59 UTC Cuối ngày)
   ▼
   ┌─────────────────────────────────────────┐
   │       ARBITRUM ONE SMART CONTRACT       │
   │ anchorDailyRoot với Alt-Schnorr Verifier│
   │ (~100.000 gas ≈ 800 VNĐ/ngày)          │
   └─────────────────────────────────────────┘

   Mô hình "Ký Phân Tầng" (Layered Notary): Ban ngày, node biên (Cloudflare) ký biên nhận SCT cục bộ bằng receiptSigner (< 1ms) — kể cả khi đứt kết nối tới VPS, tiến trình ký FaceID của người dân vẫn hoạt động bình thường. anchorDailyRoot chỉ chấp nhận khóa nhóm batchSigner — khóa cấp biên nhận không bao giờ có quyền anchor.
   Sinh khóa CKG (Centralized Key Generation): Shamir Secret Sharing tách Master Key thành sk_1 (Cloudflare Secret), sk_2 (VPS .env), sk_3 (cold share offline), sau đó zeroize RAM. Script keygen nằm trong lộ trình service/scripts/keygen-ckg.ts.
   Chi phí hạ tầng phát sinh: 0đ — cold share cất két sắt/USB, không cần server online.
   Bảng Hạch toán Chi phí Vận hành Thực tế (Không phát sinh chi phí ẩn):
   Hạng mục hạ tầng
   Đơn vị cung cấp
   Thông số kỹ thuật
   Chi phí hàng tháng
   Lưu trữ Ảnh & PDF
   Viettel IDC
   50GB Object Storage, Private ACL, 250GB băng thông
   30.000 VNĐ
   Phí Gas Blockchain
   Arbitrum One (L2)
   1 transaction Merkle Root / ngày (~100.000 gas)
   ~24.000 VNĐ
   Duy trì Tên miền
   Nhà đăng ký tên miền
   Tên miền .com hoặc .vn (chia đều 12 tháng)
   ~20.000 VNĐ
   Frontend & API Host
   Cloudflare
   Pages + Workers (Free Tier 100.000 req/ngày)
   0 VNĐ
   Database đệm
   Cloudflare
   D1 Serverless SQL (Free Tier)
   0 VNĐ
   TỔNG CHI PHÍ VẬN HÀNH
   Trọn gói toàn bộ hệ thống
   Phục vụ tối đa ~50.000 hợp đồng
   ~74.000 VNĐ / tháng
   Ghi chú: Chi phí VPS cho node Backup Auditor (Bun 1.4 + SQLite WAL) tùy nhà cung cấp — có thể tận dụng VPS cá nhân sẵn có, không tính vào bảng trên.
8. MÔ HÌNH VẬN HÀNH & KINH DOANH (TIỆN ÍCH CỘNG ĐỒNG & DONATION)
   Hoàn toàn Miễn phí (Free Public Utility):
   Người dùng không phải trả bất kỳ khoản phí nào để tạo thỏa thuận, ký FaceID, đối soát VietQR, xuất PDF và tra cứu chứng thực.
   Mô hình "Mời tôi ly cà phê" (VietQR Donation):
   Trên trang xuất file PDF và trang tra cứu kết quả, hiển thị một góc nhỏ trang nhã:
   "CivilTrust là dự án tiện ích công cộng phi lợi nhuận. Nếu ứng dụng này giúp bạn bảo vệ được tài sản và tiền cọc nhà, bạn có thể ủng hộ tác giả 1 ly cà phê qua VietQR: [Mã QR ngân hàng cá nhân]."
   Lợi ích Pháp lý Tuyệt đối:
   Không kinh doanh, không thu phí dịch vụ: Không cần thành lập doanh nghiệp, không cần xin giấy phép sàn thương mại điện tử, không cần kế toán báo cáo thuế định kỳ.
   Tiền donate cá nhân tự nguyện là hợp pháp, chuyển thẳng vào tài khoản ngân hàng của bạn mà không tốn công quản trị.
9. ĐÁNH GIÁ TỔNG KẾT & TÍNH KHẢ THI
   Tiêu chí
   Đánh giá kiến trúc CivilTrust 3.1
   Tính Nhàn hạ (Idle / Set & Forget)
   Tuyệt đối: Không cần canh ví gas, không polling ngầm, không bảo trì server. Code xong deploy là vứt đấy.
   Ngân sách Khả thi
   ~74.000 VNĐ / tháng: Nằm gọn trong mức chi trả cá nhân (< 100k/tháng), không có chi phí biến đổi bất ngờ.
   Tuân thủ Pháp luật Việt Nam
   100%: Zero-PII (Nghị định 13), chữ ký FaceID phần cứng (Luật GDĐT 2023), VietQR thật (QĐ 2345/NHNN), media nội địa tại Viettel IDC.
   Bảo mật Khóa Notary
   TS-SUF-4: Cụm ngưỡng FROST2+ 2-of-3 — loại bỏ hoàn toàn điểm chết đơn lẻ (SPOF), kháng tấn công Rogue Nonce, chữ ký gộp 64-byte cố định.
   Tính Độc lập (Antifragile)
   Bất tử: Không phụ thuộc Zalo API, SePay hay bất kỳ bên thứ ba nào. Kể cả bạn bỏ quên dự án nhiều năm, chứng cứ trên sổ cái Arbitrum vẫn tra cứu được vĩnh viễn.
10. HIỆN TRẠNG MÃ NGUỒN REPO (07/10/2026) & KHOẢNG CÁCH TRIỂN KHAI
    Thành phần
    Trạng thái
    Ghi chú
    contracts/ — CivilTrustRegistry v1.4.0
    Đã hoàn thành (chưa deploy)
    Solidity 0.8.36 · Foundry · OpenZeppelin v5.3.0 · AGPL-3.0. Đã có verifySchnorr (Alt-Schnorr), receiptSigner, dual-scheme ECDSA/Schnorr. Test: 42 unit + 25 Schnorr + fuzz + invariant. Version "unreleased", deployments/*.json còn trống — chưa có địa chỉ mainnet.
    service/ — Notary Service v1.3.0
    Đã triển khai (v1.3.0)
    Bun 1.4 · Hono · Viem · Zod · D1/SQLite WAL. Đủ API v1 (submit/proof/status/recover/sync/health), cron anchor + failover, SCT < 50ms, self-healing. Hỗ trợ sẵn RECEIPT_SIGNER_PRIVATE_KEY (layered notary).
    FROST2+ phía service
    Trong lộ trình
    src/core/crypto/ hiện có merkle.ts, eip712.ts, sct.ts — module frost2plus.ts và script keygen-ckg.ts chưa được implement (Lộ trình GĐ 1–2 của docs/frost2plus-architecture-v140.md).
    app/ — Client PWA
    Chưa có mã nguồn
    Repo git đã khởi tạo (remote CivilTrust/app.git) nhưng chưa có nội dung — toàn bộ UX mục 3 (FaceID WebAuthn, nén ảnh WebP, VietQR, NFC CCCD) đang ở dạng thiết kế.
    docs/
    Đầy đủ
    frost2plus-architecture-v140.md (tiếng Việt) + 2 paper học thuật (FROST2+ của Solv Protocol; Flock). ADR-0001 → ADR-0013 trong contracts/docs/decisions/.
    Ưu tiên tiếp theo: (1) implement service/src/core/crypto/frost2plus.ts + keygen-ckg.ts; (2) benchmark độ trễ < 50ms & test mô phỏng tấn công Rogue Nonce; (3) deploy CivilTrustRegistry v1.4.0 lên Arbitrum Sepolia → One; (4) dựng client PWA.
    Bản đặc tả kiến trúc này là kim chỉ nam hoàn chỉnh nhất: vừa đảm bảo chuẩn mực công nghệ mật mã đỉnh cao (FROST2+ TS-SUF-4, Alt-Schnorr, Client-Side DA), vừa an toàn pháp lý tuyệt đối, lại tối ưu xuất sắc cho một nhà phát triển độc lập muốn tạo ra giá trị bền vững cho xã hội.
-->
# CivilTrust App — Đặc tả ứng dụng hợp đồng điện tử có xác minh CCCD gắn chip

> Trạng thái tài liệu: bản đặc tả triển khai ban đầu, được viết dựa trên mã nguồn hiện có trong `contracts/` và `service/` ngày 09/10/2026.  
> Phạm vi của nhóm app: ứng dụng người dùng, đọc NFC CCCD, lập và ký hợp đồng, tạo bằng chứng phía khách hàng, gọi Notary Service và hiển thị kết quả kiểm chứng.  
> Ngoài phạm vi: sửa smart contract, sửa Notary Service, tự tuyên bố giá trị “công chứng” hoặc thay thế cơ quan có thẩm quyền.

## 1. Tóm tắt sản phẩm

CivilTrust là hệ thống chứng thực tính toàn vẹn và thời điểm tồn tại của hợp đồng điện tử theo mô hình lai:

1. Ứng dụng đọc CCCD gắn chip qua NFC và xử lý thông tin định danh cục bộ.
2. Các bên xem lại hợp đồng và thực hiện một hành động ký/xác nhận ý chí riêng biệt.
3. Ứng dụng đóng băng một bản tài liệu chuẩn, tính `keccak256` trên đúng chuỗi byte đó và gửi duy nhất hash lên Notary Service.
4. Service trả về Signed Commitment Token (SCT) ngay lập tức và đưa hash vào lô Merkle trong ngày.
5. Cuối ngày, service neo Merkle root lên `CivilTrustRegistry` trên Arbitrum.
6. Người kiểm tra có thể xác minh SCT tức thời và, sau khi lô được neo, xác minh Merkle proof với smart contract.

Blockchain không lưu họ tên, số CCCD, ảnh chân dung, nội dung hợp đồng hay chữ ký của các bên. Smart contract chỉ biết hash tài liệu, Merkle root, số lượng tài liệu, mốc thời gian neo và các khóa notary.

### Tình huống sử dụng ưu tiên

- Thuê trọ hoặc bàn giao mặt bằng: điều khoản đặt cọc, hiện trạng, công tơ và ảnh bàn giao.
- Vay mượn cá nhân: số tiền, thời hạn, lãi suất nếu có và bằng chứng chuyển khoản do người dùng đính kèm.
- Mua bán đồ cũ có đặt cọc: mô tả tài sản, điều kiện giao nhận và hoàn/hủy cọc.
- Mượn tài sản hoặc thuê xe: tình trạng tài sản, số km, phụ kiện và ảnh trước/sau bàn giao.

Ảnh hiện trường là phần tùy chọn của artifact. App có thể giới hạn 3–5 ảnh, resize/nén WebP ở client và cấm video trong MVP để kiểm soát dung lượng. VietQR chỉ là tiện ích tạo nội dung chuyển khoản; app không được tự tuyên bố đã thanh toán nếu chưa có xác nhận độc lập. Bản xác nhận “đã nhận tiền” phải là một sự kiện được bên nhận ký riêng và đưa vào revision/bằng chứng kế tiếp.

## 2. Phạm vi và ranh giới trách nhiệm

### 2.1. App chịu trách nhiệm

- Giao diện lập, xem lại, ký và quản lý hợp đồng.
- Điều phối phiên giao dịch giữa các bên.
- Đọc CCCD qua NFC trên thiết bị hỗ trợ và kiểm tra dữ liệu đọc được ở mức SDK/protocol cho phép.
- Xin đồng ý rõ ràng trước khi đọc, sử dụng hoặc lưu dữ liệu CCCD.
- Chuẩn hóa tài liệu, tạo PDF/bằng chứng ký và tính hash hoàn toàn ở thiết bị.
- Gọi API `submit`, `status`, `proof`, `recover` của service.
- Lưu cục bộ tài liệu gốc, SCT và bằng chứng của các bên; xuất gói bằng chứng để có thể kiểm tra độc lập.
- Gọi RPC/read-only contract hoặc thư viện `viem` tương đương để kiểm tra SCT và Merkle proof nếu triển khai chức năng xác minh độc lập.

### 2.2. Service hiện có chịu trách nhiệm

- Nhận `agreementHash` 32 byte; không nhận nội dung PDF hay PII.
- Ký và trả SCT EIP-712.
- Lưu các hash đang chờ, gom lô theo `dateKey`, dựng Merkle tree và gửi giao dịch neo root.
- Trả trạng thái và Merkle proof.
- Nhận SCT/QR payload để phục hồi bản ghi bị mất.

### 2.3. Smart contract hiện có chịu trách nhiệm

- Lưu bất biến một Merkle root cho mỗi `dateKey` khác 0.
- Xác minh chữ ký notary của batch và receipt.
- Xác minh một `agreementHash` thuộc lô đã neo bằng Merkle proof.
- Cung cấp lịch sử lô, tổng số hợp đồng và cơ chế quản trị signer/pause.

### 2.4. Những điều hệ thống không tự chứng minh

- NFC không tự chứng minh chủ thẻ đã tự nguyện ký hợp đồng.
- Hash/Merkle proof chỉ chứng minh đúng chuỗi byte đã được cam kết; không tự chứng minh nội dung hợp pháp, năng lực hành vi hay danh tính ngoài đời của người ký.
- SCT là chữ ký của notary service trên một receipt, không phải chữ ký của hai bên hợp đồng.
- Mốc `anchoredAt` là thời điểm batch được ghi lên chain, không nhất thiết là thời điểm hai bên ký. Thời điểm receipt nằm trong SCT nhưng do service phát hành.
- Dự án là hệ thống chứng thực kỹ thuật, không nên dùng từ “công chứng” theo nghĩa pháp lý nếu chưa có căn cứ và chủ thể có thẩm quyền.

## 3. Quyết định nền tảng cho NFC CCCD

Không nên triển khai đọc chip CCCD bằng một website thuần túy. Web NFC hiện chỉ nằm trong phạm vi NDEF và không hỗ trợ thao tác mức thấp như ISO-DEP/NFC-A/B; trong khi đọc thẻ thông minh cần trao đổi APDU. Vì vậy kiến trúc đề xuất là:

- **Ứng dụng mobile native hoặc cross-platform có native bridge** cho luồng đọc CCCD: Android dùng `IsoDep`; iOS dùng Core NFC/`NFCISO7816Tag` nếu entitlement, AID và loại thẻ được hỗ trợ.
- **Web/PWA** dùng cho soạn hợp đồng, tra cứu và kiểm chứng nếu không cần trực tiếp đọc chip.
- Có thể dùng một codebase giao diện Flutter hoặc React Native, nhưng phần NFC phải là native module/SDK phù hợp; không giả định plugin NDEF phổ thông có thể đọc CCCD.

Tài liệu nền tảng tham khảo:

- W3C Web NFC: <https://w3c.github.io/web-nfc/>
- Android `IsoDep`: <https://developer.android.com/reference/android/nfc/tech/IsoDep>
- Apple `NFCISO7816Tag`: <https://developer.apple.com/documentation/corenfc/nfciso7816tag>

Việc truy cập dữ liệu thật trên CCCD phụ thuộc protocol, khóa truy cập, cơ chế xác thực chip và/hoặc SDK được cấp quyền. MVP phải cô lập lớp `IdentityReader` để có thể dùng mock trong demo và thay bằng SDK hợp lệ mà không đổi domain logic.

## 4. Kiến trúc app đề xuất

```text
Mobile app / Web verifier
├── Presentation
│   ├── Onboarding & consent
│   ├── Contract editor/reviewer
│   ├── NFC scanning flow
│   ├── Party-signing ceremony
│   └── Status & verification screens
├── Application
│   ├── Agreement workflow/state machine
│   ├── Identity verification orchestration
│   ├── Canonicalization and hashing
│   ├── Evidence package builder
│   └── Service/chain verification orchestration
├── Domain
│   ├── AgreementDraft
│   ├── VerifiedIdentitySnapshot
│   ├── PartyConsentSignature
│   ├── CanonicalAgreement
│   ├── SignedCommitmentToken
│   └── VerificationResult
└── Infrastructure
    ├── Android IsoDep / iOS Core NFC adapter
    ├── Mock CCCD reader for development
    ├── Secure local storage
    ├── PDF renderer/parser
    ├── CivilTrust Service API client
    └── Arbitrum read-only client
```

Các interface tối thiểu:

```ts
interface IdentityReader {
  isSupported(): Promise<boolean>;
  readWithUserConsent(accessData: unknown): Promise<IdentityReadResult>;
  cancel(): Promise<void>;
}

interface AgreementCanonicalizer {
  buildCanonicalArtifact(input: FinalAgreementInput): Promise<Uint8Array>;
  hashKeccak256(bytes: Uint8Array): Promise<`0x${string}`>;
}

interface NotaryClient {
  submit(agreementHash: `0x${string}`): Promise<SignedCommitmentToken>;
  getStatus(agreementHash: `0x${string}`): Promise<AgreementStatus>;
  getProof(dateKey: number, agreementHash: `0x${string}`): Promise<MerkleProof>;
  recover(input: { sct?: SignedCommitmentToken; qrPayload?: string }): Promise<void>;
}
```

## 5. Luồng nghiệp vụ chính

### 5.1. Tạo và ký hợp đồng

1. Người khởi tạo chọn mẫu hoặc nhập nội dung hợp đồng.
2. App tạo `agreementSessionId` cục bộ; ID này không được coi là hash on-chain.
3. Bên A đọc CCCD, kiểm tra thông tin hiển thị, đồng ý phạm vi sử dụng dữ liệu.
4. Bên B thực hiện tương tự.
5. App hiển thị bản xem trước cuối cùng, điều khoản, danh tính đã xác minh và bản tóm tắt quyền riêng tư.
6. Mỗi bên thực hiện hành động ký/xác nhận riêng. MVP có thể dùng passkey/WebAuthn hoặc khóa thiết bị để ký digest; thao tác NFC không được thay cho bước này.
7. App tạo `CanonicalAgreement` bất biến, gồm nội dung, phiên bản schema, thông tin định danh cần thiết theo chính sách, cam kết danh tính và bằng chứng đồng ý/ký.
8. App render đúng một bản byte chuẩn và tính `agreementHash = keccak256(canonicalBytes)`.
9. App gọi `POST /api/v1/agreements/submit` với duy nhất `agreementHash`.
10. App kiểm tra SCT trả về: domain, chain ID, địa chỉ contract, message hash, chữ ký và signer phải phù hợp cấu hình tin cậy.
11. App lưu `canonicalBytes`, `agreementHash`, SCT và bằng chứng các bên vào secure storage; cho phép xuất file/gói bằng chứng.
12. App hiển thị trạng thái `Đã cấp biên nhận — chờ neo blockchain`.

### 5.2. Theo dõi và xác minh sau khi neo

1. App gọi `GET /api/v1/agreements/status/:hash` theo backoff, không polling liên tục.
2. Khi trạng thái là `batched`, app gọi `GET /api/v1/agreements/:dateKey/:hash/proof`.
3. App tự tính lại hash từ tài liệu được chọn.
4. App xác minh Merkle proof cục bộ và, nếu có RPC, gọi `verifyAgreement(...)` bằng `eth_call`.
5. Giao diện chỉ báo “hợp lệ” khi hash tài liệu, proof và root on-chain đồng nhất. Kết quả cần tách thành các mục thay vì một dấu kiểm mơ hồ:
   - tài liệu khớp hash;
   - SCT hợp lệ/không hợp lệ;
   - đã/chưa được neo;
   - Merkle proof hợp lệ/không hợp lệ;
   - địa chỉ contract và chain đang kiểm tra.

### 5.3. Kiểm chứng tài liệu của bên thứ ba

1. Người dùng chọn gói bằng chứng hoặc tài liệu cùng SCT.
2. App xử lý toàn bộ PII cục bộ và không upload tài liệu chỉ để kiểm tra.
3. App tính lại hash, đối chiếu SCT rồi lấy proof theo `dateKey`.
4. Nếu service không hoạt động nhưng gói bằng chứng đã chứa proof, app kiểm tra trực tiếp với Arbitrum RPC.
5. App tạo báo cáo kiểm chứng có thời điểm kiểm tra, chain ID, contract address, transaction hash và từng kết quả riêng biệt.

### 5.4. Phục hồi

1. App lấy raw SCT hoặc chuỗi `ct:sct:v1:...` từ gói bằng chứng.
2. App kiểm tra cấu trúc và chữ ký trước khi gửi.
3. App gọi `POST /api/v1/agreements/recover`.
4. Sau phục hồi, app phải đọc lại `status`; không tin tuyệt đối vào thông báo thành công của endpoint.

## 6. Quy tắc tạo tài liệu và tránh vòng lặp hash

Không được thực hiện chuỗi thao tác sai sau:

```text
hash PDF -> nhận SCT -> chèn QR/SCT vào PDF -> coi PDF mới là tài liệu đã được hash
```

Chèn QR làm thay đổi byte của PDF, vì vậy hash cũ không còn đại diện cho file mới. Chọn một trong hai mô hình sau:

### Mô hình khuyến nghị cho MVP: gói bằng chứng tách rời

```text
agreement.pdf              # byte bất biến được keccak256
evidence.civiltrust.json   # SCT, chữ ký các bên, metadata, proof khi có
verification-qr.png        # chứa SCT hoặc deep link, không sửa agreement.pdf
```

Có thể đóng ba file vào ZIP để tải/chia sẻ. Đây là mô hình đơn giản và ít mơ hồ nhất.

### Mô hình nâng cao: PDF container có revision gốc

Nếu bắt buộc một file PDF có QR, app phải định nghĩa chuẩn rõ ràng rằng hash áp dụng cho revision/tệp đính kèm gốc bên trong container, đồng thời verifier phải trích xuất chính xác byte gốc trước khi băm. Không được quảng bá hash đó là `keccak256` của toàn bộ PDF sau khi nhúng QR.

Quy tắc chuẩn hóa phải cố định phiên bản, ví dụ `civiltrust-agreement/v1`: encoding UTF-8, timezone UTC, thứ tự field xác định, không chứa thời gian render ngẫu nhiên, font được nhúng cố định và không render lại sau khi submit.

## 7. Mô hình dữ liệu phía app

```ts
type AgreementState =
  | "draft"
  | "identity_verification"
  | "ready_for_review"
  | "awaiting_party_signatures"
  | "canonicalized"
  | "committed_pending_anchor"
  | "batched"
  | "verification_failed";

interface IdentityReadResult {
  source: "cccd_nfc" | "mock";
  readAt: string;
  chipAuthentication?: "verified" | "not_verified" | "unsupported";
  fields: {
    documentNumber?: string;
    fullName?: string;
    dateOfBirth?: string;
    expiryDate?: string;
    portrait?: Uint8Array;
  };
  rawDataRetained: false;
}

interface LocalAgreementRecord {
  schemaVersion: "civiltrust-agreement/v1";
  state: AgreementState;
  canonicalFileUri: string;
  agreementHash: `0x${string}`;
  sct?: SignedCommitmentToken;
  proof?: {
    dateKey: number;
    merkleRoot: `0x${string}`;
    merkleProof: `0x${string}`[];
    txHash: `0x${string}`;
    anchoredAt: number;
  };
}
```

Không lưu APDU log, raw chip dump, ảnh hoặc số CCCD vào log ứng dụng, analytics, crash report, URL, clipboard hay service CivilTrust. Nếu nghiệp vụ buộc phải lưu PII trong tài liệu, file phải nằm trong vùng mã hóa của ứng dụng và chỉ xuất khi người dùng chủ động.

## 8. Tích hợp với API hiện có

### 8.1. Submit

```http
POST /api/v1/agreements/submit
Content-Type: application/json

{"agreementHash":"0x<64 hex>"}
```

- Bản ghi mới: HTTP `201`, `data.status = "committed_pending_anchor"`.
- Hash đã tồn tại: HTTP `200`, trả SCT cũ và trạng thái `pending`/`batched`.
- App phải chấp nhận cả `200` và `201` là thành công mang tính idempotent.

### 8.2. Status

```http
GET /api/v1/agreements/status/:hash
```

Trạng thái service hiện chỉ có `pending` hoặc `batched`. `404` có nghĩa service hiện tại không có bản ghi, không đủ để kết luận hash chưa từng được neo trên chain.

### 8.3. Proof

```http
GET /api/v1/agreements/:dateKey/:hash/proof
```

Proof chỉ có sau khi batch và `leaves_json` còn khả dụng trong storage của service. App phải kiểm tra proof thay vì chỉ tin JSON response.

### 8.4. Recover

```http
POST /api/v1/agreements/recover
Content-Type: application/json

{"qrPayload":"ct:sct:v1:<base64>"}
```

App không gọi endpoint `/internal/v1/sync`; đây là API nội bộ yêu cầu bearer secret.

## 9. Tích hợp trực tiếp với contract

Cấu hình tin cậy của app phải ghim theo môi trường:

- `chainId`: Arbitrum One `42161` hoặc Arbitrum Sepolia `421614`.
- `registryContract`: địa chỉ deployment thật.
- EIP-712 domain: name `CivilTrustRegistry`, version `1`.
- ABI đọc tối thiểu: `verifyReceipt`, `verifyAgreement`, `batches`, `batchSigner`, `receiptSigner`, `VERSION`.

Không lấy `chainId`, contract address hoặc signer từ SCT rồi mặc nhiên tin chúng. SCT là dữ liệu không tin cậy cho đến khi domain được đối chiếu với cấu hình app và chữ ký được xác minh với signer hiện hành/được chấp nhận.

Lưu ý khóa signer có thể được owner rotate. Việc dùng duy nhất signer hiện tại để xác minh receipt lịch sử có thể làm receipt cũ không còn xác minh được bằng `verifyReceipt`. App nên lưu bằng chứng, block/time và signer đã dùng; yêu cầu backend/contract xác định chính sách xác minh lịch sử trước khi tuyên bố hỗ trợ lâu dài.

## 10. Màn hình tối thiểu

1. **Trang chủ:** tạo hợp đồng, mở gói bằng chứng, danh sách cục bộ.
2. **Soạn hợp đồng:** mẫu, điều khoản, dữ liệu bắt buộc, autosave draft.
3. **Đọc CCCD:** giải thích quyền riêng tư, nhập dữ liệu truy cập nếu cần, trạng thái NFC, retry/cancel.
4. **Kết quả danh tính:** trường đã đọc, trạng thái xác thực chip, xác nhận của người dùng.
5. **Rà soát cuối:** preview byte/tài liệu cuối, hash rút gọn, cảnh báo mọi sửa đổi sẽ đổi hash.
6. **Ký của từng bên:** trạng thái Bên A/B, phương thức ký, thời điểm, lỗi hoặc hủy.
7. **Biên nhận:** SCT, `dateKey`, timestamp, signer, trạng thái chờ neo, nút xuất gói bằng chứng.
8. **Theo dõi:** pending/batched, transaction link, thời điểm neo.
9. **Kiểm chứng:** chọn file, tính hash, kiểm SCT, lấy/kiểm proof, hiển thị từng kết quả.
10. **Cài đặt kỹ thuật:** môi trường testnet/mainnet, RPC, contract address chỉ đọc; không hiển thị private key.

## 11. Yêu cầu bảo mật và quyền riêng tư

- NFC chỉ bắt đầu sau thao tác rõ ràng và consent; tự dừng khi app background, timeout hoặc người dùng hủy.
- Xóa buffer NFC/raw bytes ngay sau khi trích xuất trường cần thiết.
- Mã hóa dữ liệu nhạy cảm at rest bằng Android Keystore/iOS Keychain và khóa file theo thiết bị/người dùng.
- Không dùng số CCCD làm khóa chính, tên file, telemetry ID hoặc nonce.
- Không gửi PII vào service, blockchain RPC, Sentry/Firebase logs hay query string.
- Không tin dữ liệu từ QR, SCT, PDF metadata hoặc API trước khi validate schema, độ dài và chữ ký.
- Ghim môi trường/contract và chống nhầm mainnet-testnet.
- Chống double-submit ở UI nhưng vẫn dựa vào tính idempotent của API.
- Có giới hạn kích thước file, timeout, retry có backoff và trạng thái offline rõ ràng.
- Các private key của notary/relayer tuyệt đối không nằm trong app. App chỉ có khóa người dùng/passkey nếu thiết kế yêu cầu.
- Chức năng hiển thị ảnh/PII phải chống screenshot theo khả năng nền tảng và có nút xóa dữ liệu cục bộ.

## 12. Tiêu chí nghiệm thu MVP

- Chạy được luồng mock CCCD đầy đủ trên emulator; adapter NFC thật thay thế được qua cùng interface.
- Thiết bị không có NFC hoặc người dùng từ chối quyền vẫn có thông báo và đường lui hợp lý.
- Hai bên phải có bước xác nhận/ký độc lập sau khi xem bản cuối.
- Cùng một input chuẩn luôn sinh đúng cùng byte và cùng `keccak256` trên Android/iOS/web verifier.
- Sau submit, file canonical không thể bị app sửa âm thầm.
- App phát hiện thay đổi một byte của tài liệu và báo hash không khớp.
- App kiểm được SCT với domain/signer tin cậy, không chỉ hiển thị `success` từ API.
- App xử lý đúng cả response submit `200` và `201`.
- App hiển thị `pending`, lấy được proof khi `batched`, và tự kiểm proof.
- Không có PII trong request gửi tới service/RPC hoặc log debug bản release.
- Xuất và nhập lại gói bằng chứng trên thiết bị khác mà vẫn tính được cùng hash.
- Có test vector dùng chung giữa app, service và Solidity cho hash, EIP-712 và Merkle proof.

## 13. Kế hoạch triển khai đề xuất

### Giai đoạn 1 — Vertical slice không NFC thật

- Mock hai CCCD, tạo hợp đồng, ký/xác nhận, canonicalize, hash, gọi service testnet, lưu SCT.
- Làm màn hình status/proof và verifier cục bộ.
- Chốt format `civiltrust-agreement/v1` và `evidence.civiltrust.json`.

### Giai đoạn 2 — NFC adapter

- Tích hợp Android trước vì `IsoDep` cho phép APDU ở native layer.
- Tích hợp SDK/protocol CCCD được phép sử dụng; thêm kiểm tra chip/authenticity nếu khả dụng.
- Sau đó đánh giá iOS theo Core NFC entitlement/AID và khả năng tương thích thực tế.

### Giai đoạn 3 — Ký của các bên và hardening

- Passkey/WebAuthn hoặc khóa phần cứng của thiết bị ký digest của canonical artifact.
- Secure storage, consent/audit local, redaction log, threat tests và test thiết bị thật.

### Giai đoạn 4 — Demo blockchain hoàn chỉnh

- Deploy contract lên Arbitrum Sepolia, cấu hình D1/service thật, chạy cron hoặc trigger test.
- Chứng minh cả receipt trước khi neo và Merkle proof sau khi neo.
- Xuất báo cáo kiểm chứng độc lập.

## 14. Trạng thái phụ thuộc hiện tại và các điểm cần khóa với thành viên backend

| Hạng mục | Trạng thái quan sát từ code | Ảnh hưởng tới app |
|---|---|---|
| Contract core | Đã có triển khai v1.4.0 và test unit/fuzz/invariant | Có thể xây ABI đọc, nhưng chưa có địa chỉ deployment |
| Deployment | JSON deployment đang trống; changelog ghi `TBD` | Chưa thể ghim contract thật |
| Service API | Đã có routes submit/status/proof/recover/health/sync | Có thể viết client theo schema hiện tại |
| Service runtime config | `wrangler.jsonc` còn D1 ID và contract zero-address | Chưa sẵn sàng deploy nguyên trạng |
| Version | Contract `1.4.0`, service/SCT `1.3.0` | App phải version hóa riêng và không suy diễn hai version giống nhau |
| Signature scheme | Contract nhận ECDSA và FROST2+; service hiện ký ECDSA | App MVP nên hỗ trợ ECDSA trước, thiết kế parser mở rộng cho 64/65-byte Schnorr |
| Party signatures | Service/contract không lưu và không kiểm | App phải tự tạo/lưu/kiểm bằng chứng ký của các bên |
| Identity | Backend cố ý Zero-PII | Toàn bộ NFC/PII phải ở client |
| Existing-submit SCT | Nhánh trả bản ghi cũ hiện không trả field `signer` | App cần tolerant parsing hoặc backend thống nhất response trước tích hợp chính thức |
| Recovery pending | Record `pending` đã tồn tại không được chuyển sang `targetDateKey` mới | App phải đọc lại status; self-healing hiện chưa bảo đảm đúng như mô tả |
| Historical signer | Contract xác minh receipt bằng signer hiện tại | Cần chốt chính sách khi rotate key |
| PDF + QR | Tài liệu nói nhúng SCT vào PDF sau khi hash nhưng chưa định nghĩa canonical revision | MVP dùng evidence package tách rời |

## 15. Câu hỏi tích hợp cần được nhóm thống nhất

1. `agreementHash` áp dụng cho file PDF gốc, canonical JSON hay một evidence manifest?
2. Chữ ký của Bên A/B dùng passkey, chữ ký số PKI, hay chỉ là xác nhận trong app?
3. Trường CCCD nào thật sự cần đưa vào hợp đồng, trường nào chỉ dùng để đối chiếu rồi xóa?
4. SDK/quyền truy cập nào được phép dùng để đọc và xác thực chip CCCD trên Android/iOS?
5. Địa chỉ contract Sepolia, batch signer và receipt signer chính thức là gì?
6. App sẽ xác minh receipt lịch sử thế nào sau khi rotate signer?
7. Service có bổ sung endpoint trả cấu hình công khai/ABI/signer hay app ghim cấu hình theo release?
8. Có yêu cầu nhiều thiết bị/từ xa cho hai bên hay MVP ký tuần tự trên một thiết bị?
9. Gói bằng chứng có cần mã hóa cho từng bên và cơ chế chia sẻ khóa ra sao?
10. “Thành công” trong demo là receipt tức thời, batch on-chain, hay phải có cả hai?

## 16. Định nghĩa hoàn thành cho phần app

Phần app được coi là hoàn thành khi một người dùng có thể tạo hợp đồng, hai bên đọc CCCD và ký/xác nhận riêng biệt, app sinh artifact bất biến, chỉ gửi hash ra ngoài, nhận và tự kiểm SCT, theo dõi đến khi batch được neo, tự kiểm Merkle proof với đúng contract, xuất được gói bằng chứng, và nhập lại gói đó trên thiết bị khác để tái lập kết quả mà không cần gửi PII lên backend.
