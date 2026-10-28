import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/flow_widgets.dart';
import '../../core/config/app_config.dart';
import '../../core/config/environment_check.dart';
import '../../core/models/agreement.dart';
import '../../core/models/party_role.dart';
import '../identity/identity_context.dart';
import '../identity/identity_service.dart';
import '../payment/payment_details.dart';
import '../payment/payment_qr_card.dart';
import '../sessions/invite_url.dart';
import 'workflow_rules.dart';
import 'workspace_artifacts.dart';
import 'workspace_service.dart';

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
    reviewed = false;
    consent = false;
    received = false;
    message = 'Đã đồng bộ và kiểm chuỗi chữ ký. Danh tính vẫn là mock; trạng thái tiền là tự khai.';
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
    );
    reviewed = false;
    consent = false;
    received = false;
    loadBank();
    message = 'Đã lưu và đồng bộ thao tác ${action.name}.';
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
    final payment = PaymentDetails.fromDraft(current.draft);
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
                SelectableText(payment.copyText),
                if (current.state == AgreementState.draft &&
                    role == PartyRole.partyA) ...[
                  const Text(
                    'A kiểm tra/sửa tài khoản nhận trước khi duyệt. Đây không phải xác nhận quyền sở hữu tài khoản từ ngân hàng.',
                  ),
                  for (final name in bank.keys)
                    TextField(
                      controller: bank[name],
                      enabled: !busy,
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
                    onPressed: allows(WorkflowAction.approve) && reviewed
                        ? () => act(WorkflowAction.approve)
                        : null,
                    child: const Text('A duyệt và khóa đề xuất'),
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
          if (allows(WorkflowAction.reportTransfer))
            FilledButton(
              onPressed: () => act(WorkflowAction.reportTransfer),
              child: const Text('B báo đã chuyển tiền (tự khai)'),
            ),
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
              child: const Text('A tạo và lưu PDF/ZIP nguyên bản'),
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
