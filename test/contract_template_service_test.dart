import 'package:civiltrust_app/features/agreements/contract_template.dart';
import 'package:civiltrust_app/features/agreements/contract_template_service.dart';
import 'package:civiltrust_app/features/identity/mock_identity_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = ContractTemplateService();

  test('catalog exposes deposit and loan templates from supplied samples', () {
    expect(ContractTemplateService.templates, hasLength(2));
    expect(ContractTemplateService.deposit.kind, ContractKind.deposit);
    expect(ContractTemplateService.loan.kind, ContractKind.loan);
    expect(ContractTemplateService.deposit.sourceFile, endsWith('.docx'));
    expect(ContractTemplateService.loan.sourceFile, endsWith('.doc'));
  });

  test('amount is selected from the correct template field', () {
    expect(
      service.amountFor(ContractTemplateService.deposit, {
        'depositAmount': '10.000.000 VND',
      }),
      10000000,
    );
    expect(
      service.amountFor(ContractTemplateService.loan, {
        'principalAmount': '25,000,000',
      }),
      25000000,
    );
  });

  test('review includes identity and key loan terms', () async {
    final identity = await MockIdentityReader().read(role: 'partyA');
    final review = service.renderReview(
      template: ContractTemplateService.loan,
      partyA: identity,
      fields: const {
        'principalAmount': '1000000',
        'loanPurpose': 'Học tập',
        'disbursementDate': '10/10/2026',
        'dueDate': '10/11/2026',
        'interestRate': '0',
        'repaymentMethod': 'Một lần',
        'latePaymentTerms': 'Theo thỏa thuận',
      },
    );

    expect(review, contains('001099000001'));
    expect(review, contains('1.000.000 VNĐ'));
    expect(review, contains('10/11/2026'));
    expect(review, contains('BÊN A (BÊN VAY)'));
    expect(review, contains('Bên B đồng ý cho Bên A vay'));
  });
}
