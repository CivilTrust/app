import 'package:civiltrust_app/app/civiltrust_app.dart';
import 'package:civiltrust_app/core/formatting/vnd_words.dart';
import 'package:civiltrust_app/features/agreements/agreement_validator.dart';
import 'package:civiltrust_app/features/agreements/contract_template.dart';
import 'package:civiltrust_app/features/agreements/contract_template_service.dart';
import 'package:civiltrust_app/features/payment/vietqr_banks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ContractFieldSpec spec(ContractTemplate template, String key) =>
    template.fields.firstWhere((field) => field.key == key);

void main() {
  group('numberToVietnameseWords', () {
    const cases = {
      0: 'không',
      5: 'năm',
      10: 'mười',
      11: 'mười một',
      14: 'mười bốn',
      15: 'mười lăm',
      21: 'hai mươi mốt',
      24: 'hai mươi tư',
      25: 'hai mươi lăm',
      105: 'một trăm linh năm',
      110: 'một trăm mười',
      1000: 'một nghìn',
      1005: 'một nghìn không trăm linh năm',
      1500000: 'một triệu năm trăm nghìn',
      1000005: 'một triệu không trăm linh năm',
      50000000: 'năm mươi triệu',
      1000000000: 'một tỷ',
      2025000000: 'hai tỷ không trăm hai mươi lăm triệu',
      9999999999999:
          'chín nghìn chín trăm chín mươi chín tỷ chín trăm chín mươi chín '
          'triệu chín trăm chín mươi chín nghìn chín trăm chín mươi chín',
    };
    cases.forEach((value, words) {
      test('$value', () => expect(numberToVietnameseWords(value), words));
    });

    test('contract style capitalises and appends currency', () {
      expect(vndInWords(50000000), 'Năm mươi triệu đồng');
    });
  });

  group('VndInputFormatter', () {
    const formatter = VndInputFormatter();
    TextEditingValue type(String text) => formatter.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      ),
    );

    test('groups thousands and strips non-digits', () {
      expect(type('50000000').text, '50.000.000');
      expect(type('1.234a5').text, '12.345');
      expect(type('0007').text, '7');
      expect(VndInputFormatter.digitsOf('50.000.000'), '50000000');
    });

    test('rejects more than 13 digits', () {
      expect(type('12345678901234').text, '');
    });
  });

  group('AgreementValidator', () {
    final validator = AgreementValidator(clock: () => DateTime(2026, 11, 18));
    const loan = ContractTemplateService.loan;
    const deposit = ContractTemplateService.deposit;

    test('interest is capped at 20%/year and allows two decimals', () {
      final rate = spec(loan, 'interestRate');
      expect(validator.validateField(loan, rate, '0'), isNull);
      expect(validator.validateField(loan, rate, '20'), isNull);
      expect(validator.validateField(loan, rate, '12,5'), isNull);
      expect(validator.validateField(loan, rate, '19.99'), isNull);
      expect(validator.validateField(loan, rate, '20,01'), contains('20%'));
      expect(validator.validateField(loan, rate, '100'), contains('20%'));
      expect(validator.validateField(loan, rate, '1,234'), isNotNull);
    });

    test('money accepts grouped input and enforces bounds', () {
      final amount = spec(loan, 'principalAmount');
      expect(validator.validateField(loan, amount, '50.000.000'), isNull);
      expect(validator.validateField(loan, amount, '999'), contains('1.000'));
      expect(validator.validateField(loan, amount, '0'), isNotNull);
      expect(validator.validateField(loan, amount, '12a'), isNotNull);
    });

    test('dates cannot be in the past or too far ahead', () {
      final disbursement = spec(loan, 'disbursementDate');
      expect(validator.validateField(loan, disbursement, '18/11/2026'), isNull);
      expect(
        validator.validateField(loan, disbursement, '17/11/2026'),
        contains('trước hôm nay'),
      );
      expect(
        validator.validateField(loan, disbursement, '19/11/2027'),
        contains('quá xa'),
      );
      final completion = spec(deposit, 'completionDate');
      expect(
        validator.validateField(deposit, completion, '18/11/2031'),
        isNull,
      );
      expect(
        validator.validateField(deposit, completion, '19/11/2031'),
        isNotNull,
      );
    });

    test('text fields enforce length and reject control characters', () {
      final purpose = spec(loan, 'loanPurpose');
      expect(validator.validateField(loan, purpose, 'Ăn'), contains('ít nhất'));
      expect(validator.validateField(loan, purpose, 'Học phí'), isNull);
      expect(
        validator.validateField(loan, purpose, 'a' * 501),
        contains('Tối đa'),
      );
      expect(validator.validateField(loan, purpose, 'Học\u0000phí'), isNotNull);
      final extra = spec(loan, 'additionalTerms');
      expect(validator.validateField(loan, extra, ''), isNull);
    });

    test('signer must be at least 18 on the signing day', () {
      expect(validator.signerAgeError('18/11/2008'), isNull);
      expect(validator.signerAgeError('19/11/2008'), contains('18 tuổi'));
      expect(validator.signerAgeError('15/08/1995'), isNull);
      expect(validator.signerAgeError(null), isNull);
    });

    test('account holder name allows Vietnamese letters only', () {
      expect(validator.validateAccountName('NGUYEN VAN AN'), isNull);
      expect(validator.validateAccountName('Nguyễn Văn An'), isNull);
      expect(validator.validateAccountName('AN 123'), isNotNull);
      expect(validator.validateAccountName(''), isNotNull);
    });
  });

  test('bank search ignores case and diacritics', () {
    expect(bankByBin('970436')?.shortName, 'Vietcombank');
    expect(
      vietQrBanks.where((b) => b.matches('cong thuong')).map((b) => b.bin),
      containsAll(['970415']),
    );
    expect(vietQrBanks.where((b) => b.matches('9704')), isNotEmpty);
    expect(
      vietQrBanks.map((b) => b.bin).toSet(),
      hasLength(vietQrBanks.length),
    );
  });

  testWidgets('wide screens use a navigation rail instead of a bottom bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const CivilTrustApp());
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('switching phone/desktop layout keeps the form state', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const CivilTrustApp());
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hợp đồng vay tiền'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(find.text('Đang sử dụng dữ liệu mô phỏng'), findsOneWidget);
    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    // Still on the identity step, not reset to the template chooser.
    expect(find.text('Đang sử dụng dữ liệu mô phỏng'), findsOneWidget);
    expect(find.text('Hợp đồng đặt cọc'), findsNothing);
  });

  testWidgets('phones use a bottom navigation bar with short labels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const CivilTrustApp());
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Tạo mới'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
