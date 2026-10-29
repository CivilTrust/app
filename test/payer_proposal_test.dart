import 'dart:convert';

import 'package:civiltrust_app/core/models/agreement.dart';
import 'package:civiltrust_app/core/models/party_role.dart';
import 'package:civiltrust_app/features/workspace/payer_proposal.dart';
import 'package:civiltrust_app/features/workspace/workflow_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new B signs after A while legacy B continues to sign first', () {
    expect(
      WorkflowRules.next(
        AgreementState.contentFrozen,
        PartyRole.partyA,
        PartyRole.partyB,
        WorkflowAction.sign,
        payerProposal: true,
      ),
      AgreementState.partyASigned,
    );
    expect(
      () => WorkflowRules.next(
        AgreementState.contentFrozen,
        PartyRole.partyB,
        PartyRole.partyB,
        WorkflowAction.sign,
        payerProposal: true,
      ),
      throwsFormatException,
    );
    expect(
      WorkflowRules.next(
        AgreementState.contentFrozen,
        PartyRole.partyB,
        PartyRole.partyB,
        WorkflowAction.sign,
      ),
      AgreementState.partyBSigned,
    );
    expect(
      () => WorkflowRules.next(
        AgreementState.draft,
        PartyRole.partyA,
        PartyRole.partyA,
        WorkflowAction.decline,
      ),
      throwsFormatException,
    );
    expect(
      WorkflowRules.next(
        AgreementState.paymentPending,
        PartyRole.partyA,
        PartyRole.partyB,
        WorkflowAction.reportIssue,
        payerProposal: true,
      ),
      AgreementState.paymentPending,
    );
  });
  test(
    'B report supports no attachment and verifies MIME, size and content hash',
    () {
      final report = TransferEvidence.create(
        agreementId: 'synthetic',
        reference: 'optional',
      );
      expect(report.containsKey('attachment'), false);
      TransferEvidence.validate(report, 'synthetic');
      final attached = TransferEvidence.create(
        agreementId: 'synthetic',
        reference: 'reference',
        bytes: utf8.encode('%PDF-1.4\nSynthetic fixture'),
      );
      TransferEvidence.validate(attached, 'synthetic');
      (attached['attachment'] as Map)['hash'] = 'TAMPER';
      expect(
        () => TransferEvidence.validate(attached, 'synthetic'),
        throwsFormatException,
      );
      expect(
        () => TransferEvidence.create(
          agreementId: 'synthetic',
          reference: '',
          bytes: utf8.encode('<script>not a document</script>'),
        ),
        throwsFormatException,
      );
      expect(
        () => TransferEvidence.create(
          agreementId: 'synthetic',
          reference: '',
          bytes: List.filled(TransferEvidence.maxAttachmentBytes + 1, 0),
        ),
        throwsFormatException,
      );
      expect(
        () => TransferEvidence.validate(report, 'another-contract'),
        throwsFormatException,
      );
    },
  );
  test('A may fill recipient fields but not rewrite B commercial terms', () {
    final base = AgreementDraft(
      id: 'synthetic',
      title: 'title',
      terms: 'unchanged',
      amountVnd: 100,
      createdAt: DateTime.utc(2026),
      fields: {
        'workflowProfile': WorkflowRules.payerProfile,
        'creatorRole': 'partyB',
      },
    );
    AgreementDraft copy({
      String terms = 'unchanged',
      Map<String, String> fields = const {},
    }) => AgreementDraft(
      id: base.id,
      title: base.title,
      terms: terms,
      amountVnd: base.amountVnd,
      createdAt: base.createdAt,
      fields: {...base.fields, ...fields},
    );
    expect(
      proposalTermsDigest(
        copy(
          fields: {
            'accountNumber': 'synthetic',
            'partyAIdentitySummary': 'mock',
            'proposalDigest': 'ignored',
          },
        ),
      ),
      proposalTermsDigest(base),
    );
    expect(
      proposalTermsDigest(copy(terms: 'changed')),
      isNot(proposalTermsDigest(base)),
    );
  });
}
