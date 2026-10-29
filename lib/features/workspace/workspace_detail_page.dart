import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/encoding/encoding_utils.dart';

import '../../app/flow_widgets.dart';
import '../../core/config/app_config.dart';
import '../../core/config/environment_check.dart';
import '../../core/models/agreement.dart';
import '../../core/models/identity_evidence.dart';
import '../../core/models/party_role.dart';
import '../identity/identity_context.dart';
import '../identity/identity_service.dart';
import '../payment/payment_details.dart';
import '../payment/payment_qr_card.dart';
import '../sessions/invite_url.dart';
import 'workflow_rules.dart';
import 'workspace_artifacts.dart';
import 'workspace_service.dart';
import 'payer_proposal.dart';

class WorkspaceDetailPage extends StatefulWidget {
  const WorkspaceDetailPage({
    required this.service,
    required this.localId,
    required this.config,
    required this.unlock,
    required this.copyDraft,
    super.key,
  });
  final WorkspaceService service;
  final String localId;
  final AppConfig config;
  final Future<bool> Function() unlock;
  final Future<void> Function(Map<String, dynamic>) copyDraft;
  @override
  State<WorkspaceDetailPage> createState() => _WorkspaceDetailPageState();
}

class _WorkspaceDetailPageState extends State<WorkspaceDetailPage>
    with WidgetsBindingObserver {
  late final identity = IdentityService.forMode(widget.config.identityMode);
  late final artifacts = WorkspaceArtifacts(widget.service, widget.config);
  final bank = {
    for (final key in ['bankBin', 'accountNumber', 'accountName'])
      key: TextEditingController(),
  };
  final reference = TextEditingController();
  final feedback = TextEditingController();
  Uint8List? attachment;
  IdentityEvidence? recipientPreview;
  bool transferDeclared = false, attachmentReviewed = false;
  bool busy = false, reviewed = false, consent = false, received = false;
  String message = '';
  Map<String, dynamic> get record => widget.service.record(widget.localId);
  SigningSession get session => widget.service.session(record);
  @override
  void initState() {
    super.initState();
    widget.service.vault.addListener(changed);
    WidgetsBinding.instance.addObserver(this);
    loadBank();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) refresh();
    });
  }

  void loadBank() {
    if (!widget.service.vault.unlocked) return;
    for (final entry in bank.entries) {
      entry.value.text = session.draft.fields[entry.key] ?? '';
    }
  }

  void changed() {
    if (!mounted) return;
    if (!widget.service.vault.unlocked) {
      for (final controller in bank.values) {
        controller.clear();
      }
      reference.clear();
      feedback.clear();
      recipientPreview = null;
      attachment = null;
      transferDeclared = false;
      attachmentReviewed = false;
      reviewed = false;
      consent = false;
      received = false;
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) identity.cancel();
  }

  @override
  void dispose() {
    widget.service.vault.removeListener(changed);
    WidgetsBinding.instance.removeObserver(this);
    identity.dispose();
    for (final c in bank.values) {
      c.dispose();
    }
    reference.dispose();
    feedback.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => message = e.toString());
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> refresh() => run(() async {
    await widget.service.sync(widget.localId);
    if (!mounted) return;
    loadBank();
    recipientPreview = null;
    reviewed = false;
    consent = false;
    received = false;
    message = 'Đã đồng bộ và kiểm chuỗi chữ ký. Danh tính vẫn là mock; trạng thái tiền là tự khai.';
    if (WorkflowRules.isPayerProposal(session.draft) &&
        session.partyA != null &&
        session.partyB != null &&
        record['pending'] == null) {
      try {
        await artifacts.savePayerStage(widget.localId);
      } catch (_) {
        message = 'Đã đồng bộ. Chưa lưu/tải được gói PDF nguyên bản; dùng nút lưu hồ sơ để thử lại, không ký lại.';
      }
    }
    if (record['finalized'] == true && record['archive'] == null) {
      await artifacts.fetch(widget.localId);
    }
  });
  bool allows(WorkflowAction action) {
    if (busy ||
        record['readOnly'] == true ||
        record['pending'] != null ||
        record['version'] == 0 ||
        record['finalized'] == true) {
      return false;
    }
    try {
      WorkflowRules.next(
        session.state,
        PartyRole.values.byName(record['role'] as String),
        WorkflowRules.creator(session.draft),
        action,
        payerProposal: WorkflowRules.isPayerProposal(session.draft),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> act(WorkflowAction action) => run(() async {
    final before = record['version'];
    final bankValues = {
      for (final e in bank.entries) e.key: e.value.text.trim(),
    };
    final fresh = await widget.service.sync(widget.localId);
    if (fresh['version'] != before) {
      loadBank();
      recipientPreview = null;
      reviewed = false;
      consent = false;
      received = false;
      throw StateError(
        'Phiên đã thay đổi. Xem lại trạng thái/nội dung mới rồi xác nhận lại.',
      );
    }
    await widget.service.act(
      widget.localId,
      action,
      identityService: identity,
      consent: consent && reviewed,
      bankFields: action == WorkflowAction.approve ? bankValues : null,
      paymentReference: reference.text,
      attachment: attachment,
      responseNote: feedback.text,
      recipientEvidence: recipientPreview,
    );
    reviewed = false;
    recipientPreview = null;
    consent = false;
    received = false;
    loadBank();
    message = 'Đã lưu và đồng bộ thao tác ${action.name}.';
    if (WorkflowRules.isPayerProposal(session.draft) &&
        session.partyA != null &&
        session.partyB != null) {
      try {
        if (action == WorkflowAction.confirmReceived) {
          await artifacts.finalize(widget.localId);
        } else {
          await artifacts.savePayerStage(widget.localId);
        }
        message = 'Đã đồng bộ thao tác và lưu gói hồ sơ. PDF hợp đồng nguyên bản không đổi; thanh toán là ghi nhận riêng.';
        attachment = null;
        transferDeclared = false;
        attachmentReviewed = false;
        reference.clear();
      } catch (_) {
        message = 'Thao tác đã đồng bộ; gói hồ sơ chưa hoàn tất lưu/công bố. Làm mới hoặc dùng nút lưu hồ sơ để tiếp tục, không ký/báo chuyển lại.';
      }
    }
  });
  Future<void> pickAttachment() => run(() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'pdf'],
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > TransferEvidence.maxAttachmentBytes) {
      throw const FormatException('Chứng từ tối đa 1 MiB.');
    }
    TransferEvidence.mime(bytes);
    attachment = bytes;
    attachmentReviewed = false;
  });
  Future<void> readRecipient() => run(() async {
    final value = await identity.identify(
      context: IdentityContext.create(
        ceremonyId: session.draft.fields['identityCeremonyId']!,
        role: 'partyA',
      ),
      consent: consent,
    );
    if (!mounted || !widget.service.vault.unlocked) return;
    recipientPreview = value;
    if (bank['bankBin']!.text.isEmpty) bank['bankBin']!.text = '970436';
    if (bank['accountName']!.text.isEmpty) {
      bank['accountName']!.text = value.displayName;
    }
    reviewed = false;
    message = 'Đã đọc danh tính mock A. Nhập và kiểm tra tài khoản nhận tiền trước khi khóa bản cuối.';
  });
  Future<void> download() => run(() async {
    final bundle = await artifacts.local(widget.localId);
    await FileSaver.instance.saveFile(
      name: 'civiltrust-${session.draft.id}',
      bytes: bundle.zip,
      fileExtension: 'zip',
      mimeType: MimeType.zip,
    );
  });
  @override
  Widget build(BuildContext context) {
    if (!widget.service.vault.unlocked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kho đã khóa')),
        body: Center(
          child: FilledButton(
            onPressed: () async {
              if (await widget.unlock()) {
                loadBank();
                if (mounted) await refresh();
              }
            },
            child: const Text('Mở khóa để xem hợp đồng'),
          ),
        ),
      );
    }
    final current = session, local = record;
    final role = PartyRole.values.byName(local['role'] as String);
    final payerProposal = WorkflowRules.isPayerProposal(current.draft);
    final pendingRecipient =
        payerProposal &&
        !current.events.any((e) => (e['body'] as Map)['action'] == 'approve');
    final payment = pendingRecipient
        ? null
        : PaymentDetails.fromDraft(current.draft);
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết hợp đồng')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FlowHeader(
            title: current.draft.title,
            subtitle:
                '${role.label} · ${role.businessLabel(current.draft.templateId)} · ${local['isOwner'] == true ? 'Người tạo' : 'Người được mời'}',
          ),
          TrustNotice(
            title: WorkflowRules.status(current),
            message:
                'Bản lưu gần nhất: ${local['lastSyncedAt'] ?? 'chưa đồng bộ'}. Hết hạn truy cập server: ${local['expiresAt'] ?? 'chưa có'}. Không dùng trạng thái cũ làm kết luận mới nhất.',
          ),
          if (!payerProposal &&
              WorkflowRules.creator(current.draft) == PartyRole.partyB)
            const TrustNotice(
              title: 'Hồ sơ B tạo ở phiên bản cũ',
              message: 'Phiên này giữ nguyên quy tắc B ký trước, A ký sau. Chỉ đề xuất B tạo mới áp dụng A ký trước; không tự đổi thứ tự của hồ sơ đang có.',
            ),
          if (busy) const LinearProgressIndicator(),
          if (message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(message),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: busy ? null : refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Làm mới trạng thái'),
              ),
              if (local['version'] == 0)
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => run(() async {
                          await widget.service.resumeCreation(widget.localId);
                        }),
                  child: const Text('Khôi phục yêu cầu tạo phiên'),
                ),
              if (local['isOwner'] == true)
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => run(() async {
                          final code = widget.service.invite(record);
                          final url =
                              {'http', 'https'}.contains(Uri.base.scheme)
                              ? buildInviteUrl(Uri.base, code)
                              : 'join=$code';
                          await Clipboard.setData(ClipboardData(text: url));
                          message =
                              'Đã sao chép lời mời riêng cho ${WorkflowRules.creator(current.draft).other.label}. Không gửi gói khôi phục.';
                        }),
                  child: const Text('Sao chép lời mời đối tác'),
                ),
            ],
          ),
          if (local['pending'] != null)
            const Text(
              'Có thao tác chưa xác nhận trên mạng. Làm mới trước khi tiếp tục, không tự ký lại.',
            ),
          if (local['readOnly'] == true)
            const Text(
              'Thiết bị này thiếu khóa hành động gốc. Có thể xem/tải; cần nhập gói khôi phục từ thiết bị đã thao tác để tiếp tục.',
            ),
          const SizedBox(height: 16),
          SectionCard(
            title:
                'Nội dung và revision ${current.draft.fields['revision'] ?? '1'}',
            icon: Icons.description_outlined,
            child: SelectableText(current.draft.terms),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Thông tin nhận tiền của A',
            icon: Icons.account_balance,
            child: Column(
              children: [
                SelectableText(
                  payment?.copyText ??
                      'Chờ A tự cung cấp tài khoản. B không cần nhập thay.',
                ),
                if (payerProposal &&
                    current.draft.fields['partyAIdentitySummary'] != null)
                  SelectableText(
                    'A bổ sung: ${current.draft.fields['partyAIdentitySummary']}',
                  ),
                if (current.state == AgreementState.draft &&
                    role == PartyRole.partyA) ...[
                  const Text(
                    'A kiểm tra/sửa tài khoản nhận trước khi duyệt. Đây không phải xác nhận quyền sở hữu tài khoản từ ngân hàng.',
                  ),
                  if (payerProposal) ...[
                    CheckboxListTile(
                      value: consent,
                      onChanged: busy
                          ? null
                          : (v) => setState(() => consent = v ?? false),
                      title: const Text(
                        'Tôi đồng ý đọc danh tính mock của A; chưa có NFC thật.',
                      ),
                    ),
                    OutlinedButton(
                      onPressed: busy || !consent ? null : readRecipient,
                      child: const Text(
                        'Đọc CCCD mock của A trước khi điền tài khoản',
                      ),
                    ),
                    if (recipientPreview != null)
                      SelectableText(
                        'Danh tính A: ${recipientPreview!.displayName} · ${recipientPreview!.documentNumberMasked}',
                      ),
                  ],
                  for (final name in bank.keys)
                    TextField(
                      controller: bank[name],
                      enabled:
                          !busy && (!payerProposal || recipientPreview != null),
                      onChanged: payerProposal
                          ? (_) => setState(() => reviewed = false)
                          : null,
                      decoration: InputDecoration(
                        labelText: switch (name) {
                          'bankBin' => 'BIN ngân hàng',
                          'accountNumber' => 'Số tài khoản nhận tiền',
                          _ => 'Tên người nhận do A xác nhận',
                        },
                      ),
                    ),
                  CheckboxListTile(
                    value: reviewed,
                    onChanged: busy
                        ? null
                        : (v) => setState(() => reviewed = v ?? false),
                    title: const Text(
                      'Tôi là A, đã xem điều khoản và kiểm tra thông tin nhận tiền.',
                    ),
                  ),
                  FilledButton(
                    onPressed:
                        allows(WorkflowAction.approve) &&
                            reviewed &&
                            (!payerProposal ||
                                (consent && recipientPreview != null))
                        ? () => act(WorkflowAction.approve)
                        : null,
                    child: Text(
                      payerProposal
                          ? 'A xác nhận và khóa bản cuối'
                          : 'A duyệt và khóa đề xuất',
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (allows(WorkflowAction.sign)) ...[
            const SizedBox(height: 12),
            TrustNotice(
              title: 'Ký đúng vai trò bằng danh tính mock',
              message: identity.notice,
            ),
            if (payerProposal && role == PartyRole.partyB)
              const Text(
                'A đã ký. Hãy kiểm tra danh tính A, ngân hàng, số tài khoản và tên nhận bên trên. Điều khoản B đề xuất được giữ nguyên; bạn ký trước khi mở VietQR.',
              ),
            CheckboxListTile(
              value: reviewed,
              onChanged: (v) => setState(() => reviewed = v ?? false),
              title: const Text(
                'Tôi đã đọc nội dung, thông tin nhận tiền và đồng ý ký bản đã khóa.',
              ),
            ),
            CheckboxListTile(
              value: consent,
              onChanged: (v) => setState(() => consent = v ?? false),
              title: const Text(
                'Tôi đồng ý đọc mới danh tính mô phỏng cho lần ký này.',
              ),
            ),
            FilledButton(
              onPressed: reviewed && consent
                  ? () => act(WorkflowAction.sign)
                  : null,
              child: Text('${role.label} đọc danh tính mới và ký'),
            ),
          ],
          if (current.partyA != null && current.partyB != null) ...[
            const SizedBox(height: 12),
            PaymentQrCard(draft: current.draft),
          ],
          if (allows(WorkflowAction.reportTransfer) && !payerProposal)
            FilledButton(
              onPressed: () => act(WorkflowAction.reportTransfer),
              child: const Text('B báo đã chuyển tiền (tự khai)'),
            ),
          if (payerProposal && allows(WorkflowAction.reportTransfer)) ...[
            const Text(
              'Chuyển khoản ngoài CivilTrust rồi quay lại báo chuyển. Mở QR không đồng nghĩa thanh toán thành công. Chứng từ là tùy chọn, chưa được ngân hàng kiểm chứng.',
            ),
            TextField(
              controller: reference,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Mã tham chiếu giao dịch (không bắt buộc)',
              ),
            ),
            OutlinedButton(
              onPressed: busy ? null : pickAttachment,
              child: const Text('Chọn chứng từ PNG/JPEG/PDF, tối đa 1 MiB'),
            ),
            if (attachment != null) ...[
              if (TransferEvidence.mime(attachment!).startsWith('image/'))
                Image.memory(
                  attachment!,
                  height: 180,
                  errorBuilder: (_, error, stack) => const Text(
                    'Ảnh không xem trước được; hãy bỏ tệp hoặc chọn ảnh khác.',
                  ),
                )
              else
                const Text(
                  'Đã chọn PDF. Hãy kiểm tra và che dữ liệu nhạy cảm trước khi gửi.',
                ),
              TextButton(
                onPressed: () => setState(() {
                  attachment = null;
                  attachmentReviewed = false;
                }),
                child: const Text('Bỏ chứng từ'),
              ),
              CheckboxListTile(
                value: attachmentReviewed,
                onChanged: (v) =>
                    setState(() => attachmentReviewed = v ?? false),
                title: const Text(
                  'Tôi đã kiểm tra tệp và loại bỏ thông tin nhạy cảm không cần thiết. Tệp sẽ được chia sẻ mã hóa với A.',
                ),
              ),
            ],
            CheckboxListTile(
              value: transferDeclared,
              onChanged: (v) => setState(() => transferDeclared = v ?? false),
              title: const Text(
                'Tôi là B, đã thực hiện chuyển khoản; không chỉ mở màn hình QR.',
              ),
            ),
            FilledButton(
              onPressed:
                  transferDeclared &&
                      (attachment == null || attachmentReviewed) &&
                      record['signedArtifactReady'] == true
                  ? () => act(WorkflowAction.reportTransfer)
                  : null,
              child: const Text(
                'B gửi thông báo chuyển khoản và lưu bằng chứng',
              ),
            ),
          ],
          if (payerProposal && current.transfer != null) ...[
            Text(
              'B tự báo chuyển: ${current.transfer!['reference']} · ${current.transfer!['reportedAt']}',
            ),
            Text(
              current.transfer!['attachment'] == null
                  ? 'Không có chứng từ đính kèm. Chờ A kiểm tra ngân hàng.'
                  : 'Có chứng từ do B cung cấp; chưa được ngân hàng kiểm chứng.',
            ),
            if (current.transfer!['attachment'] is Map &&
                ((current.transfer!['attachment'] as Map)['mime'] as String)
                    .startsWith('image/'))
              Image.memory(
                Uint8List.fromList(
                  base64UrlDecodeNoPadding(
                    (current.transfer!['attachment'] as Map)['bytes'] as String,
                  ),
                ),
                height: 180,
                errorBuilder: (_, error, stack) =>
                    const Text('Không xem trước được ảnh chứng từ.'),
              ),
            if (current.transfer!['attachment'] is Map)
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => run(() async {
                        final data = current.transfer!['attachment'] as Map;
                        await FileSaver.instance.saveFile(
                          name: 'civiltrust-transfer',
                          bytes: Uint8List.fromList(
                            base64UrlDecodeNoPadding(data['bytes'] as String),
                          ),
                          fileExtension: data['mime'] == 'application/pdf'
                              ? 'pdf'
                              : data['mime'] == 'image/png'
                              ? 'png'
                              : 'jpg',
                          mimeType: data['mime'] == 'application/pdf'
                              ? MimeType.pdf
                              : data['mime'] == 'image/png'
                              ? MimeType.png
                              : MimeType.jpeg,
                        );
                      }),
                child: const Text('Tải chứng từ B cung cấp'),
              ),
          ],
          if (allows(WorkflowAction.confirmReceived)) ...[
            CheckboxListTile(
              value: received,
              onChanged: (v) => setState(() => received = v ?? false),
              title: const Text(
                'Tôi là A, đã tự kiểm tra tiền thực nhận trong app ngân hàng.',
              ),
            ),
            TextField(
              controller: reference,
              decoration: const InputDecoration(
                labelText: 'Ghi chú xác nhận (không chứa dữ liệu nhạy cảm)',
              ),
            ),
            FilledButton(
              onPressed: received
                  ? () => act(WorkflowAction.confirmReceived)
                  : null,
              child: const Text('A xác nhận đã nhận tiền'),
            ),
          ],
          if (payerProposal &&
              role == PartyRole.partyA &&
              (allows(WorkflowAction.decline) ||
                  allows(WorkflowAction.reportIssue))) ...[
            TextField(
              controller: feedback,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Phản hồi cho B (không ghi dữ liệu nhạy cảm)',
              ),
            ),
            if (allows(WorkflowAction.requestChanges))
              OutlinedButton(
                onPressed: () => act(WorkflowAction.requestChanges),
                child: const Text('Đề nghị B tạo bản chỉnh sửa'),
              ),
            if (allows(WorkflowAction.decline))
              OutlinedButton(
                onPressed: () => act(WorkflowAction.decline),
                child: const Text('Từ chối đề xuất này'),
              ),
            if (allows(WorkflowAction.reportIssue) && current.response == null)
              OutlinedButton(
                onPressed: () => act(WorkflowAction.reportIssue),
                child: const Text(
                  'Chưa thấy tiền / có sai lệch — chưa xác nhận nhận đủ',
                ),
              ),
          ],
          if (current.response != null)
            Text('Phản hồi A: ${current.response!['note']}'),
          if (payerProposal && current.partyA != null && current.partyB != null)
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => run(() async {
                      if (current.state == AgreementState.paymentConfirmed &&
                          role == PartyRole.partyA &&
                          local['finalized'] != true) {
                        await artifacts.finalize(widget.localId);
                      } else {
                        await artifacts.savePayerStage(widget.localId);
                      }
                      message =
                          'Đã lưu gói bằng chứng; PDF nguyên bản không đổi.';
                    }),
              child: const Text(
                'Lưu / khôi phục gói hồ sơ ở trạng thái hiện tại',
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Chữ ký A: ${current.partyA == null ? 'chưa có' : 'có, đã kiểm kỹ thuật'} · B: ${current.partyB == null ? 'chưa có' : 'có, đã kiểm kỹ thuật'}',
          ),
          const Text(
            'Chữ ký demo không xác thực CCCD/chủ thẻ. VietQR không chứng minh tiền đã đến. ZIP/SCT và on-chain là các lớp kiểm chứng riêng.',
          ),
          if (current.state == AgreementState.paymentConfirmed &&
              role == PartyRole.partyA &&
              local['finalized'] != true)
            FilledButton(
              onPressed: busy
                  ? null
                  : () => run(() async {
                      await artifacts.finalize(widget.localId);
                      message = 'Đã lưu nguyên bản ZIP và công bố cho đối tác. SCT/proof kiểm riêng.';
                    }),
              child: Text(
                payerProposal
                    ? 'A lưu và công bố xác nhận nhận tiền'
                    : 'A tạo và lưu PDF/ZIP nguyên bản',
              ),
            ),
          if (local['finalized'] == true)
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => run(() async {
                      await artifacts.fetch(widget.localId);
                      message =
                          'Đã tải và kiểm hồ sơ nguyên bản từ coordinator.';
                    }),
              child: const Text('Lấy ZIP nguyên bản từ coordinator'),
            ),
          if (local['archive'] != null) ...[
            Text(
              (local['archive'] as Map)['note']?.toString() ??
                  'Có ZIP lưu cục bộ.',
            ),
            OutlinedButton(
              onPressed: busy ? null : download,
              child: const Text('Tải ZIP đã lưu trên thiết bị'),
            ),
          ],
          TextButton(
            onPressed: busy
                ? null
                : () => widget.copyDraft({
                    'localId': 'draft:${createIdentityNonce()}',
                    'kind': 'form',
                    'creatorRole': role.name,
                    'templateId': current.draft.templateId,
                    'fields': current.draft.fields,
                    'revision':
                        (int.tryParse(
                              current.draft.fields['revision'] ?? '1',
                            ) ??
                            1) +
                        1,
                    'supersedesAgreementId': current.draft.id,
                  }),
            child: const Text(
              'Tạo đề xuất mới từ nội dung này (không sửa bản đã ký)',
            ),
          ),
          if (local['endpoint'] != widget.config.coordinatorBaseUrl)
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => run(() async {
                      final approved = await showDialog<bool>(
                        context: context,
                        builder: (dialog) => AlertDialog(
                          title: const Text('Xác nhận đổi địa chỉ coordinator'),
                          content: Text(
                            'Hồ sơ cũ thuộc ${endpointOrigin(local['endpoint'] as String)}. App hiện dùng ${endpointOrigin(widget.config.coordinatorBaseUrl)}. Chỉ tiếp tục nếu nhóm kiểm soát server mới và đã giữ database. Capability sẽ được gửi đến server mới; app phải giải mã/kiểm đúng hồ sơ trước khi lưu thay đổi.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialog, false),
                              child: const Text('Hủy'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(dialog, true),
                              child: const Text('Tôi xác nhận server của nhóm'),
                            ),
                          ],
                        ),
                      );
                      if (approved == true) {
                        await widget.service.migrateToConfiguredEndpoint(
                          widget.localId,
                          confirmed: true,
                        );
                        message = 'Đã kiểm đúng hồ sơ và cập nhật endpoint.';
                      }
                    }),
              child: const Text('Khôi phục sau khi nhóm đổi URL coordinator'),
            ),
        ],
      ),
    );
  }
}
