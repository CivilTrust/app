import '../../core/models/agreement.dart';
import '../../core/models/party_role.dart';

enum WorkflowAction { approve, sign, reportTransfer, confirmReceived }

class WorkflowRules {
  static const profile = 'creator-independent/1';
  static bool supports(AgreementDraft draft) =>
      draft.fields['workflowProfile'] == profile;
  static PartyRole creator(AgreementDraft draft) {
    if (!supports(draft)) {
      throw const FormatException('Unknown workflow profile');
    }
    return PartyRole.values.byName(draft.fields['creatorRole']!);
  }

  /// Business roles never follow the transport owner flag. Money is B -> A.
  static AgreementState next(
    AgreementState state,
    PartyRole actor,
    PartyRole creatorRole,
    WorkflowAction action,
  ) {
    switch (action) {
      case WorkflowAction.approve:
        if (state == AgreementState.draft && actor == PartyRole.partyA) {
          return AgreementState.contentFrozen;
        }
      case WorkflowAction.sign:
        if (state == AgreementState.contentFrozen && actor == creatorRole) {
          return actor == PartyRole.partyA
              ? AgreementState.partyASigned
              : AgreementState.partyBSigned;
        }
        if ((state == AgreementState.partyASigned &&
                creatorRole == PartyRole.partyA &&
                actor == PartyRole.partyB) ||
            (state == AgreementState.partyBSigned &&
                creatorRole == PartyRole.partyB &&
                actor == PartyRole.partyA)) {
          return AgreementState.bothSigned;
        }
      case WorkflowAction.reportTransfer:
        if (state == AgreementState.bothSigned && actor == PartyRole.partyB) {
          return AgreementState.paymentPending;
        }
      case WorkflowAction.confirmReceived:
        if (state == AgreementState.paymentPending &&
            actor == PartyRole.partyA) {
          return AgreementState.paymentConfirmed;
        }
    }
    throw const FormatException(
      'Hành động không đúng vai trò hoặc trạng thái.',
    );
  }

  static String status(SigningSession session) => switch (session.state) {
    AgreementState.draft => 'Đề xuất — chờ A xác nhận thông tin nhận tiền',
    AgreementState.contentFrozen =>
      'Đã khóa — chờ ${creator(session.draft).label} ký trước',
    AgreementState.partyASigned => 'A đã ký — chờ B ký',
    AgreementState.partyBSigned =>
      supports(session.draft) && creator(session.draft) == PartyRole.partyB
          ? 'B đã ký — chờ A ký'
          : 'Đã đủ chữ ký',
    AgreementState.bothSigned => 'Đủ hai chữ ký — chờ B báo chuyển',
    AgreementState.paymentPending => 'B đã báo chuyển — chờ A xác nhận',
    AgreementState.paymentConfirmed => 'A tự xác nhận nhận tiền',
    _ => 'Hồ sơ bằng chứng',
  };
}
