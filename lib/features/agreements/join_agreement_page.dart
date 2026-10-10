import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/flow_widgets.dart';
import '../../core/config/app_config.dart';
import '../../core/crypto/hash_service.dart';
import '../../core/encoding/encoding_utils.dart';
import '../../core/formatting/display_formatters.dart';
import '../../core/models/agreement.dart';
import '../../core/models/identity_evidence.dart';
import '../identity/mock_identity_reader.dart';
import '../payment/vietqr_service.dart';
import '../sessions/remote_session_repository.dart';
import '../sessions/session_models.dart';
import '../signing/mock_party_signer.dart';
import '../signing/session_validator.dart';

class JoinAgreementPage extends StatefulWidget {
  const JoinAgreementPage({required this.config, super.key});
  final AppConfig config;

  @override
  State<JoinAgreementPage> createState() => _JoinAgreementPageState();
}

class _JoinAgreementPageState extends State<JoinAgreementPage> {
  final inviteController = TextEditingController();
  SessionCapabilities? capability;
  SigningSession? session;
  IdentityEvidence? identityB;
  int? version;
  var accepted = false;
  var identityConsent = false;
  var busy = false;
  var step = 0;
  DateTime? expiresAt;
  String message = '';

  RemoteSessionRepository get repository =>
      RemoteSessionRepository(widget.config.coordinatorBaseUrl);

  @override
  void initState() {
    super.initState();
    final fragment = Uri.base.fragment;
    if (fragment.startsWith('join=')) {
      inviteController.text = fragment.substring(5);
    }
  }

  Future<void> open() => _run(() async {
    var value = inviteController.text.trim();
    if (value.isEmpty) throw const FormatException('Hãy dán link hoặc mã mời.');
    if (value.contains('#join=')) value = value.split('#join=').last;
    capability = SessionCapabilities.fromInviteFragment(value);
    final snapshot = await repository.read(capability!);
    await SessionValidator(
      const HashService(),
      MockPartySigner(),
    ).validate(snapshot.value);
    session = snapshot.value;
    version = snapshot.version;
    expiresAt = snapshot.expiresAt;
    if (snapshot.value.payment != null) {
      step = 4;
      message = 'Bên A đã xác nhận nhận tiền và đóng gói hồ sơ.';
    } else if (snapshot.value.state == AgreementState.paymentPending) {
      step = 4;
      message = 'Bạn đã báo chuyển tiền. Đang chờ Bên A xác nhận.';
    } else if (snapshot.value.partyB != null) {
      step = 3;
      message = 'Chữ ký Bên B đã có. Hãy thực hiện chuyển khoản.';
    } else {
      step = 1;
      message = 'Link hợp lệ. Hãy đọc toàn bộ nội dung trước khi xác minh.';
    }
  });

  Future<void> identify() => _run(() async {
    if (!identityConsent) {
      throw StateError('Bạn phải đồng ý đọc dữ liệu CCCD mô phỏng.');
    }
    identityB = await MockIdentityReader().read(role: 'partyB');
    step = 2;
    message = 'Đã điền thông tin Bên B từ CCCD mock.';
  });

  Future<void> sign() => _run(() async {
    if (!accepted) {
      throw StateError('Bạn phải xác nhận đã đọc và đồng ý.');
    }
    final signature = await MockPartySigner().sign(
      role: 'partyB',
      digest: hexToBytes(session!.frozenDigest!),
      identity: identityB!,
    );
    final updated = session!.copyWith(
      state: AgreementState.partyBSigned,
      partyB: signature,
    );
    version = await repository.update(capability!, updated, version!);
    session = updated;
    step = 3;
    message = 'Đã ký hợp đồng. Chuyển khoản bằng app ngân hàng rồi xác nhận bên dưới.';
  });

  Future<void> markTransferred() => _run(() async {
    final updated = session!.copyWith(state: AgreementState.paymentPending);
    version = await repository.update(capability!, updated, version!);
    session = updated;
    step = 4;
    message =
        'Đã báo Bên A. Hợp đồng chỉ hoàn tất sau khi A kiểm tra tiền thực tế.';
  });

  Future<void> refreshCompletion() => _run(() async {
    final snapshot = await repository.read(capability!);
    await SessionValidator(
      const HashService(),
      MockPartySigner(),
    ).validate(snapshot.value, requirePartyB: true);
    session = snapshot.value;
    version = snapshot.version;
    expiresAt = snapshot.expiresAt;
    message = session!.payment == null
        ? 'Bên A chưa xác nhận nhận tiền.'
        : 'Bên A đã xác nhận nhận tiền. Hãy nhận ZIP cuối từ Bên A.';
  });

  Future<void> _run(Future<void> Function() operation) async {
    setState(() => busy = true);
    try {
      await operation();
    } catch (error) {
      message = 'Không thể tiếp tục: $error';
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
    children: [
      const FlowHeader(
        title: 'Bên B tham gia ký',
        subtitle:
            'Mở link an toàn, đọc hợp đồng, xác minh CCCD, ký và chuyển khoản.',
      ),
      FlowProgress(
        current: step,
        labels: const [
          'Mở link',
          'Đọc hợp đồng',
          'Danh tính B',
          'Ký & chuyển',
          'Chờ A',
        ],
      ),
      const SizedBox(height: 22),
      if (busy) const LinearProgressIndicator(),
      if (message.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            message,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: message.startsWith('Không')
                  ? Colors.red.shade700
                  : const Color(0xff0f766e),
            ),
          ),
        ),
      if (step == 0) _openStep(),
      if (step == 1) _readStep(),
      if (step == 2) _identityStep(),
      if (step == 3) _paymentStep(),
      if (step == 4) _waitingStep(),
    ],
  );

  Widget _openStep() => SectionCard(
    title: 'Link mời từ Bên A',
    icon: Icons.link,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: inviteController,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Dán link hoặc mã mời'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: busy ? null : open,
          icon: const Icon(Icons.lock_open),
          label: const Text('Mở và kiểm tra phiên ký'),
        ),
      ],
    ),
  );

  Widget _readStep() => Column(
    children: [
      SectionCard(
        title: session!.draft.title,
        icon: Icons.description_outlined,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 480),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xfffffdf7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xffe7dfcc)),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              session!.draft.terms,
              style: const TextStyle(height: 1.55),
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      SectionCard(
        title: 'Thông tin phiên ký',
        icon: Icons.shield_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session!.draft.templateId == 'loan-v1'
                  ? 'Vai trò: Bên B · Bên cho vay'
                  : 'Vai trò: Bên B · Bên đặt cọc',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              'Số tiền chuyển: ${DisplayFormatters.vnd(session!.draft.amountVnd)}',
            ),
            if (expiresAt != null)
              Text('Phiên hết hạn: ${DisplayFormatters.dateTime(expiresAt!)}'),
            const SizedBox(height: 10),
            const TrustNotice(
              title: 'Chữ ký demo',
              message: 'Bạn sẽ ký digest nội dung bằng khóa Ed25519 tạm thời. Đây chưa phải chữ ký số được chứng nhận.',
            ),
            const SizedBox(height: 10),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: identityConsent,
              onChanged: (value) =>
                  setState(() => identityConsent = value ?? false),
              title: const Text(
                'Tôi đồng ý dùng dữ liệu CCCD mô phỏng cho bản demo',
              ),
              subtitle: const Text(
                'Consent này không đồng nghĩa đồng ý nội dung hợp đồng.',
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: identityConsent ? identify : null,
          icon: const Icon(Icons.nfc),
          label: const Text('Tôi đã đọc · Xác minh CCCD Bên B'),
        ),
      ),
    ],
  );

  Widget _identityStep() => Column(
    children: [
      SectionCard(
        title: session!.draft.templateId == 'loan-v1'
            ? 'Bên B · Bên cho vay'
            : 'Bên B · Bên đặt cọc',
        icon: Icons.badge_outlined,
        child: IdentitySummary(
          identity: identityB!.toJson(),
          role: session!.draft.templateId == 'loan-v1'
              ? 'Bên B · Bên cho vay'
              : 'Bên B · Bên đặt cọc',
        ),
      ),
      const SizedBox(height: 12),
      CheckboxListTile(
        value: accepted,
        onChanged: (value) => setState(() => accepted = value ?? false),
        title: const Text(
          'Tôi xác nhận thông tin đúng, đã đọc và đồng ý toàn bộ hợp đồng.',
        ),
        subtitle: const Text(
          'Chữ ký được tạo trên đúng digest mà Bên A đã ký.',
        ),
        controlAffinity: ListTileControlAffinity.leading,
      ),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: busy || !accepted ? null : sign,
          icon: const Icon(Icons.draw),
          label: const Text('Đồng ý và ký hợp đồng'),
        ),
      ),
    ],
  );

  Widget _paymentStep() {
    final draft = session!.draft;
    final qr = const VietQrService().build(
      bankBin: draft.fields['bankBin'] ?? '',
      accountNumber: draft.fields['accountNumber'] ?? '',
      amount: draft.amountVnd,
      purpose: 'CIVILTRUST ${draft.id.substring(0, 8)}',
    );
    return SectionCard(
      title: 'Chuyển khoản cho Bên A',
      icon: Icons.account_balance,
      child: Center(
        child: Column(
          children: [
            QrImageView(data: qr, size: 230),
            const SizedBox(height: 8),
            Text(
              '${draft.fields['accountName']} · ${draft.fields['accountNumber']}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            Text(
              DisplayFormatters.vnd(draft.amountVnd),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xff0f766e),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Quét bằng app ngân hàng. Kiểm tra lại người nhận và số tiền trước khi xác nhận.',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : markTransferred,
                icon: const Icon(Icons.send),
                label: const Text('Tôi đã thực hiện chuyển khoản'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _waitingStep() => SectionCard(
    child: Column(
      children: [
        const CircleAvatar(
          radius: 32,
          backgroundColor: Color(0xfffef3c7),
          child: Icon(Icons.hourglass_top, color: Color(0xffb45309), size: 34),
        ),
        const SizedBox(height: 14),
        Text(
          session?.payment == null
              ? 'Đang chờ Bên A xác nhận'
              : 'Bên A đã xác nhận nhận tiền',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          session?.payment == null
              ? 'Bên A sẽ kiểm tra tiền thực tế trong app ngân hàng, sau đó tạo PDF cuối và hồ sơ bằng chứng.'
              : 'PDF/ZIP cuối không được lưu trên coordinator trong MVP. Hãy nhận hồ sơ ZIP trực tiếp từ Bên A.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: busy ? null : refreshCompletion,
          icon: const Icon(Icons.refresh),
          label: const Text('Kiểm tra trạng thái Bên A'),
        ),
      ],
    ),
  );
}
