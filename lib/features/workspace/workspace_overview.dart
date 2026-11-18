import 'dart:convert';

import '../../core/crypto/hash_service.dart';
import '../../core/models/agreement.dart';
import '../../core/models/party_role.dart';
import '../../ui/components.dart';
import 'workflow_rules.dart';

/// Short human-friendly code shown in lists and headers, e.g. "CT-3F9A12BC".
/// It is the prefix of the VietQR transfer memo ("CIVILTRUST 3F9A12BC…"), so
/// users can match a bank transaction to a record. Display only; never used
/// as an identifier in protocol data.
String agreementCode(String agreementId) =>
    'CT-${const HashService().keccakHex(utf8.encode(agreementId)).substring(2, 10).toUpperCase()}';

enum RecordBucket { action, waiting, done, draft }

class RecordOverview {
  const RecordOverview({
    required this.bucket,
    required this.headline,
    this.detail,
  });
  final RecordBucket bucket;

  /// What happens next, phrased for this device's user.
  final String headline;
  final String? detail;
}

String _actionText(WorkflowAction action, bool payer) => switch (action) {
  WorkflowAction.approve =>
    payer
        ? 'Bổ sung tài khoản nhận tiền và khóa bản cuối'
        : 'Kiểm tra thông tin nhận tiền và khóa đề xuất',
  WorkflowAction.sign => 'Đọc kỹ và ký hợp đồng',
  WorkflowAction.reportTransfer => 'Chuyển khoản rồi báo đã chuyển',
  WorkflowAction.confirmReceived =>
    'Kiểm tra app ngân hàng và xác nhận đã nhận tiền',
  _ => 'Xử lý hợp đồng',
};

String _waitingText(WorkflowAction action, PartyRole other, bool payer) =>
    switch (action) {
      WorkflowAction.approve =>
        payer
            ? 'Chờ ${other.label} bổ sung tài khoản và khóa bản cuối'
            : 'Chờ ${other.label} kiểm tra và khóa đề xuất',
      WorkflowAction.sign => 'Chờ ${other.label} ký',
      WorkflowAction.reportTransfer => 'Chờ ${other.label} chuyển khoản',
      WorkflowAction.confirmReceived =>
        'Chờ ${other.label} xác nhận đã nhận tiền',
      _ => 'Chờ ${other.label}',
    };

const _mainActions = [
  WorkflowAction.approve,
  WorkflowAction.sign,
  WorkflowAction.reportTransfer,
  WorkflowAction.confirmReceived,
];

WorkflowAction? _allowed(SigningSession session, PartyRole role) {
  for (final action in _mainActions) {
    try {
      WorkflowRules.next(
        session.state,
        role,
        WorkflowRules.creator(session.draft),
        action,
        payerProposal: WorkflowRules.isPayerProposal(session.draft),
      );
      return action;
    } on FormatException {
      continue;
    }
  }
  return null;
}

/// Classifies a stored workspace record for the dashboard.
RecordOverview overviewOf(Map<String, dynamic> record, SigningSession session) {
  if (record['finalized'] == true) {
    return const RecordOverview(
      bucket: RecordBucket.done,
      headline: 'Đã hoàn tất',
      detail: 'Tải gói bằng chứng trong chi tiết hợp đồng.',
    );
  }
  if (session.state == AgreementState.declined) {
    return const RecordOverview(
      bucket: RecordBucket.done,
      headline: 'Bên A đã từ chối đề xuất',
    );
  }
  if (session.state == AgreementState.changesRequested) {
    return const RecordOverview(
      bucket: RecordBucket.done,
      headline: 'Bên A đề nghị chỉnh sửa',
      detail: 'Bên B tạo đề xuất thay thế từ nội dung này.',
    );
  }
  if (record['version'] == 0) {
    return const RecordOverview(
      bucket: RecordBucket.action,
      headline: 'Khôi phục yêu cầu tạo phiên',
      detail: 'Lần gửi trước chưa được xác nhận.',
    );
  }
  if (record['pending'] != null) {
    return const RecordOverview(
      bucket: RecordBucket.action,
      headline: 'Làm mới trạng thái trước khi tiếp tục',
      detail: 'Có thao tác chưa được xác nhận trên mạng; không tự ký lại.',
    );
  }
  final role = PartyRole.values.byName(record['role'] as String);
  final payer = WorkflowRules.isPayerProposal(session.draft);
  if (session.state == AgreementState.paymentConfirmed) {
    return role == PartyRole.partyA
        ? const RecordOverview(
            bucket: RecordBucket.action,
            headline: 'Lưu và gửi gói hồ sơ hoàn tất cho bên kia',
          )
        : const RecordOverview(
            bucket: RecordBucket.waiting,
            headline: 'Chờ Bên A gửi gói hồ sơ hoàn tất',
          );
  }
  final mine = record['readOnly'] == true ? null : _allowed(session, role);
  if (mine != null) {
    return RecordOverview(
      bucket: RecordBucket.action,
      headline: _actionText(mine, payer),
      detail:
          session.state == AgreementState.paymentPending &&
              session.response?['action'] == 'reportIssue'
          ? 'Bạn đã báo chưa thấy tiền; kiểm tra lại ngân hàng.'
          : null,
    );
  }
  final theirs = _allowed(session, role.other);
  return RecordOverview(
    bucket: RecordBucket.waiting,
    headline: theirs == null
        ? WorkflowRules.status(session)
        : _waitingText(theirs, role.other, payer),
    detail: record['readOnly'] == true
        ? 'Thiết bị chỉ xem: cần gói khôi phục từ thiết bị đã thao tác.'
        : null,
  );
}

/// Ordered progress of one agreement. Times come only from signed/recorded
/// values (signature, transfer report, receipt confirmation).
List<TimelineEntry> timelineOf(
  SigningSession session, {
  bool finalized = false,
}) {
  final payer = WorkflowRules.isPayerProposal(session.draft);
  PartyRole? creator;
  try {
    creator = WorkflowRules.creator(session.draft);
  } on FormatException {
    creator = null;
  }
  final first = payer ? PartyRole.partyA : (creator ?? PartyRole.partyA);
  final second = first.other;
  DateTime? signedAt(PartyRole role) => role == PartyRole.partyA
      ? session.partyA?.signedAt
      : session.partyB?.signedAt;
  final labels = <(String, DateTime?)>[
    (
      payer
          ? 'Bên B gửi đề xuất'
          : '${(creator ?? PartyRole.partyA).label} tạo hợp đồng',
      session.draft.createdAt,
    ),
    (
      payer
          ? 'Bên A bổ sung tài khoản và khóa nội dung'
          : 'Bên A duyệt thông tin nhận tiền, khóa nội dung',
      null,
    ),
    ('${first.label} ký', signedAt(first)),
    ('${second.label} ký', signedAt(second)),
    (
      'Bên B báo đã chuyển khoản',
      DateTime.tryParse(session.transfer?['reportedAt']?.toString() ?? ''),
    ),
    ('Bên A xác nhận đã nhận tiền', session.payment?.confirmedAt),
    ('Gói hồ sơ hoàn tất được gửi cho hai bên', null),
  ];
  final reached = switch (session.state) {
    AgreementState.draft ||
    AgreementState.changesRequested ||
    AgreementState.declined => 1,
    AgreementState.contentFrozen => 2,
    AgreementState.partyASigned || AgreementState.partyBSigned => 3,
    AgreementState.bothSigned => 4,
    AgreementState.paymentPending => 5,
    AgreementState.paymentConfirmed => finalized ? 7 : 6,
    _ => finalized ? 7 : 6,
  };
  final closed =
      session.state == AgreementState.declined ||
      session.state == AgreementState.changesRequested;
  return [
    for (var i = 0; i < labels.length; i++)
      TimelineEntry(
        labels[i].$1,
        done: i < reached,
        current: !closed && i == reached,
        at: i < reached ? labels[i].$2 : null,
      ),
  ];
}
