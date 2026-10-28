import 'package:civiltrust_app/core/models/agreement.dart';
import 'package:civiltrust_app/core/models/party_role.dart';
import 'package:civiltrust_app/features/workspace/workflow_rules.dart';
import 'package:civiltrust_app/features/workspace/workflow_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final creator in PartyRole.values) {
    test(
      '${creator.name} creates; receiver A approves; creator signs first',
      () {
        var state = WorkflowRules.next(
          AgreementState.draft,
          PartyRole.partyA,
          creator,
          WorkflowAction.approve,
        );
        state = WorkflowRules.next(
          state,
          creator,
          creator,
          WorkflowAction.sign,
        );
        state = WorkflowRules.next(
          state,
          creator.other,
          creator,
          WorkflowAction.sign,
        );
        expect(state, AgreementState.bothSigned);
        state = WorkflowRules.next(
          state,
          PartyRole.partyB,
          creator,
          WorkflowAction.reportTransfer,
        );
        expect(
          WorkflowRules.next(
            state,
            PartyRole.partyA,
            creator,
            WorkflowAction.confirmReceived,
          ),
          AgreementState.paymentConfirmed,
        );
      },
    );
    test(
      '${creator.name} ownership never grants wrong payment or signing role',
      () {
        expect(
          () => WorkflowRules.next(
            AgreementState.draft,
            PartyRole.partyB,
            creator,
            WorkflowAction.approve,
          ),
          throwsFormatException,
        );
        expect(
          () => WorkflowRules.next(
            AgreementState.contentFrozen,
            creator.other,
            creator,
            WorkflowAction.sign,
          ),
          throwsFormatException,
        );
        expect(
          () => WorkflowRules.next(
            AgreementState.paymentPending,
            PartyRole.partyB,
            creator,
            WorkflowAction.confirmReceived,
          ),
          throwsFormatException,
        );
        expect(
          () => WorkflowRules.next(
            AgreementState.bothSigned,
            PartyRole.partyA,
            creator,
            WorkflowAction.reportTransfer,
          ),
          throwsFormatException,
        );
      },
    );
  }
  test(
    'action key can be restored and verifies only exact canonical message',
    () async {
      final key = await WorkflowKey.create();
      final body = <String, dynamic>{
        'action': 'approve',
        'version': 1,
        'sessionId': 'synthetic',
      };
      final signature = await key.sign(body);
      expect(
        await WorkflowKey.verify(
          body,
          await WorkflowKey(key.seed).publicKey,
          signature,
        ),
        isTrue,
      );
      expect(
        await WorkflowKey.verify(
          {...body, 'version': 2},
          await key.publicKey,
          signature,
        ),
        isFalse,
      );
    },
  );
}
