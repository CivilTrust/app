import '../../core/crypto/hash_service.dart';
import '../../core/encoding/encoding_utils.dart';
import '../../core/models/agreement.dart';
import '../../core/models/party_role.dart';
import '../payment/payment_details.dart';
import '../signing/party_signer.dart';
import '../signing/signing_context.dart';
import 'workflow_event.dart';
import 'workflow_rules.dart';

Future<void> validateWorkflow(
  SigningSession session,
  HashService hash,
  PartySigner signer, {
  bool requireBoth = false,
}) async {
  final creator = WorkflowRules.creator(session.draft);
  final fields = session.draft.fields;
  if (fields['payerRole'] != 'partyB' ||
      fields['payeeRole'] != 'partyA' ||
      fields['signingProtocol'] != SigningContext.protocol ||
      int.tryParse(fields['revision'] ?? '') == null) {
    throw const FormatException('Workflow metadata không hợp lệ.');
  }
  PaymentDetails.fromDraft(session.draft);
  final digest = hash.canonicalObjectHash(session.draft.toJson());
  var state = AgreementState.draft;
  var previous = '';
  final signatures = {'partyA': session.partyA, 'partyB': session.partyB};
  final signedRoles = <String>{};
  if (session.events.length > 6) {
    throw const FormatException('Quá nhiều workflow event.');
  }
  for (final event in session.events) {
    final body = Map<String, dynamic>.from(event['body'] as Map);
    final action = WorkflowAction.values.byName(body['action'] as String);
    final role = PartyRole.values.byName(body['role'] as String);
    final key = event['publicKey'] as String;
    var detailsHash = '';
    if (action == WorkflowAction.sign) {
      final signature = signatures[role.name];
      if (signature == null ||
          signature.schemaVersion != 2 ||
          signature.role != role.name ||
          signature.signedDigest != digest ||
          signature.envelope?['agreementId'] != session.draft.id ||
          signature.envelope?['ceremonyId'] != fields['identityCeremonyId'] ||
          !await signer.verify(signature)) {
        throw const FormatException('Chữ ký workflow không hợp lệ.');
      }
      detailsHash = hash.canonicalObjectHash(signature.toJson());
      signedRoles.add(role.name);
    } else if (action == WorkflowAction.confirmReceived) {
      if (session.payment?.confirmedByPartyA != true) {
        throw const FormatException('Thiếu xác nhận của A.');
      }
      detailsHash = hash.canonicalObjectHash(session.payment!.toJson());
    }
    final expected = <String, dynamic>{
      'domain': 'civiltrust-workflow-event/1',
      'agreementId': session.draft.id,
      'draftDigest': digest,
      'role': role.name,
      'action': action.name,
      'previous': previous,
      'detailsHash': detailsHash,
    };
    if (canonicalJson(body) != canonicalJson(expected) ||
        event.keys.toSet().difference({
          'body',
          'publicKey',
          'signature',
        }).isNotEmpty ||
        !await WorkflowKey.verify(body, key, event['signature'] as String)) {
      throw const FormatException('Workflow event đã bị thay đổi.');
    }
    final identityKey =
        (signatures[role.name]?.identity['attributes']
            as Map?)?['workspaceActionKey'];
    if (signatures[role.name] != null && identityKey != key) {
      throw const FormatException('Khóa hành động không khớp người ký.');
    }
    state = WorkflowRules.next(state, role, creator, action);
    previous = workflowEventHash(event);
  }
  for (final entry in signatures.entries) {
    if ((entry.value != null) != signedRoles.contains(entry.key)) {
      throw const FormatException('Chữ ký thiếu event tương ứng.');
    }
  }
  if (requireBoth && signedRoles.length != 2) {
    throw const FormatException('Chưa đủ hai chữ ký.');
  }
  final paid = state == AgreementState.paymentConfirmed;
  if ((session.payment != null) != paid) {
    throw const FormatException('Xác nhận thanh toán không đúng trạng thái.');
  }
  final actual = session.state == AgreementState.committedPendingAnchor && paid
      ? AgreementState.paymentConfirmed
      : session.state;
  if (actual != state ||
      (state != AgreementState.draft && session.frozenDigest != digest) ||
      (state == AgreementState.draft && session.frozenDigest != null)) {
    throw const FormatException('Trạng thái không khớp chuỗi bằng chứng.');
  }
}
