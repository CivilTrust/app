import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../app/flow_widgets.dart';
import '../../core/config/app_config.dart';
import '../../core/crypto/hash_service.dart';
import '../signing/mock_party_signer.dart';
import '../signing/session_validator.dart';
import 'artifact_service.dart';
import 'evidence_manifest.dart';

enum VerificationLevel { valid, invalid, present, unavailable, notChecked }

class VerificationResult {
  const VerificationResult(this.label, this.detail, this.level);
  final String label;
  final String detail;
  final VerificationLevel level;
}

class VerifyBundlePage extends StatefulWidget {
  const VerifyBundlePage({required this.config, super.key});
  final AppConfig config;

  @override
  State<VerifyBundlePage> createState() => _VerifyBundlePageState();
}

class _VerifyBundlePageState extends State<VerifyBundlePage> {
  List<VerificationResult> results = const [];
  String? documentHash;
  String? error;
  var busy = false;

  Future<void> verify() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (picked == null) return;
    setState(() {
      busy = true;
      error = null;
      results = const [];
    });
    try {
      final manifest = ArtifactService(const HashService())
          .importZip(await picked.readAsBytes());
      await SessionValidator(
        const HashService(),
        MockPartySigner(),
      ).validate(manifest.session, requirePartyB: true);
      if (!mounted) return;
      setState(() {
        documentHash = manifest.documentHash;
        results = _successResults(manifest);
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        error = exception.toString();
        results = const [
          VerificationResult(
            'Hồ sơ CivilTrust',
            'Không thể xác nhận tính toàn vẹn của gói được chọn.',
            VerificationLevel.invalid,
          ),
        ];
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  List<VerificationResult> _successResults(EvidenceManifest manifest) => [
    VerificationResult(
      'Hash PDF',
      'Khớp agreement.pdf trong ZIP.',
      VerificationLevel.valid,
    ),
    VerificationResult(
      'Evidence ${manifest.schema}',
      'Canonical evidence hash khớp dữ liệu phiên.',
      VerificationLevel.valid,
    ),
    const VerificationResult(
      'Chữ ký Bên A',
      'Chữ ký Ed25519 demo trên frozen digest hợp lệ.',
      VerificationLevel.valid,
    ),
    const VerificationResult(
      'Chữ ký Bên B',
      'Chữ ký Ed25519 demo trên cùng frozen digest hợp lệ.',
      VerificationLevel.valid,
    ),
    VerificationResult(
      'Xác nhận nhận tiền',
      manifest.session.payment == null
          ? 'Không có trong evidence.'
          : 'Có xác nhận thủ công của Bên A; chưa được ngân hàng kiểm chứng.',
      manifest.session.payment == null
          ? VerificationLevel.unavailable
          : VerificationLevel.present,
    ),
    VerificationResult(
      'SCT Notary',
      manifest.signedCommitment == null
          ? 'ZIP không có SCT.'
          : 'Có phản hồi SCT; app chưa xác minh chữ ký SCT.',
      manifest.signedCommitment == null
          ? VerificationLevel.unavailable
          : VerificationLevel.notChecked,
    ),
    VerificationResult(
      'Merkle proof',
      manifest.merkleProof == null
          ? 'Chưa có proof trong evidence.'
          : 'Có proof nhưng client chưa thực hiện phép kiểm Merkle.',
      manifest.merkleProof == null
          ? VerificationLevel.unavailable
          : VerificationLevel.notChecked,
    ),
    VerificationResult(
      'Blockchain',
      widget.config.hasRegistry
          ? 'Đã có địa chỉ registry nhưng app chưa gọi RPC để kiểm chứng.'
          : 'Chưa cấu hình địa chỉ registry.',
      VerificationLevel.notChecked,
    ),
  ];

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
    children: [
      const FlowHeader(
        title: 'Kiểm chứng hồ sơ',
        subtitle: 'Kiểm tra cục bộ từng lớp bằng chứng. Tệp không được upload lên coordinator.',
      ),
      SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TrustNotice(
              title: 'Không phải kết luận pháp lý',
              message:
                  'Kết quả dưới đây chỉ mô tả phép kiểm kỹ thuật đã thực sự chạy. '
                  'CivilTrust không phải dịch vụ công chứng.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy ? null : verify,
              icon: const Icon(Icons.folder_zip),
              label: const Text('Chọn hồ sơ CivilTrust ZIP'),
            ),
            if (busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: TextStyle(color: Colors.red.shade700)),
            ],
            if (documentHash != null) ...[
              const SizedBox(height: 14),
              SelectableText(
                'Hash PDF: $documentHash',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      if (results.isNotEmpty) ...[
        const SizedBox(height: 16),
        SectionCard(
          title: 'Kết quả theo từng lớp',
          icon: Icons.fact_check_outlined,
          child: Column(
            children: [for (final result in results) _ResultTile(result)],
          ),
        ),
      ],
    ],
  );
}

class _ResultTile extends StatelessWidget {
  const _ResultTile(this.result);
  final VerificationResult result;

  @override
  Widget build(BuildContext context) {
    final (icon, color, status) = switch (result.level) {
      VerificationLevel.valid => (
        Icons.check_circle,
        const Color(0xff047857),
        'Hợp lệ',
      ),
      VerificationLevel.invalid => (
        Icons.cancel,
        const Color(0xffb91c1c),
        'Không hợp lệ',
      ),
      VerificationLevel.present => (
        Icons.info,
        const Color(0xff0369a1),
        'Có dữ liệu',
      ),
      VerificationLevel.unavailable => (
        Icons.remove_circle_outline,
        Colors.grey,
        'Chưa có',
      ),
      VerificationLevel.notChecked => (
        Icons.help_outline,
        const Color(0xffb45309),
        'Chưa kiểm tra',
      ),
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(
        result.label,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(result.detail),
      trailing: Text(
        status,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
