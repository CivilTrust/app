import 'package:civiltrust_app/core/crypto/hash_service.dart';
import 'package:civiltrust_app/core/encoding/encoding_utils.dart';
import 'package:civiltrust_app/core/models/agreement.dart';
import 'package:civiltrust_app/features/identity/mock_identity_reader.dart';
import 'package:civiltrust_app/features/payment/payment_details.dart';
import 'package:civiltrust_app/features/signing/mock_party_signer.dart';
import 'package:civiltrust_app/features/signing/session_validator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/payment_draft.dart';
import 'helpers/vietqr_reference_decoder.dart';

void main() {
  test('A/B payment instructions match signed fields for deposit and loan', () {
    for (final template in ['deposit-v1', 'loan-v1']) {
      final original = paymentDraft(template: template);
      final roundTrip = AgreementDraft.fromJson(original.toJson());
      final a = PaymentDetails.fromDraft(original);
      final b = PaymentDetails.fromDraft(roundTrip);
      expect(a.payload, b.payload);
      expect(
        decodeAccountQr(b.payload)['purpose'],
        original.fields['paymentPurpose'],
      );
      expect(
        decodeAccountQr(a.payload)['accountNumber'],
        original.fields['accountNumber'],
      );
      expect(a.copyText, b.copyText);
      expect(a.copyText, contains('Tên do Bên A cung cấp'));
    }
  });
  test('new references bind full ID; legacy references are preserved', () {
    final a = PaymentDetails.fromDraft(
      paymentDraft(id: '1793001706002000-aaa'),
    );
    final b = PaymentDetails.fromDraft(
      paymentDraft(id: '1793001706002000-bbb'),
    );
    expect(a.purpose, isNot(b.purpose));
    expect(a.purpose.length, lessThanOrEqualTo(25));
    final old = PaymentDetails.fromDraft(paymentDraft(legacy: true));
    expect(old.purpose, 'CIVILTRUST 17930017');
    expect(old.legacyReference, isTrue);
    expect(
      PaymentDetails.fromDraft(paymentDraft(id: 'short')).purpose,
      startsWith('CIVILTRUST '),
    );
  });
  test('unsupported profiles and changed instructions fail safely', () {
    expect(
      () => PaymentDetails.fromDraft(
        paymentDraft(overrides: {'paymentQrProfile': 'next'}),
      ),
      throwsFormatException,
    );
    expect(
      () => PaymentDetails.fromDraft(
        paymentDraft(overrides: {'paymentPurpose': 'OTHER'}),
      ),
      throwsFormatException,
    );
    expect(
      () => PaymentDetails.fromDraft(
        paymentDraft(overrides: {'accountNumber': 'A' * 20}),
      ),
      throwsArgumentError,
    );
    expect(
      () => PaymentDetails.fromDraft(
        paymentDraft(overrides: {'accountName': ''}),
      ),
      throwsFormatException,
    );
  });
  test(
    'changing any locked payment instruction invalidates the party signature',
    () async {
      const hash = HashService();
      final signer = MockPartySigner();
      final original = paymentDraft();
      final digest = hash.canonicalObjectHash(original.toJson());
      final signature = await signer.sign(
        role: 'partyA',
        digest: hexToBytes(digest),
        identity: await MockIdentityReader().read(role: 'partyA'),
      );
      for (final field in [
        'bankBin',
        'accountNumber',
        'accountName',
        'paymentPurpose',
        'paymentQrProfile',
      ]) {
        final modified = paymentDraft(
          overrides: {...original.fields, field: 'changed'},
        );
        final session = SigningSession(
          draft: modified,
          state: AgreementState.partyASigned,
          frozenDigest: digest,
          partyA: signature,
        );
        await expectLater(
          SessionValidator(hash, signer).validate(session),
          throwsFormatException,
        );
      }
    },
  );
}
