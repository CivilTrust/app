import '../../core/models/agreement.dart';
import '../../core/models/party_role.dart';

enum WorkflowAction {
  approve,
  sign,
  reportTransfer,
  confirmReceived,
  requestChanges,
  decline,
  reportIssue,
}

class WorkflowRules {
  static const profile = 'creator-independent/1';
  static const payerProfile = 'payer-proposal/1';
  static bool isPayerProposal(AgreementDraft draft) =>
      draft.fields['workflowProfile'] == payerProfile;
  static bool supports(AgreementDraft draft) =>
      {profile, payerProfile}.contains(draft.fields['workflowProfile']);
  static PartyRole firstSigner(AgreementDraft draft) =>
      isPayerProposal(draft) ? PartyRole.partyA : creator(draft);
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
    WorkflowAction action, {
    bool payerProposal = false,
  }) {
    final first = payerProposal ? PartyRole.partyA : creatorRole;
    switch (action) {
      case WorkflowAction.approve:
        if (state == AgreementState.draft && actor == PartyRole.partyA) {
          return AgreementState.contentFrozen;
        }
      case WorkflowAction.sign:
        if (state == AgreementState.contentFrozen && actor == first) {
          return actor == PartyRole.partyA
              ? AgreementState.partyASigned
              : AgreementState.partyBSigned;
        }
        if ((state == AgreementState.partyASigned &&
                first == PartyRole.partyA &&
                actor == PartyRole.partyB) ||
            (state == AgreementState.partyBSigned &&
                first == PartyRole.partyB &&
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
      case WorkflowAction.requestChanges:
      case WorkflowAction.decline:
        if (payerProposal &&
            state == AgreementState.draft &&
            actor == PartyRole.partyA) {
          return action == WorkflowAction.decline
              ? AgreementState.declined
              : AgreementState.changesRequested;
        }
      case WorkflowAction.reportIssue:
        if (payerProposal &&
            state == AgreementState.paymentPending &&
            actor == PartyRole.partyA) {
          return state;
        }
    }
    throw const FormatException(
      'Hành động không đúng vai trò hoặc trạng thái.',
    );
  }

  static String status(SigningSession session) => switch (session.state) {
    AgreementState.draft =>
      isPayerProposal(session.draft)
          ? 'Đề xuất của B — chờ A đọc danh tính mock và bổ sung tài khoản'
          : 'Đề xuất — chờ A xác nhận thông tin nhận tiền',
    AgreementState.contentFrozen =>
      'Đã khóa — chờ ${firstSigner(session.draft).label} ký trước',
    AgreementState.partyASigned => 'A đã ký — chờ B ký',
    AgreementState.partyBSigned =>
      supports(session.draft) && creator(session.draft) == PartyRole.partyB
          ? 'B đã ký — chờ A ký'
          : 'Đã đủ chữ ký',
    AgreementState.bothSigned => 'Đủ hai chữ ký — chờ B báo chuyển',
    AgreementState.paymentPending =>
      session.response?['action'] == 'reportIssue'
          ? 'A báo chưa thấy tiền/có sai lệch — chưa xác nhận nhận đủ'
          : 'B đã báo chuyển — chờ A xác nhận',
    AgreementState.paymentConfirmed => 'A tự xác nhận nhận tiền',
    AgreementState.changesRequested =>
      'A đề nghị chỉnh sửa — cần đề xuất thay thế',
    AgreementState.declined => 'A đã từ chối đề xuất',
    _ => 'Hồ sơ bằng chứng',
  };
}
