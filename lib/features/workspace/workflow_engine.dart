import '../../core/crypto/hash_service.dart';
import '../../core/models/agreement.dart';
import '../../core/models/party_role.dart';
import '../../core/models/party_signature.dart';
import 'workflow_event.dart';
import 'workflow_rules.dart';

class WorkflowEngine {
  static const hash = HashService();
  static Future<SigningSession> apply(
    SigningSession current,
    PartyRole role,
    WorkflowKey key,
    WorkflowAction action, {
    PartySignature? signature,
    String? paymentReference,
  }) async {
    final state = WorkflowRules.next(
      current.state,
      role,
      WorkflowRules.creator(current.draft),
      action,
    );
    final payment = action == WorkflowAction.confirmReceived
        ? PaymentReceipt(
            confirmedByPartyA: true,
            confirmedAt: DateTime.now().toUtc(),
            reference: paymentReference?.trim().isNotEmpty == true
                ? paymentReference!.trim()
                : 'A tự xác nhận; chưa được ngân hàng kiểm chứng',
          )
        : current.payment;
    final digest = hash.canonicalObjectHash(current.draft.toJson());
    final body = <String, dynamic>{
      'domain': 'civiltrust-workflow-event/1',
      'agreementId': current.draft.id,
      'draftDigest': digest,
      'role': role.name,
      'action': action.name,
      'previous': current.events.isEmpty
          ? ''
          : workflowEventHash(current.events.last),
      'detailsHash': action == WorkflowAction.sign
          ? hash.canonicalObjectHash(signature!.toJson())
          : action == WorkflowAction.confirmReceived
          ? hash.canonicalObjectHash(payment!.toJson())
          : '',
    };
    final event = <String, dynamic>{
      'body': body,
      'publicKey': await key.publicKey,
      'signature': await key.sign(body),
    };
    return current.copyWith(
      state: state,
      frozenDigest: digest,
      partyA: role == PartyRole.partyA ? signature : null,
      partyB: role == PartyRole.partyB ? signature : null,
      payment: payment,
      events: [...current.events, event],
    );
  }
}
