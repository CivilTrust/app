import 'dart:convert';

import '../../core/crypto/hash_service.dart';
import '../../core/models/agreement.dart';
import 'vietqr_service.dart';

/// Immutable instructions derived from a draft whose signature is validated
/// by the surrounding session flow. No bank account ownership is implied.
class PaymentDetails {
  PaymentDetails._({
    required this.bankBin,
    required this.accountNumber,
    required this.accountName,
    required this.amount,
    required this.purpose,
    required this.payload,
    required this.legacyReference,
  });

  static const profile = 'vietqr-account/2';
  static String purposeFor(String agreementId) =>
      'CIVILTRUST ${const HashService().keccakHex(utf8.encode(agreementId)).substring(2, 14).toUpperCase()}';

  factory PaymentDetails.fromDraft(AgreementDraft draft) {
    final fields = draft.fields;
    final version = fields['paymentQrProfile'];
    final legacy = version == null;
    if (!legacy && version != profile) {
      throw const FormatException(
        'Phiên bản thông tin chuyển khoản chưa được hỗ trợ.',
      );
    }
    if (legacy && fields.containsKey('paymentPurpose')) {
      throw const FormatException('Thông tin chuyển khoản thiếu phiên bản.');
    }
    // Preserve old sessions' previously displayed reference. Only new
    // reviewed drafts use the full-id-derived reference signed in fields.
    final purpose = legacy
        ? 'CIVILTRUST ${draft.id.substring(0, draft.id.length < 8 ? draft.id.length : 8).toUpperCase()}'
        : fields['paymentPurpose'];
    if (purpose == null || (!legacy && purpose != purposeFor(draft.id))) {
      throw const FormatException('Nội dung chuyển khoản không khớp hồ sơ.');
    }
    final bankBin = fields['bankBin'] ?? '';
    final accountNumber = fields['accountNumber'] ?? '';
    final accountName = fields['accountName']?.trim() ?? '';
    if (accountName.isEmpty) {
      throw const FormatException('Thiếu tên người nhận do Bên A cung cấp.');
    }
    final payload = const VietQrService().build(
      bankBin: bankBin,
      accountNumber: accountNumber,
      amount: draft.amountVnd,
      purpose: purpose,
    );
    return PaymentDetails._(
      bankBin: bankBin,
      accountNumber: accountNumber,
      accountName: accountName,
      amount: draft.amountVnd,
      purpose: purpose,
      payload: payload,
      legacyReference: legacy,
    );
  }

  final String bankBin;
  final String accountNumber;
  final String accountName;
  final int amount;
  final String purpose;
  final String payload;
  final bool legacyReference;

  String get copyText =>
      'Chuyển cho Bên A\nBIN ngân hàng: $bankBin\n'
      'Số tài khoản: $accountNumber\nTên do Bên A cung cấp: $accountName\n'
      'Số tiền (VND): $amount\nNội dung: $purpose\n'
      'Kiểm tra tên người nhận trong app ngân hàng trước khi xác nhận.';
}
