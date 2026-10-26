# Tuần 1, ngày 3–4 — EIP-712 và ECDSA recovery

Ghi nhận ngày 26/10/2026. Phạm vi chỉ thuộc `app/`; không sửa `contracts/` hoặc `service/`. Đây là lớp kiểm chữ ký SCT cục bộ, chưa phải kiểm Merkle proof hoặc xác nhận on-chain.

## Phần đã triển khai

`SctVerifier` dựng đúng digest EIP-712 theo schema của service/contract:

```text
domain = EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)
message = Receipt(bytes32 agreementHash,uint256 dateKey,uint64 timestamp,bytes32 nonce)
digest = keccak256(0x1901 || domainSeparator || structHash)
```

Các giá trị ABI tĩnh được mã hóa thành word 32 byte. `agreementHash` lấy từ byte của `agreement.pdf`; verifier không dùng `frozenDigest` của draft hoặc hash JSON. Địa chỉ contract được left-pad thành 32 byte và các số nguyên được mã hóa big-endian như ABI.

ECDSA recovery dùng `web3dart 3.0.3`, package công bố hỗ trợ Flutter Web và cung cấp `ecRecover` cho secp256k1. App kiểm chữ ký 65 byte, `r/s` trong miền hợp lệ, low-s canonical và recovery id `27/28` trước khi phục hồi địa chỉ. Không có private key trong source hoặc fixture app.

## Mô hình tin cậy

`SctTrustPolicy` yêu cầu đồng thời:

- đúng `chainId`;
- đúng `verifyingContract` của deployment;
- signer phục hồi thuộc tập `batchSigner` hoặc `receiptSigner` được cấu hình ngoài SCT.

Field `sct.signer` chỉ là metadata. Nếu có thì phải khớp địa chỉ phục hồi; nếu vắng, chữ ký vẫn có thể được phục hồi và đánh giá theo policy. App không chấp nhận chữ ký chỉ vì địa chỉ phục hồi khớp `sct.signer` tự khai.

Kết quả verifier có bốn mức:

| Trạng thái | Ý nghĩa |
| --- | --- |
| `valid` | Digest/chữ ký hợp lệ, domain đúng deployment và signer nằm trong tập tin cậy |
| `invalid` | Hash PDF, payload, domain, chữ ký, metadata signer hoặc trust policy không khớp |
| `unsupported` | Version SCT hoặc domain schema chưa được client hỗ trợ |
| `notConfigured` | Phục hồi chữ ký thành công nhưng app chưa có deployment/signer tin cậy để kết luận |

`valid` ở đây chỉ nói về SCT EIP-712. Nó không có nghĩa record đã được batch, có Merkle proof hoặc đã được contract xác nhận.

## Vector liên ngôn ngữ

Fixture công khai `test/fixtures/sct_viem_v1_3_0.json` được tạo bằng `viem@2.56.5` với `account.signTypedData`. Fixture chỉ giữ domain, message, digest, public signer và signature; khóa test dùng lúc sinh vector không được ghi vào app.

| Thuộc tính | Giá trị fixture |
| --- | --- |
| Chain | Arbitrum Sepolia `421614` |
| Contract | `0x1234567890123456789012345678901234567890` — địa chỉ giả lập, không phải deployment thật |
| Signer | `0x70997970c51812dc3a010c7d01b50e0d17dc79c8` — signer fixture, không phải signer production |
| Digest Viem | `0x228d10e9c9647c6930bcd8af0b8bd8f769d8def0a11cf3341414ec1bde173257` |

Test Dart tính lại đúng digest Viem và phục hồi đúng signer. Test âm tính bao phủ: đổi một byte đầu vào tài liệu, đổi `agreementHash`, `dateKey`, `timestamp`, `nonce`, chain, contract, domain name/version, signature sai độ dài/recovery id, metadata signer không khớp và signer không được phép. Trường hợp thiếu `sct.signer` vẫn hợp lệ khi địa chỉ phục hồi thuộc policy.

## Cấu hình và blocker thực tế

Hiện chưa có deployment Arbitrum Sepolia trong `contracts/deployments/arbitrum-sepolia.json`, vì vậy code ngày 3–4 **không hard-code fixture làm cấu hình runtime**. Fixture chỉ dùng trong test. Trước khi nối UI ngày 5, nhóm contracts/service cần bàn giao:

1. contract address của đúng deployment;
2. `batchSigner` và `receiptSigner` đang hoạt động;
3. một SCT v1.3.0 do service thật ký và một vector sai;
4. xác nhận policy khi `sct.signer` vắng ở response idempotent `200`.

Nếu các giá trị trên chưa có, UI ngày 5 phải hiện `notConfigured`, không được hiện “SCT hợp lệ” hoặc “on-chain verified”.

## Nghiệm thu ngày 4

- `flutter analyze --no-pub`: pass, không có issue.
- `flutter test --no-pub`: pass 36 test; 1 live coordinator test được skip đúng cấu hình mặc định. Riêng verifier có 8 test pass.
- `flutter build web --no-pub`: pass; Wasm dry run của Flutter cũng thành công.
- Đã thử `flutter test --platform chrome test/sct_verifier_test.dart`, nhưng runner của máy kiểm thử đứng ở bước `loading` hơn một phút và không chạy test case nên đã dừng. Không ghi nhận lệnh này là pass. Web build thành công xác nhận dependency compile cho Web; cần chạy lại browser test trên CI/Chrome profile hoạt động ổn định.
- Không thay đổi PDF, coordinator, hợp đồng Solidity hoặc service.
- Bước tiếp theo ngày 5: đưa policy vào cấu hình runtime, nối verifier vào luồng tạo ZIP và màn Kiểm chứng, vẫn giữ Merkle/RPC là “chưa kiểm”.
