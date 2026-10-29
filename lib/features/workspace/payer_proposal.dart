import 'dart:convert';

import '../../core/crypto/hash_service.dart';
import '../../core/encoding/encoding_utils.dart';
import '../../core/models/agreement.dart';
import '../../core/models/identity_evidence.dart';

/// Fields A may supply; commercial terms always remain B's proposal.
const recipientFields = {
  'bankBin',
  'accountNumber',
  'accountName',
  'partyAIdentityCommitment',
  'partyAIdentitySummary',
  'proposalDigest',
};
String proposalTermsDigest(AgreementDraft draft) =>
    const HashService().canonicalObjectHash({
      ...draft.toJson(),
      'fields': {
        for (final entry in draft.fields.entries)
          if (!recipientFields.contains(entry.key)) entry.key: entry.value,
      },
    });
Map<String, String> recipientIdentity(IdentityEvidence identity) => {
  'partyAIdentityCommitment': identity.identityCommitment,
  'partyAIdentitySummary':
      '${identity.displayName} · ${identity.documentNumberMasked} · danh tính mock',
};

class TransferEvidence {
  static const maxAttachmentBytes = 1024 * 1024;
  static String mime(List<int> bytes) {
    bool starts(List<int> value) =>
        bytes.length >= value.length &&
        List.generate(
          value.length,
          (i) => bytes[i] == value[i],
        ).every((v) => v);
    if (starts([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
      return 'image/png';
    }
    if (starts([0xff, 0xd8, 0xff])) return 'image/jpeg';
    if (starts(utf8.encode('%PDF-'))) return 'application/pdf';
    throw const FormatException(
      'Chỉ nhận ảnh PNG/JPEG hoặc PDF; không khớp định dạng tệp.',
    );
  }

  static Map<String, dynamic> create({
    required String agreementId,
    required String reference,
    List<int>? bytes,
  }) {
    if (reference.length > 200) {
      throw const FormatException('Mã tham chiếu tối đa 200 ký tự.');
    }
    if (bytes != null && (bytes.isEmpty || bytes.length > maxAttachmentBytes)) {
      throw const FormatException('Chứng từ tối đa 1 MiB.');
    }
    return {
      'agreementId': agreementId,
      'reference': reference.trim(),
      'reportedAt': DateTime.now().toUtc().toIso8601String(),
      'assurance': 'payer-reported-unverified',
      if (bytes != null)
        'attachment': {
          'mime': mime(bytes),
          'bytes': base64UrlNoPadding(bytes),
          'hash': const HashService().keccakHex(bytes),
        },
    };
  }

  static void validate(Map<String, dynamic> value, String agreementId) {
    if (value['agreementId'] != agreementId ||
        value['assurance'] != 'payer-reported-unverified' ||
        value['reference'] is! String ||
        (value['reference'] as String).length > 200 ||
        DateTime.tryParse(value['reportedAt']?.toString() ?? '') == null) {
      throw const FormatException('Thông báo chuyển khoản không hợp lệ.');
    }
    final attachment = value['attachment'];
    if (attachment != null) {
      final bytes = base64UrlDecodeNoPadding(
        (attachment as Map)['bytes'] as String,
      );
      if (bytes.isEmpty ||
          bytes.length > maxAttachmentBytes ||
          attachment['mime'] != mime(bytes) ||
          attachment['hash'] != const HashService().keccakHex(bytes)) {
        throw const FormatException('Chứng từ bị thay đổi hoặc quá lớn.');
      }
    }
  }
}

SigningSession signedSnapshot(SigningSession session) => SigningSession(
  draft: session.draft,
  state: AgreementState.bothSigned,
  frozenDigest: session.frozenDigest,
  partyA: session.partyA,
  partyB: session.partyB,
  events: session.events.take(3).toList(),
);
