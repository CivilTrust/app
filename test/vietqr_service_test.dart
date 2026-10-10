import 'package:civiltrust_app/features/payment/vietqr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = VietQrService();

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
