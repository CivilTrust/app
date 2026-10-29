import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';

import '../../app/flow_widgets.dart';
import 'agreement_vault.dart';
import 'workflow_rules.dart';
import 'workspace_service.dart';
import '../../core/models/party_role.dart';

class WorkspaceHistoryPage extends StatefulWidget {
  const WorkspaceHistoryPage({
    required this.service,
    required this.unlock,
    required this.open,
    required this.resumeForm,
    super.key,
  });
  final WorkspaceService service;
  final Future<bool> Function() unlock;
  final Future<void> Function(String) open;
  final Future<void> Function(Map<String, dynamic>) resumeForm;
  @override
  State<WorkspaceHistoryPage> createState() => _WorkspaceHistoryPageState();
}

class _WorkspaceHistoryPageState extends State<WorkspaceHistoryPage> {
  AgreementVault get vault => widget.service.vault;
  bool busy = false;
  String message = '';
  @override
  void initState() {
    super.initState();
    vault.addListener(changed);
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    vault.removeListener(changed);
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => message = e.toString());
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> importBackup() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.length > 64 * 1024 * 1024) {
      throw const FormatException('Backup quá lớn.');
    }
    if (!mounted) return;
    final password = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mật khẩu của gói khôi phục'),
        content: TextField(
          controller: password,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, password.text),
            child: const Text('Nhập gói'),
          ),
        ],
      ),
    );
    password.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      password.dispose();
    });
    if (value == null) return;
    await vault.importEncrypted(utf8.decode(bytes), value);
    if (mounted) {
      setState(
        () => message =
            'Đã nhập hồ sơ mới. Hồ sơ đang có không bị rollback bởi backup cũ.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = vault.unlocked
        ? vault.records.where((r) => r['submittedSession'] == null).toList()
        : <Map<String, dynamic>>[];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const FlowHeader(
          title: 'Hợp đồng của tôi',
          subtitle: 'Bản lưu trên thiết bị này. Đồng bộ không phải xác nhận thanh toán ngân hàng hoặc xác thực NFC.',
        ),
        if (busy) const LinearProgressIndicator(),
        if (message.isNotEmpty) Text(message),
        if (!vault.unlocked) ...[
          const TrustNotice(
            title: 'Kho đang khóa',
            message: 'Mở cùng trình duyệt/origin và dùng mật khẩu kho để xem lại. Đổi thiết bị cần gói khôi phục mã hóa. Mất mật khẩu hoặc xóa dữ liệu trình duyệt mà không có backup có thể mất quyền truy cập.',
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () => run(() async {
                    await widget.unlock();
                  }),
            child: const Text('Mở / tạo kho hợp đồng'),
          ),
        ] else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => run(() async {
                        final encrypted = await vault.exportEncrypted();
                        await FileSaver.instance.saveFile(
                          name: 'civiltrust-recovery',
                          bytes: Uint8List.fromList(utf8.encode(encrypted)),
                          fileExtension: 'json',
                          mimeType: MimeType.json,
                        );
                      }),
                child: const Text('Xuất gói khôi phục'),
              ),
              OutlinedButton(
                onPressed: busy ? null : () => run(importBackup),
                child: const Text('Nhập gói khôi phục'),
              ),
              TextButton(
                onPressed: busy ? null : vault.lock,
                child: const Text('Khóa kho'),
              ),
            ],
          ),
          const Text(
            'Không gửi gói khôi phục cho đối tác: nó có thể chứa quyền quản lý và khóa phiên. ZIP bằng chứng là tệp riêng để chia sẻ.',
          ),
          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Chưa có hồ sơ được lưu trên thiết bị này.'),
            ),
          for (final record in records)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _tile(record),
            ),
        ],
      ],
    );
  }

  Widget _tile(Map<String, dynamic> record) {
    if (record['kind'] == 'form') {
      return SectionCard(
        title: 'Bản nháp · ${record['templateId']}',
        icon: Icons.edit_note,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vai trò: ${record['creatorRole'] == 'partyA' ? 'Bên A' : 'Bên B'} · chưa ký, chưa gửi coordinator',
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () => run(() => widget.resumeForm(record)),
              child: const Text('Tiếp tục bản nháp'),
            ),
          ],
        ),
      );
    }
    try {
      final session = widget.service.session(record);
      return SectionCard(
        title: session.draft.title,
        icon: Icons.description_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vai trò: ${PartyRole.values.byName(record['role'] as String).label} · ${record['isOwner'] == true ? 'Người tạo' : 'Người được mời'}',
            ),
            Text(WorkflowRules.status(session)),
            Text(
              record['version'] == 0
                  ? 'Yêu cầu tạo đang chờ xác nhận'
                  : 'Lần đồng bộ cuối: ${record['lastSyncedAt'] ?? 'chưa có'}',
            ),
            if (record['finalized'] == true)
              const Text('Đã đóng gói trên coordinator; kiểm SCT/proof riêng.'),
            if (record['archive'] != null)
              const Text('Có ZIP nguyên bản lưu trong kho thiết bị.'),
            FilledButton(
              onPressed: busy
                  ? null
                  : () => run(() => widget.open(record['localId'] as String)),
              child: const Text('Xem hợp đồng và trạng thái'),
            ),
          ],
        ),
      );
    } catch (_) {
      return const Text(
        'Có hồ sơ không đọc được. Giữ backup và kiểm tra phiên bản app.',
      );
    }
  }
}
