
# Overview

# TÀI LIỆU ĐẶC TẢ KIẾN TRÚC DỰ ÁN: CIVILTRUST (GIAO KÈO SỐ)

**Phiên bản:** 3.1 (Kiến trúc Set-and-Forget / Public Good Edition)

**Đồng bộ mã nguồn (07/10/2026):** `contracts` v1.4.0 (FROST2+ Threshold Schnorr) · `service` v1.3.0 · `app` chưa có mã nguồn · tài liệu tham chiếu: `docs/frost2plus-architecture-v140.md`, ADR-0001 → ADR-0013.

**Mục tiêu vận hành:** Hệ thống tự chạy 100% không cần quản trị (Idle), chi phí cố định ~74.000đ/tháng, không thành lập công ty, không phụ thuộc API trung gian, bảo mật dữ liệu tuyệt đối theo Nghị định 13/2023/NĐ-CP.

---

## 1. TỔNG QUAN DỰ ÁN (EXECUTIVE SUMMARY)

- **Tên dự án:** **CivilTrust** – Nền tảng Xác thực & Lưu vết Thỏa thuận Dân sự P2P.
- **Định vị sản phẩm:** Tiện ích số công cộng (Free Public Utility / Open-source Tool) giúp người dân tự tạo lập chứng cứ pháp lý số chống chối bỏ cho các giao dịch đời sống (thuê trọ, vay mượn cá nhân, cọc mua bán, bàn giao tài sản).
- **Triết lý sản phẩm cốt lõi:**
  1. **Tiền mặt VND đi qua app Ngân hàng (VietQR):** Không phát hành token, không custody (giữ tiền) của người dùng, không dính dáng quy định tiền mã hóa.
  2. **File PDF là Chứng cứ Tự thân (Self-Contained Artifact):** Giá trị pháp lý nằm ngay trong tệp tài liệu số mang chữ ký phần cứng FaceID (WebAuthn trên đường cong NIST P-256) của hai bên theo Luật Giao dịch điện tử 2023, kèm biên nhận **SCT (Signed Commitment Token)** nhúng trong QR/metadata (`ct:sct:v1:...`).
  3. **Đóng dấu hàng loạt 1 lần/ngày (Daily Merkle Anchor):** Không gửi giao dịch lắt nhắt lên chain. Gom toàn bộ giao kèo trong ngày thành 1 Cây Merkle và đóng dấu đúng **1 giao dịch duy nhất** vào 23:59 UTC trên Arbitrum One (~100.000 gas ≈ 800 VNĐ/ngày ≈ ~24.000đ/tháng tiền gas, bất kể số lượng hợp đồng).
  4. **Kiến trúc Tự thân (Zero-Middleman):** Tận dụng tính năng có sẵn của hệ điều hành điện thoại (Native OS Share, Camera QR, NFC CCCD). Không dùng Zalo API, không mua SMS Brandname, không thuê cổng SePay/Casso.
  5. **Zero-PII & Lưu trữ Nội địa An toàn:** Tầng service tuyệt đối chỉ xử lý mã băm 32-byte (`keccak256(PDF)`) — không tên, không CCCD, không nội dung tài liệu. Dữ liệu nhạy cảm (ảnh/PDF) thuộc tầng media lưu tại Data Center trong nước (Viettel IDC), tuân thủ Nghị định 13/2023/NĐ-CP.
  6. **Mô hình Set-and-Forget (Làm xong vứt đấy):** Deploy lên hạ tầng Serverless Cloudflare (0đ) + Arbitrum (~800đ/ngày tiền gas). Tác giả không tốn công quản trị, không sợ biến động chi phí.
  7. **Không Điểm Chết Đơn Lẻ (v1.4.0):** Hạ tầng ký notary nâng cấp từ 1 private key lên **cụm ngưỡng FROST2+ 2-of-3 (chuẩn TS-SUF-4)**, chữ ký Schnorr gộp 64-byte cố định, xác minh on-chain bằng kỹ thuật Alt-Schnorr (0 gas qua `eth_call`).

---

## 2. ĐỐI TƯỢNG & TÌNH HUỐNG SỬ DỤNG (USE CASES)

1. **Thuê trọ / Bàn giao mặt bằng:** Người thuê và chủ nhà ký xác nhận hiện trạng phòng (ảnh tường nứt, đồ đạc cũ, chỉ số công tơ điện nước) + Điều kiện hoàn cọc.
2. **Cho vay mượn cá nhân (Giấy nợ số - IOU):** Xác nhận việc vay tiền, số tiền, ngày hẹn trả, lãi suất (nếu có), đính kèm mã chuyển khoản ngân hàng thật.
3. **Mua bán đồ cũ P2P có cọc (Chợ Tốt, Facebook Marketplace):** Khóa thỏa thuận cọc chuyển hàng, tránh tình trạng bom hàng hoặc lừa tiền cọc.
4. **Mượn tài sản / Thuê xe tự lái:** Ghi nhận hiện trạng vết xước, số km trên đồng hồ trước khi lăn bánh.

---

## 3. THIẾT KẾ TRẢI NGHIỆM NGƯỜI DÙNG TỰ THÂN (ZERO-MIDDLEMAN UX)

Toàn bộ quy trình diễn ra trực tiếp giữa 2 người dùng (P2P), đồng bộ trạng thái tinh gọn:

```
[BƯỚC 1: KHỞI TẠO] ──► [BƯỚC 2: KÝ SỐ P2P] ──► [BƯỚC 3: ĐỒNG BỘ TRẠNG THÁI] ──► [BƯỚC 4: DÒNG TIỀN THỰC] ──► [BƯỚC 5: TẢI PDF TỰ THÂN]
  Chụp 3-5 ảnh WebP      Native Share / QR        B gửi 1 POST                    Chuyển khoản VietQR        PDF + QR SCT nhúng sẵn
  + Đọc NFC CCCD         FaceID (Passkey P-256)   /api/v1/agreements/submit       Xác nhận "Đã nhận tiền"    (23:59 UTC chốt Merkle Root)
  (tùy chọn chính danh)  (chữ ký phần cứng)       A gọi GET .../status/:hash      (chữ ký FaceID 2 chiều)    Khôi phục qua /recover nếu cần
```

### Bước 1: Khởi tạo Thỏa thuận & Nén Ảnh Cục bộ (1 phút)

- Bên A mở Web App (PWA) trên trình duyệt điện thoại:
  - Nhập tóm tắt điều khoản (ví dụ: *"A nhận cọc thuê phòng 302 giá 2.000.000đ của B, báo trước 30 ngày hoàn cọc"*).
  - Chụp **tối đa 3 – 5 ảnh hiện trường trực tiếp từ camera app** (Cấm tuyệt đối tải video để tránh đầy bộ nhớ).
  - **Thuật toán nén ảnh Client-side:** PWA tự động resize ảnh về chuẩn HD (1280x720) và chuyển đổi sang định dạng WebP (chất lượng 0.7). Mỗi ảnh chỉ tốn ~80KB – 120KB. Toàn bộ file PDF gồm text và 5 ảnh **chưa tới 1MB**.
  - *(Tùy chọn chính danh):* Áp thẻ **CCCD gắn chip** vào lưng máy để đọc NFC (chuẩn ICAO 9303), lấy chữ ký số của **Cục C06 - Bộ Công An**. Toàn bộ xử lý chính danh diễn ra **phía client bằng WebCrypto** — không có bất kỳ PII nào được gửi lên blockchain hay server (ADR-0011).

### Bước 2: Ký số Hai chiều & Chia sẻ P2P Không Tốn Phí

- Bên A quét FaceID: Chip bảo mật điện thoại (Secure Enclave / TEE) tạo chữ ký mật mã phần cứng **WebAuthn (NIST P-256)**.
- **Chia sẻ trực tiếp:**
  - *Gặp trực tiếp:* Màn hình máy A hiện mã QR, máy B bật camera quét thẳng.
  - *Gặp từ xa:* Máy A bấm nút "Gửi", gọi bảng chia sẻ hệ điều hành (**Native OS Web Share Sheet**). Máy A tự chọn gửi link qua Zalo, Messenger, Telegram hay SMS cá nhân.
- **Bên B ký kết:** Mở link trên trình duyệt, xem nội dung + ảnh hiện trường → Bấm **"Đồng ý & Ký tên"** → Quét FaceID trên máy B.

### Bước 3: Đồng bộ Trạng thái Tinh gọn (Event-Driven + Manual Refresh)

- **Phía Máy B:** Quét FaceID xong, client tổng hợp PDF hoàn tất và gửi **đúng 1 request `POST /api/v1/agreements/submit`** (`agreementHash` 32-byte) lên server → nhận ngay **biên nhận SCT (EIP-712) trong < 50ms**. Màn hình máy B hiện nút: *"Báo cho Bên A qua Zalo/Tin nhắn"*.
- **Phía Máy A (Không dùng Polling liên tục):**
  - Anh An gửi link xong có thể tắt màn hình đi làm việc khác.
  - Khi chị Bình báo đã ký, anh An chỉ cần **mở lại app CivilTrust** (hoặc bấm nút **"Làm mới trạng thái"**).
  - Ứng dụng gửi **đúng 1 request `GET /api/v1/agreements/status/:hash`** để kiểm tra → Màn hình anh An lập tức chuyển sang bước nhận tiền cọc VietQR.
  - *Lợi ích:* Không tốn tài nguyên chạy ngầm, không ngốn request của Cloudflare.

### Bước 4: Đối soát Dòng tiền Thực (Biên nhận Số 2 Chiều)

- Màn hình hiện mã **VietQR** động (chứa số tài khoản Bên A, số tiền cọc, và mã tham chiếu thỏa thuận).
- Bên B mở app ngân hàng quen thuộc (Vietcombank, MB, Techcombank...) quét mã và chuyển tiền VND bình thường.
- **Xác nhận biên nhận tiền (P2P Mutual Receipt):**
  - Khi tiền về tài khoản, Bên A mở app bấm nút: *"Tôi xác nhận đã nhận đủ 2.000.000đ cọc"* → **Quét FaceID**.
  - *Ý nghĩa pháp lý:* Chữ ký FaceID của chính chủ nhận tiền thừa nhận *"Đã nhận tiền"* có giá trị chứng cứ trước Tòa án mạnh hơn bất kỳ webhook tự động nào của bên thứ ba.

### Bước 5: Xuất Bản Chứng thư Tự thân & Đóng dấu Cuối ngày

- **Hiệu lực tức thì:** Cả hai bên tải ngay file **PDF Bản Chứng Thư Dân Sự Số**. File mang sẵn 2 chữ ký phần cứng P-256, mã xác nhận nhận tiền, và **QR chứa biên nhận SCT** (`ct:sct:v1:...`) — có giá trị thi hành ngay tức khắc.
- **Tự phục hồi (Client-Side Data Availability):** Nếu cơ sở dữ liệu server gặp sự cố, PDF/QR vẫn chứa đủ SCT để nạp lại qua `POST /api/v1/agreements/recover` — **không cần hai bên ký lại** (ADR-0012).
- **Đóng dấu niêm phong thời gian:** Mã băm của giao kèo được xếp hàng vào bộ nhớ đệm trong ngày. Đến **23:59 UTC**, hệ thống gom toàn bộ hợp đồng trong ngày thành một Merkle Root duy nhất và ghi lên Arbitrum bằng chữ ký ngưỡng FROST2+ 2-of-3.

---

## 4. KIẾN TRÚC LƯU TRỮ NỘI ĐỊA (VIETTEL IDC OBJECT STORAGE)

> **Ghi chú đồng bộ repo:** Tầng service đã triển khai (`service/` v1.3.0) vận hành theo **Zero-PII tuyệt đối** — chỉ lưu hash 32-byte trong Cloudflare D1 / SQLite. Phần lưu trữ media (ảnh/PDF) dưới đây thuộc **thiết kế tầng client/PWA** (repo `app/` chưa có mã nguồn).

Nhằm tuân thủ tuyệt đối **Nghị định 13/2023/NĐ-CP** và bảo đảm quyền riêng tư, toàn bộ dữ liệu nhạy cảm được quản lý như sau:

```
[PWA nén ảnh WebP] ──► [Xin Pre-signed URL từ Worker] ──► [Upload thẳng Viettel IDC S3 (Private)]
                                                                          │
[Thẩm phán / Người dùng quét QR xem ảnh] ◄── [Cấp Pre-signed URL 5 phút] ─┘
```

1. **Vị trí Lưu trữ Vật lý:** Đặt tại Data Center của **Viettel IDC** (Hà Nội và Bình Dương), đạt tiêu chuẩn an toàn thông tin Cấp độ 3 và chứng chỉ ISO 27001. Không một byte ảnh nào bay ra khỏi lãnh thổ Việt Nam.
2. **Quyền riêng tư Tuyệt đối (Bucket Private 100%):**
   - Kho chứa S3 trên Viettel IDC được khóa hoàn toàn (Private). Không ai có thể dò link hay quét ID để xem lén ảnh của người khác.
   - Khi người dùng hoặc Thẩm phán quét mã QR cần xem ảnh/PDF, Cloudflare Worker kiểm tra mã băm và cấp một **Pre-signed URL có thời hạn đúng 5 phút**. Hết 5 phút, link tự hủy.
3. **Quy chuẩn Dung lượng & Định dạng File:**
   - **Cấm upload video:** Video quá nặng, gây lag PWA và nhanh đầy ổ cứng.
   - **Ảnh chụp:** Tối đa 3 – 5 ảnh, định dạng WebP, độ phân giải HD 1280x720, dung lượng ~100KB/ảnh.
   - Tổng dung lượng 1 giao kèo: **< 1MB**.
4. **Nút "Lưu vào Google Drive Cá nhân":**
   - Trên màn hình hoàn tất, cung cấp nút **"Tải về máy / Lưu vào Google Drive"**.
   - Trách nhiệm lưu trữ gốc thuộc về người dùng (tinh thần P2P tự thân), giúp kho lưu trữ Viettel IDC 50GB của hệ thống có thể phục vụ bền vững tới **50.000 hợp đồng**.

---

## 5. CƠ CHẾ ĐÓNG DẤU "DAILY MERKLE ANCHOR" (CHỐT SỔ 23:59 UTC)

Đây là giải pháp cốt lõi giúp hệ thống triệt tiêu gánh nặng chi phí gas:

```
[Hợp đồng #001] ──┐
[Hợp đồng #002] ──┼──► [Cây Merkle Off-chain] ──► [Merkle Root 32-bytes] ──► [Arbitrum One L2]
[Hợp đồng #... ] ──┤     (Chốt lúc 23:59 UTC)     (Ký EIP-712 BatchAttestation)  (~100.000 gas/ngày)
[Hợp đồng #N   ] ──┘
```

### 5.1. Cơ chế Vận hành Kinh tế

- Ban ngày, hệ thống chỉ lưu tạm mã băm `agreementHash` vào cơ sở dữ liệu đệm Cloudflare D1 (0đ) và nhân bản liên tục sang node backup (Bun VPS + SQLite WAL).
- **Lịch trình chống split-brain (Anti-Split-Brain Schedule):**
  - **23:55 UTC — Quiet Window Cut-off:** Các submission mới tự động roll sang ngày kế tiếp (D+1) để tránh race condition vùng biên.
  - **23:59 UTC — Primary Anchor:** Node chính gom toàn bộ hash trong ngày, dựng **Merkle Tree chuẩn OpenZeppelin v5 (double-hash)**, ký EIP-712 `BatchAttestation` và phát **ĐÚNG 1 GIAO DỊCH DUY NHẤT** ghi chuỗi `merkleRoot` (32 bytes) lên Smart Contract `CivilTrustRegistry.sol` (v1.4.0) trên Arbitrum One.
  - **00:05 UTC (D+1) — Audit & Failover:** Node backup (Bun VPS) truy vấn Arbitrum One kiểm tra trạng thái ngày D. Nếu node chính chưa anchor thành công, node backup tự động kích hoạt failover.
- **Cơ chế bảo vệ bất biến:** Guard `AlreadyAnchored(dateKey)` khóa vĩnh viễn write-once — mỗi ngày chỉ ghi được đúng 1 lần, không thể sửa/xóa. Relayer là permissionless (bất kỳ ai cũng có thể broadcast giao dịch hợp lệ, ví ký không cần giữ gas).
- **Chi phí Gas thực tế (theo tài liệu repo):**
  - 1 giao dịch ghi Root trên Arbitrum: ~100.000 gas ≈ **800 VNĐ**.
  - 1 tháng (30 ngày): $30 \times 800\text{đ} = \mathbf{24.000\text{ VNĐ / tháng}}$.
  - **1 năm vận hành:** Tốn đúng **~288.000 VNĐ**.
  - Nạp sẵn **100.000 VNĐ tiền ETH** vào ví Relayer ≈ chạy được **~4 tháng**; nạp ~300.000 VNĐ ≈ trọn **1 năm**.
- **Ghi chú giờ UTC:** 23:59 UTC tương đương **~07:00 sáng hôm sau theo giờ Việt Nam**.

### 5.2. Logic Xử lý Ngoại lệ (Fail-Safe & Retry)

- **Nếu ngày hôm đó không có hợp đồng nào:** Worker kiểm tra `if (totalAgreementsToday == 0) return;` → Bỏ qua, không gửi transaction để tiết kiệm tiền gas.
- **Nếu mạng Arbitrum bị nghẽn hoặc RPC lỗi:**
  - Node chính kích hoạt cơ chế **Retry**.
  - Nếu vẫn lỗi, đến **00:05 UTC node backup tự động audit và rescue** bằng failover (node 2 ký và broadcast lại batch của ngày D).
  - Nếu cả hai node bỏ lỡ (sự cố mạng toàn cầu), toàn bộ dữ liệu ngày hôm đó sẽ tự động gộp chung vào đợt chốt sổ của đêm hôm sau, không bao giờ bị mất dấu vết.

---

## 6. BẰNG CHỨNG PHÁP LÝ & GIẢI PHÁP CHO THẨM PHÁN / LUẬT SƯ

### 6.1. Cơ sở Pháp lý Vững chắc tại Việt Nam

- **Điều 22 & 23 Luật Giao dịch điện tử 2023:** Công nhận chữ ký điện tử tạo bằng phương tiện do người ký kiểm soát tại thời điểm ký (Chip phần cứng FaceID NIST P-256) và có khả năng phát hiện mọi thay đổi đối với văn bản sau thời điểm ký.
- **Điều 119 Bộ luật Dân sự 2015:** Thừa nhận hợp đồng được xác lập thông qua hành vi thực tế (chuyển và nhận tiền VietQR có xác nhận 2 bên).
- **Nghị định 13/2023/NĐ-CP:** Đảm bảo 100% vì **Zero-PII On-Chain**. Không có Tên, SĐT, Số CCCD nào bị đưa lên mạng blockchain quốc tế; chỉ có các mã băm toán học vô nghĩa. Chính danh (CCCD/C06) xử lý hoàn toàn phía client bằng WebCrypto — các hàm xác thực PII từng có trên contract đã bị gỡ bỏ từ v1.2.0 (ADR-0011).
- **Bảo vệ chữ ký notary:** Biên nhận SCT dùng **EIP-712** buộc chặt `chainId` + địa chỉ contract (chống replay cross-chain), có `deadline` hết hạn chữ ký. Contract **không thể nâng cấp** (no upgradeability) và **không giữ ETH** (zero custody).

### 6.2. Quy trình Thẩm phán kiểm tra tranh chấp (Chỉ mất 5 giây, 0 đồng gas):

- **Cách 1: Quét mã QR:** Thẩm phán dùng camera điện thoại quét mã QR trên bản in giấy → Trình duyệt mở `verify.civiltrust.vn` (xác minh client-side bằng WebCrypto, không qua server trung gian) → Màn hình hiện **TÍCH XANH** xác nhận văn bản nguyên bản.
- **Cách 2: Kéo thả file PDF (Giám định chống Photoshop):**
  - Thẩm phán truy cập trang tra cứu, kéo thả file PDF nghi vấn vào ô kiểm tra.
  - Trình duyệt tự băm file ra chuỗi `hash` và đối chiếu với Merkle Root đã chốt sổ trên blockchain Arbitrum:
    - **Khớp:** Báo xanh (Văn bản toàn vẹn, niêm phong đúng ngày).
    - **Sai lệch dù chỉ 1 pixel ảnh:** Báo đỏ lập tức: *"CẢNH BÁO: Tệp tin đã bị chỉnh sửa sau thời điểm niêm phong!"*
- **Xác minh on-chain (0 gas qua `eth_call`):**
  - `verifyAgreement(dateKey, hash, merkleProof)` — chứng minh văn bản nằm trong cây Merkle đã neo (chuẩn OZ v5 double-hash).
  - `verifyReceipt(hash, dateKey, timestamp, nonce, signature)` — xác thực biên nhận SCT với `batchSigner` (hoặc `receiptSigner` ban ngày).
  - `verifySchnorr(messageHash, R.x, parity, z)` — xác thực chữ ký ngưỡng FROST2+ 64-byte qua kỹ thuật Alt-Schnorr (lõi xác minh ~5.000 gas, **0 gas khi gọi `eth_call`**).
- **Chi phí kiểm tra:** **0 đồng** (Sử dụng lệnh gọi đọc `eth_call` miễn phí).

### 6.3. Tấm khiên Bảo vệ Tác giả: Tuyên bố Miễn trừ Trách nhiệm (Disclaimer)

Để tác giả phần mềm không bị lôi vào các vụ kiện tụng dân sự ngoài đời, trang khởi tạo thỏa thuận bắt buộc hiển thị điều khoản:

> *"CivilTrust là công cụ tiện ích công nghệ tự thân, mã nguồn mở. Nền tảng KHÔNG PHẢI là văn phòng công chứng và KHÔNG đóng vai trò là bên thứ ba bảo lãnh. Người dùng tự chịu trách nhiệm về tính xác thực của nội dung giao kết. Tác giả phần mềm được miễn trừ toàn bộ trách nhiệm dân sự và liên đới phát sinh từ các tranh chấp giữa các bên."*

---

## 7. KIẾN TRÚC HỆ THỐNG TRỌN GÓI & DỰ TOÁN CHI PHÍ CỐ ĐỊNH (~74K/THÁNG)

Toàn bộ hệ thống vận hành trên sự kết hợp giữa tài nguyên miễn phí và dịch vụ giá rẻ nội địa:

```
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
```

### Tầng ký ngưỡng FROST2+ 2-of-3 (v1.4.0 — ADR-0013)

```
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
```

- **Mô hình "Ký Phân Tầng" (Layered Notary):** Ban ngày, node biên (Cloudflare) ký biên nhận SCT cục bộ bằng `receiptSigner` (< 1ms) — kể cả khi đứt kết nối tới VPS, tiến trình ký FaceID của người dân vẫn hoạt động bình thường. `anchorDailyRoot` **chỉ chấp nhận** khóa nhóm `batchSigner` — khóa cấp biên nhận không bao giờ có quyền anchor.
- **Sinh khóa CKG (Centralized Key Generation):** Shamir Secret Sharing tách Master Key thành `sk_1` (Cloudflare Secret), `sk_2` (VPS `.env`), `sk_3` (cold share offline), sau đó zeroize RAM. Script keygen nằm trong lộ trình `service/scripts/keygen-ckg.ts`.
- **Chi phí hạ tầng phát sinh: 0đ** — cold share cất két sắt/USB, không cần server online.

### Bảng Hạch toán Chi phí Vận hành Thực tế (Không phát sinh chi phí ẩn):

| Hạng mục hạ tầng                | Đơn vị cung cấp                       | Thông số kỹ thuật                                   | Chi phí hàng tháng           |
| ----------------------------------- | ----------------------------------------- | ------------------------------------------------------- | ------------------------------- |
| **Lưu trữ Ảnh & PDF**      | Viettel IDC                               | 50GB Object Storage, Private ACL, 250GB băng thông    | **30.000 VNĐ**           |
| **Phí Gas Blockchain**       | Arbitrum One (L2)                         | 1 transaction Merkle Root / ngày (~100.000 gas)        | **~24.000 VNĐ**          |
| **Duy trì Tên miền**       | Nhà đăng ký tên miền                | Tên miền`.com` hoặc `.vn` (chia đều 12 tháng) | **~20.000 VNĐ**          |
| **Frontend & API Host**       | Cloudflare                                | Pages + Workers (Free Tier 100.000 req/ngày)           | **0 VNĐ**                |
| **Database đệm**            | Cloudflare                                | D1 Serverless SQL (Free Tier)                           | **0 VNĐ**                |
| **TỔNG CHI PHÍ VẬN HÀNH** | **Trọn gói toàn bộ hệ thống** | **Phục vụ tối đa ~50.000 hợp đồng**        | **~74.000 VNĐ / tháng** |

> *Ghi chú: Chi phí VPS cho node Backup Auditor (Bun 1.4 + SQLite WAL) tùy nhà cung cấp — có thể tận dụng VPS cá nhân sẵn có, không tính vào bảng trên.*

---

## 8. MÔ HÌNH VẬN HÀNH & KINH DOANH (TIỆN ÍCH CỘNG ĐỒNG & DONATION)

- **Hoàn toàn Miễn phí (Free Public Utility):**
  - Người dùng không phải trả bất kỳ khoản phí nào để tạo thỏa thuận, ký FaceID, đối soát VietQR, xuất PDF và tra cứu chứng thực.
- **Mô hình "Mời tôi ly cà phê" (VietQR Donation):**
  - Trên trang xuất file PDF và trang tra cứu kết quả, hiển thị một góc nhỏ trang nhã:

    > *"CivilTrust là dự án tiện ích công cộng phi lợi nhuận. Nếu ứng dụng này giúp bạn bảo vệ được tài sản và tiền cọc nhà, bạn có thể ủng hộ tác giả 1 ly cà phê qua VietQR: [Mã QR ngân hàng cá nhân]."*
    >
- **Lợi ích Pháp lý Tuyệt đối:**
  - **Không kinh doanh, không thu phí dịch vụ:** Không cần thành lập doanh nghiệp, không cần xin giấy phép sàn thương mại điện tử, không cần kế toán báo cáo thuế định kỳ.
  - Tiền donate cá nhân tự nguyện là hợp pháp, chuyển thẳng vào tài khoản ngân hàng của bạn mà không tốn công quản trị.

---

## 9. ĐÁNH GIÁ TỔNG KẾT & TÍNH KHẢ THI

| Tiêu chí                                      | Đánh giá kiến trúc CivilTrust 3.1                                                                                                                                                                   |
| ----------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Tính Nhàn hạ (Idle / Set & Forget)** | **Tuyệt đối:** Không cần canh ví gas, không polling ngầm, không bảo trì server. Code xong deploy là vứt đấy.                                                                        |
| **Ngân sách Khả thi**                  | **~74.000 VNĐ / tháng:** Nằm gọn trong mức chi trả cá nhân (< 100k/tháng), không có chi phí biến đổi bất ngờ.                                                                     |
| **Tuân thủ Pháp luật Việt Nam**      | **100%:** Zero-PII (Nghị định 13), chữ ký FaceID phần cứng (Luật GDĐT 2023), VietQR thật (QĐ 2345/NHNN), media nội địa tại Viettel IDC.                                             |
| **Bảo mật Khóa Notary**                | **TS-SUF-4:** Cụm ngưỡng FROST2+ 2-of-3 — loại bỏ hoàn toàn điểm chết đơn lẻ (SPOF), kháng tấn công Rogue Nonce, chữ ký gộp 64-byte cố định.                                |
| **Tính Độc lập (Antifragile)**        | **Bất tử:** Không phụ thuộc Zalo API, SePay hay bất kỳ bên thứ ba nào. Kể cả bạn bỏ quên dự án nhiều năm, chứng cứ trên sổ cái Arbitrum vẫn tra cứu được vĩnh viễn. |

---

## 10. HIỆN TRẠNG MÃ NGUỒN REPO (07/10/2026) & KHOẢNG CÁCH TRIỂN KHAI

| Thành phần                                          | Trạng thái                                 | Ghi chú                                                                                                                                                                                                                                                                                       |
| ----------------------------------------------------- | -------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`contracts/` — CivilTrustRegistry v1.4.0** | ✅**Đã hoàn thành (chưa deploy)** | Solidity 0.8.36 · Foundry · OpenZeppelin v5.3.0 · AGPL-3.0. Đã có`verifySchnorr` (Alt-Schnorr), `receiptSigner`, dual-scheme ECDSA/Schnorr. Test: 42 unit + 25 Schnorr + fuzz + invariant. Version "unreleased", `deployments/*.json` còn trống — chưa có địa chỉ mainnet. |
| **`service/` — Notary Service v1.3.0**       | ✅**Đã triển khai (v1.3.0)**        | Bun 1.4 · Hono · Viem · Zod · D1/SQLite WAL. Đủ API v1 (submit/proof/status/recover/sync/health), cron anchor + failover, SCT < 50ms, self-healing. Hỗ trợ sẵn`RECEIPT_SIGNER_PRIVATE_KEY` (layered notary).                                                                        |
| **FROST2+ phía service**                       | ⏳**Trong lộ trình**                 | `src/core/crypto/` hiện có `merkle.ts`, `eip712.ts`, `sct.ts` — module `frost2plus.ts` và script `keygen-ckg.ts` chưa được implement (Lộ trình GĐ 1–2 của `docs/frost2plus-architecture-v140.md`).                                                                  |
| **`app/` — Client PWA**                      | ⏳**Chưa có mã nguồn**             | Repo git đã khởi tạo (remote`CivilTrust/app.git`) nhưng chưa có nội dung — toàn bộ UX mục 3 (FaceID WebAuthn, nén ảnh WebP, VietQR, NFC CCCD) đang ở dạng thiết kế.                                                                                                       |
| **`docs/`**                                   | ✅ Đầy đủ                                | `frost2plus-architecture-v140.md` (tiếng Việt) + 2 paper học thuật (FROST2+ của Solv Protocol; Flock). ADR-0001 → ADR-0013 trong `contracts/docs/decisions/`.                                                                                                                        |

**Ưu tiên tiếp theo:** (1) implement `service/src/core/crypto/frost2plus.ts` + `keygen-ckg.ts`; (2) benchmark độ trễ < 50ms & test mô phỏng tấn công Rogue Nonce; (3) deploy `CivilTrustRegistry` v1.4.0 lên Arbitrum Sepolia → One; (4) dựng client PWA.

---

Bản đặc tả kiến trúc này là kim chỉ nam hoàn chỉnh nhất: vừa đảm bảo chuẩn mực công nghệ mật mã đỉnh cao (FROST2+ TS-SUF-4, Alt-Schnorr, Client-Side DA), vừa an toàn pháp lý tuyệt đối, lại tối ưu xuất sắc cho một nhà phát triển độc lập muốn tạo ra giá trị bền vững cho xã hội.
