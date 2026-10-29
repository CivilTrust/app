import '../../core/crypto/hash_service.dart';
import '../../core/encoding/encoding_utils.dart';
import '../../core/models/agreement.dart';
import '../../core/models/party_role.dart';
import '../payment/payment_details.dart';
import '../signing/party_signer.dart';
import '../signing/signing_context.dart';
import 'workflow_event.dart';
import 'workflow_rules.dart';
import 'payer_proposal.dart';

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
  final payer = WorkflowRules.isPayerProposal(session.draft);
  if (payer && creator != PartyRole.partyB) {
    throw const FormatException('Profile đề xuất B chỉ dành cho B tạo.');
  }
  if (!payer ||
      session.events.any((e) => (e['body'] as Map)['action'] == 'approve')) {
    PaymentDetails.fromDraft(session.draft);
  }
  if (payer &&
      session.events.any((e) => (e['body'] as Map)['action'] == 'approve') &&
      (fields['partyAIdentityCommitment']?.isNotEmpty != true ||
          fields['partyAIdentitySummary']?.isNotEmpty != true ||
          fields['proposalDigest'] != proposalTermsDigest(session.draft))) {
    throw const FormatException(
      'Thiếu danh tính A hoặc điều khoản đề xuất đã bị sửa.',
    );
  }
  final digest = hash.canonicalObjectHash(session.draft.toJson());
  var state = AgreementState.draft;
  var previous = '';
  final signatures = {'partyA': session.partyA, 'partyB': session.partyB};
  final signedRoles = <String>{};
  if (session.events.length > (payer ? 7 : 6)) {
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
    } else if (payer && action == WorkflowAction.reportTransfer) {
      if (session.transfer == null) {
        throw const FormatException('Thiếu thông báo chuyển khoản của B.');
      }
      TransferEvidence.validate(session.transfer!, session.draft.id);
      detailsHash = hash.canonicalObjectHash(session.transfer!);
    } else if (payer &&
        {
          WorkflowAction.requestChanges,
          WorkflowAction.decline,
          WorkflowAction.reportIssue,
        }.contains(action)) {
      if (session.response?['action'] != action.name ||
          session.response?['note'] is! String ||
          (session.response!['note'] as String).trim().isEmpty ||
          (session.response!['note'] as String).length > 500) {
        throw const FormatException('Thiếu phản hồi của A.');
      }
      detailsHash = hash.canonicalObjectHash(session.response!);
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
    state = WorkflowRules.next(
      state,
      role,
      creator,
      action,
      payerProposal: payer,
    );
    previous = workflowEventHash(event);
  }
  if (session.transfer != null &&
      (!payer ||
          !session.events.any(
            (e) => (e['body'] as Map)['action'] == 'reportTransfer',
          ))) {
    throw const FormatException('Thông báo chuyển khoản không có event.');
  }
  if (session.response != null &&
      (!payer ||
          session.events
                  .where(
                    (e) =>
                        (e['body'] as Map)['action'] ==
                        session.response!['action'],
                  )
                  .length !=
              1)) {
    throw const FormatException('Phản hồi không khớp event.');
  }
  if (payer &&
      session.partyA != null &&
      session.partyA!.identity['identityCommitment'] !=
          fields['partyAIdentityCommitment']) {
    throw const FormatException('Danh tính A thay đổi sau khi khóa.');
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
      (!{
            AgreementState.draft,
            AgreementState.changesRequested,
            AgreementState.declined,
          }.contains(state) &&
          session.frozenDigest != digest) ||
      (state == AgreementState.draft && session.frozenDigest != null)) {
    throw const FormatException('Trạng thái không khớp chuỗi bằng chứng.');
  }
}
