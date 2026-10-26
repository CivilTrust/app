import 'package:civiltrust_app/core/models/agreement.dart';
import 'package:civiltrust_app/features/payment/payment_details.dart';

AgreementDraft paymentDraft({
  String id = '1793001706002000-62b807991749bd81',
  bool legacy = false,
  Map<String, String> overrides = const {},
  int amount = 2000000,
  String template = 'deposit-v1',
}) => AgreementDraft(
  id: id,
  title: 'Payment demo',
  terms: 'Synthetic test terms',
  amountVnd: amount,
  createdAt: DateTime.utc(2026, 10, 26),
  templateId: template,
  fields: {
    'bankBin': '970436',
    'accountNumber': '000000000001',
    'accountName': 'NGUOI NHAN DEMO',
    if (!legacy) 'paymentQrProfile': PaymentDetails.profile,
    if (!legacy) 'paymentPurpose': PaymentDetails.purposeFor(id),
    ...overrides,
  },
);

// Hand-encoded synthetic profile. CRC generated separately using Python's
// binascii.crc_hqx(ascii_body_ending_in_6304, 0xffff) = 0x55EF.
const accountQrGolden =
    '00020101021238560010A000000727012600069704360112000000000001'
    '0208QRIBFTTA5303704540720000005802VN62230819CIVILTRUST TEST0001630455EF';
