import 'package:civiltrust_app/features/agreements/agreement_validator.dart';
import 'package:civiltrust_app/features/agreements/contract_template_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validator = AgreementValidator();

  test('rejects invalid dates and loan chronology', () {
    final dueField = ContractTemplateService.loan.fields.firstWhere(
      (field) => field.key == 'dueDate',
    );
    expect(
      validator.validateField(
        ContractTemplateService.loan,
        dueField,
        '31/02/2026',
      ),
      isNotNull,
    );
    expect(
      validator.validateBusinessRules(ContractTemplateService.loan, const {
        'disbursementDate': '10/10/2026',
        'dueDate': '09/10/2026',
      }),
      contains('sau ngày giải ngân'),
    );
  });

  test('rejects deposit greater than total transaction value', () {
    expect(
      validator.validateBusinessRules(ContractTemplateService.deposit, const {
        'totalValue': '1000000',
        'depositAmount': '2000000',
      }),
      contains('không được lớn hơn'),
    );
  });

  test('validates VietQR recipient fields', () {
    expect(validator.validateBankBin('970436'), isNull);
    expect(validator.validateBankBin('VCB'), isNotNull);
    expect(validator.validateAccountNumber('1234567890'), isNull);
    expect(validator.validateAccountNumber('12 34'), isNotNull);
  });
}
