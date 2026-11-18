import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';

import '../../app/flow_widgets.dart';
import 'agreement_vault.dart';
import 'workspace_overview.dart';
import 'workspace_service.dart';
import '../../core/formatting/display_formatters.dart';
import '../../core/models/agreement.dart';
import '../../core/models/party_role.dart';
import '../../ui/app_theme.dart';
import '../../ui/components.dart';

class WorkspaceHistoryPage extends StatefulWidget {
  const WorkspaceHistoryPage({
    required this.service,
    required this.unlock,
    required this.open,
    required this.resumeForm,
    this.hasUpdate,
    super.key,
  });
  final bool Function(String localId)? hasUpdate;
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
  AppTone messageTone = AppTone.success;
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
      if (mounted) {
        setState(() {
          message = friendlyError(e);
          messageTone = AppTone.danger;
        });
      }
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
      setState(() {
        message = 'Đã nhập gói khôi phục. Hồ sơ đang có không bị thay bằng bản cũ hơn.';
        messageTone = AppTone.success;
      });
    }
  }

  String query = '';
  RecordBucket? filter;

  Future<void> exportBackup() async {
    final encrypted = await vault.exportEncrypted();
    await FileSaver.instance.saveFile(
      name: 'civiltrust-recovery',
      bytes: Uint8List.fromList(utf8.encode(encrypted)),
      fileExtension: 'json',
      mimeType: MimeType.json,
    );
    if (mounted) {
      setState(
        () => message = 'Đã xuất gói khôi phục. Cất cùng mật khẩu ở nơi an toàn; không gửi cho bên kia.',
      );
    }
  }

  ({RecordOverview overview, SigningSession? session, String title})? _summary(
    Map<String, dynamic> record,
  ) {
    if (record['kind'] == 'form') {
      final template = record['templateId'] == 'loan-v1'
          ? 'Hợp đồng vay tiền'
          : 'Hợp đồng đặt cọc';
      return (
        overview: const RecordOverview(
          bucket: RecordBucket.draft,
          headline: 'Bản nháp chưa gửi — tiếp tục điền và xem lại',
        ),
        session: null,
        title: template,
      );
    }
    try {
      final session = widget.service.session(record);
      return (
        overview: overviewOf(record, session),
        session: session,
        title: session.draft.title,
      );
    } catch (_) {
      return null;
    }
  }

  bool _matches(Map<String, dynamic> record, SigningSession? session) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final haystack = [
      if (session != null) ...[
        session.draft.title,
        agreementCode(session.draft.id),
        session.draft.fields['assetDescription'] ?? '',
        session.draft.fields['loanPurpose'] ?? '',
      ],
      record['templateId']?.toString() ?? '',
    ].join(' ').toLowerCase();
    return haystack.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final records = vault.unlocked
        ? vault.records.where((r) => r['submittedSession'] == null).toList()
        : <Map<String, dynamic>>[];
    final summaries = [
      for (final record in records) (record: record, summary: _summary(record)),
    ];
    int count(RecordBucket bucket) =>
        summaries.where((s) => s.summary?.overview.bucket == bucket).length;
    final visible =
        summaries.where((s) {
          final summary = s.summary;
          if (summary == null) return filter == null;
          if (filter != null && summary.overview.bucket != filter) return false;
          return _matches(s.record, summary.session);
        }).toList()..sort((a, b) {
          int rank(RecordBucket? bucket) =>
              bucket == null ? 9 : RecordBucket.values.indexOf(bucket);
          return rank(a.summary?.overview.bucket)
              .compareTo(rank(b.summary?.overview.bucket));
        });
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const FlowHeader(
          title: 'Hợp đồng của tôi',
          subtitle: 'Lưu mã hóa trên thiết bị này. Mở từng hồ sơ để làm mới trạng thái mới nhất.',
        ),
        if (busy) const LinearProgressIndicator(),
        if (message.isNotEmpty) StatusMessage(message, tone: messageTone),
        if (!vault.unlocked) ...[
          Card(
            child: EmptyState(
              icon: Icons.lock_outline,
              title: 'Kho hợp đồng đang khóa',
              message: 'Mở bằng mật khẩu kho trên cùng trình duyệt. Đổi thiết bị thì nhập gói khôi phục mã hóa.',
              action: FilledButton.icon(
                onPressed: busy
                    ? null
                    : () => run(() async {
                        await widget.unlock();
                      }),
                icon: const Icon(Icons.lock_open),
                label: const Text('Mở / tạo kho hợp đồng'),
              ),
            ),
          ),
        ] else ...[
          if (count(RecordBucket.action) > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TrustNotice(
                tone: AppTone.info,
                title:
                    'Bạn có ${count(RecordBucket.action)} hợp đồng cần xử lý',
                message:
                    'Các hợp đồng này đang chờ bạn thực hiện bước tiếp theo.',
              ),
            ),
          TextField(
            onChanged: (value) => setState(() => query = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Tìm theo mã CT-…, tên mẫu, tài sản',
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (bucket, label) in const [
                  (null, 'Tất cả'),
                  (RecordBucket.action, 'Cần xử lý'),
                  (RecordBucket.waiting, 'Đang chờ'),
                  (RecordBucket.done, 'Đã xong'),
                  (RecordBucket.draft, 'Bản nháp'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        bucket == null
                            ? '$label (${summaries.length})'
                            : '$label (${count(bucket)})',
                      ),
                      selected: filter == bucket,
                      onSelected: (_) => setState(() => filter = bucket),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          if (visible.isEmpty)
            EmptyState(
              icon: records.isEmpty ? Icons.folder_open : Icons.search_off,
              title: records.isEmpty
                  ? 'Chưa có hợp đồng nào trên thiết bị này'
                  : 'Không có hợp đồng phù hợp',
              message: records.isEmpty
                  ? 'Tạo hợp đồng mới hoặc mở link mời từ bên kia.'
                  : 'Thử bỏ bộ lọc hoặc đổi từ khóa tìm kiếm.',
            ),
          for (final item in visible)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _tile(item.record, item.summary),
            ),
          const SizedBox(height: 24),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            leading: const Icon(Icons.shield_outlined),
            title: const Text('Sao lưu và bảo mật kho'),
            subtitle: const Text('Gói khôi phục, khóa kho'),
            childrenPadding: const EdgeInsets.only(bottom: 12),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gói khôi phục chứa quyền truy cập các phiên ký và được mã hóa bằng mật khẩu kho. Không gửi cho bên kia của hợp đồng; gói bằng chứng ZIP mới là tệp để chia sẻ.',
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => run(exportBackup),
                    icon: const Icon(Icons.download),
                    label: const Text('Xuất gói khôi phục'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => run(importBackup),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Nhập gói khôi phục'),
                  ),
                  TextButton.icon(
                    onPressed: busy ? null : vault.lock,
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Khóa kho'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _tile(
    Map<String, dynamic> record,
    ({RecordOverview overview, SigningSession? session, String title})? summary,
  ) {
    if (summary == null) {
      return const TrustNotice(
        tone: AppTone.danger,
        title: 'Có hồ sơ không đọc được',
        message: 'Giữ gói khôi phục và kiểm tra phiên bản ứng dụng.',
      );
    }
    final overview = summary.overview;
    final session = summary.session;
    final (chip, tone) = switch (overview.bucket) {
      RecordBucket.action => ('Cần bạn xử lý', AppTone.warning),
      RecordBucket.waiting => ('Đang chờ bên kia', AppTone.info),
      RecordBucket.done => ('Đã xong', AppTone.success),
      RecordBucket.draft => ('Bản nháp', AppTone.mock),
    };
    final role = PartyRole.values.byName(
      (record['role'] ?? record['creatorRole']) as String,
    );
    final open = session == null
        ? () => run(() => widget.resumeForm(record))
        : () => run(() => widget.open(record['localId'] as String));
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : open,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      summary.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  StatusChip(chip, tone: tone),
                ],
              ),
              if (widget.hasUpdate?.call(record['localId'] as String) ?? false)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.fiber_new_outlined,
                        size: 18,
                        color: AppTone.warning.foreground,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Có cập nhật mới từ bên kia — mở để xem',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTone.warning.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                [
                  if (session != null) agreementCode(session.draft.id),
                  if (session != null)
                    DisplayFormatters.vnd(session.draft.amountVnd),
                  session == null
                      ? role.label
                      : '${role.label} · ${role.businessLabel(session.draft.templateId)}',
                ].join(' · '),
                style: const TextStyle(color: AppColors.inkMuted),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    overview.bucket == RecordBucket.action
                        ? Icons.arrow_circle_right_outlined
                        : overview.bucket == RecordBucket.done
                        ? Icons.check_circle_outline
                        : Icons.schedule,
                    size: 20,
                    color: tone.foreground,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          overview.headline,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (overview.detail != null)
                          Text(
                            overview.detail!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.inkMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child:
                    overview.bucket == RecordBucket.action ||
                        overview.bucket == RecordBucket.draft
                    ? FilledButton(
                        onPressed: busy ? null : open,
                        child: Text(
                          session == null ? 'Tiếp tục bản nháp' : 'Xử lý ngay',
                        ),
                      )
                    : OutlinedButton(
                        onPressed: busy ? null : open,
                        child: const Text('Xem chi tiết'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
