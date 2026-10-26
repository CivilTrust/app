import 'package:civiltrust_app/features/payment/vietqr_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/payment_draft.dart';
import 'helpers/vietqr_reference_decoder.dart';

void main() {
  const service = VietQrService();

  test('matches a hand-encoded golden and independent CRC/TLV decoding', () {
    expect(referenceCrc('123456789'), '29B1');
    final qr = service.build(
      bankBin: '970436',
      accountNumber: '000000000001',
      amount: 2000000,
      purpose: 'CIVILTRUST TEST0001',
    );
    expect(qr, accountQrGolden);
    expect(decodeAccountQr(qr), {
      'bankBin': '970436',
      'accountNumber': '000000000001',
      'amount': '2000000',
      'purpose': 'CIVILTRUST TEST0001',
    });
    final changedAmount = qr.replaceFirst('54072000000', '54073000000');
    expect(() => decodeAccountQr(changedAmount), throwsFormatException);
    expect(() => readTlv('0005bad'), throwsFormatException);
    expect(() => readTlv('000201000201'), throwsFormatException);
  });

  test('respects account/purpose/amount bounds without silent truncation', () {
    String build({
      String account = '000000000001',
      String purpose = 'TEST',
      int amount = 1,
    }) => service.build(
      bankBin: '970436',
      accountNumber: account,
      amount: amount,
      purpose: purpose,
    );
    final maximum = decodeAccountQr(
      build(
        account: 'A' * 19,
        purpose: 'Z' * 25,
        amount: VietQrService.maxAmount,
      ),
    );
    expect(maximum['accountNumber'], 'A' * 19);
    expect(maximum['purpose'], 'Z' * 25);
    expect(maximum['amount'], VietQrService.maxAmount.toString());
    for (final account in ['123', 'A' * 20, '0000 0000', '0000\n']) {
      expect(() => build(account: account), throwsArgumentError);
    }
    for (final purpose in ['', '   ', 'X' * 26, 'Đặt cọc', 'TEST!']) {
      expect(() => build(purpose: purpose), throwsArgumentError);
    }
    expect(
      () => build(amount: VietQrService.maxAmount + 1),
      throwsArgumentError,
    );
    expect(() => build(amount: -1), throwsArgumentError);
    expect(
      decodeAccountQr(build(purpose: 'case Preserved'))['purpose'],
      'case Preserved',
    );
  });

  test('builds a dynamic VietQR payload with amount and bank account', () {
    final qr = service.build(
      bankBin: '970436',
      accountNumber: '1234567890',
      amount: 1500000,
      purpose: 'CivilTrust HD ABC123',
    );

    expect(qr, startsWith('000201010212'));
    expect(qr, contains('970436'));
    expect(qr, contains('1234567890'));
    expect(qr, contains('1500000'));
    expect(qr, matches(RegExp(r'6304[0-9A-F]{4}$')));
  });

  test('rejects invalid payment input', () {
    expect(
      () => service.build(
        bankBin: 'VCB',
        accountNumber: '1234567890',
        amount: 1000,
        purpose: 'TEST',
      ),
      throwsArgumentError,
    );
    expect(
      () => service.build(
        bankBin: '970436',
        accountNumber: '1234567890',
        amount: 0,
        purpose: 'TEST',
      ),
      throwsArgumentError,
    );
  });
}
