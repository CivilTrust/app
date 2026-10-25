# Yêu cầu bàn giao để app demo Sepolia

Tài liệu chuẩn bị để người phụ trách app gửi cho thành viên `service/` và `contracts/`. Chưa gửi trực tiếp từ Codex. Mục tiêu phản hồi: trước 01/11/2026 cho SCT/deployment, trước 03/11/2026 cho proof/batch mẫu. Đầu mối liên hệ và ngày phản hồi thực tế cần nhóm điền.

| Nhóm | Cần bàn giao | App sử dụng |
| --- | --- | --- |
| Contracts | Chain ID 421614; registry address, ABI và commit/phiên bản deployment; tx deploy/explorer URL; `batchSigner` và `receiptSigner` hiện hành, quy tắc signer rotation | Pin EIP-712 domain, kiểm signer, `eth_call` đúng contract |
| Service | URL môi trường test truy cập từ Flutter Web, CORS cho origin local/demo; ví dụ thật response `submit` 201/200, `status`, `proof`, `recover` và mã lỗi | Typed adapter, phân biệt pending/batched/error, cấu hình demo |
| Cả hai | SCT do service/Viem ký trên Sepolia; vector sai chữ ký/domain/hash; proof cho batch 1/2/3 lá, root, dateKey, tx hash, một record đã anchor | Kiểm liên ngôn ngữ EIP-712/Merkle/RPC; demo không phụ thuộc giờ cron |

## Hai điểm service cần xác nhận

1. `POST /api/v1/agreements/submit` lần đầu (`201`) có `sct.signer`; nhánh idempotent (`200`) hiện bỏ field này. App ngày 2 chấp nhận field vắng nhưng không coi metadata signer là bằng chứng tin cậy. Đề nghị service thống nhất response và cung cấp fixture cho cả hai nhánh.
2. Xác nhận quy tắc `dateKey` quanh quiet window 23:55 UTC và cách recovery xử lý record `pending` thuộc ngày cũ. Cho biết khi nào proof sẵn sàng, ý nghĩa từng `404`, và lịch/cách tạo một batch mẫu trước demo.

Không gửi private key, cluster secret, CCCD hoặc dữ liệu cá nhân thật trong fixture. App chỉ gửi `agreementHash = keccak256(agreement.pdf)` cho service. SCT và proof nằm trong sidecar ZIP; PDF không đổi sau khi submit.
