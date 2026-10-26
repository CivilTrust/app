import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/flow_widgets.dart';
import '../../core/config/app_config.dart';
import '../../core/crypto/hash_service.dart';
import '../../core/encoding/encoding_utils.dart';
import '../../core/formatting/display_formatters.dart';
import '../../core/ids/agreement_id.dart';
import '../../core/models/agreement.dart';
import '../../core/models/identity_evidence.dart';
import '../artifacts/artifact_service.dart';
import '../identity/mock_identity_reader.dart';
import '../notary/notary_client.dart';
import '../payment/vietqr_service.dart';
import '../sessions/remote_session_repository.dart';
import '../sessions/session_models.dart';
import '../signing/mock_party_signer.dart';
import '../signing/session_validator.dart';
import 'contract_template.dart';
import 'contract_template_service.dart';
import 'agreement_validator.dart';

class CreateAgreementPage extends StatefulWidget {
  const CreateAgreementPage({required this.config, super.key});
  final AppConfig config;

  @override
  State<CreateAgreementPage> createState() => _CreateAgreementPageState();
}

class _CreateAgreementPageState extends State<CreateAgreementPage> {
  final templateService = ContractTemplateService();
  final hash = const HashService();
  final signer = MockPartySigner();
  final identityReader = MockIdentityReader();
  final validator = const AgreementValidator();
  final controllers = <String, TextEditingController>{};
  final formKey = GlobalKey<FormState>();
  ContractTemplate? selectedTemplate;
  IdentityEvidence? identityA;
  SigningSession? session;
  SessionCapabilities? owner;
  int? version;
  ArtifactBundle? bundle;
  var stage = 0;
  var confirmedReview = false;
  var identityConsent = false;
  var busy = false;
  var notaryReceived = false;
  String? inviteUrl;
  String? notaryStatus;
  DateTime? expiresAt;
  String message = '';

  RemoteSessionRepository get repository =>
      RemoteSessionRepository(widget.config.coordinatorBaseUrl);

  void selectTemplate(ContractTemplate template) {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    controllers.clear();
    for (final field in template.fields) {
      controllers[field.key] = TextEditingController(text: field.initialValue);
    }
    controllers.addAll({
      'bankBin': TextEditingController(text: '970436'),
      'accountNumber': TextEditingController(),
      'accountName': TextEditingController(),
    });
    setState(() {
      selectedTemplate = template;
      stage = 1;
      identityConsent = false;
      message = '';
    });
  }

  Future<void> readIdentity() => _run(() async {
    if (!identityConsent) {
      throw StateError('Bạn phải đồng ý đọc dữ liệu CCCD mô phỏng.');
    }
    identityA = await identityReader.read(role: 'partyA');
    controllers['accountName']!.text = identityA!.displayName;
    stage = 2;
    message = 'Đã điền thông tin Bên A từ CCCD mock.';
  });

  Map<String, String> get fields => {
    for (final entry in controllers.entries) entry.key: entry.value.text.trim(),
  };

  bool _isDateField(String key) =>
      const {'completionDate', 'disbursementDate', 'dueDate'}.contains(key);

  Future<void> _pickDate(String key) async {
    final current = validator.parseDate(controllers[key]?.text ?? '');
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2200),
      helpText: 'Chọn ngày',
    );
    if (selected == null) return;
    String two(int value) => value.toString().padLeft(2, '0');
    controllers[key]!.text =
        '${two(selected.day)}/${two(selected.month)}/${selected.year}';
  }

  bool validateDetails() {
    if (!(formKey.currentState?.validate() ?? false)) return false;
    final businessError = validator.validateBusinessRules(
      selectedTemplate!,
      fields,
    );
    if (businessError != null) {
      setState(() => message = businessError);
      return false;
    }
    final amount = templateService.amountFor(selectedTemplate!, fields);
    if (amount <= 0) {
      setState(() => message = 'Số tiền thanh toán phải lớn hơn 0.');
      return false;
    }
    setState(() {
      stage = 3;
      message = '';
    });
    return true;
  }

  String get reviewText => templateService.renderReview(
    template: selectedTemplate!,
    fields: fields,
    partyA: identityA!,
  );

  Future<void> createSession() => _run(() async {
    if (!confirmedReview) {
      throw StateError('Bạn phải xác nhận đã đọc nội dung.');
    }
    final amount = templateService.amountFor(selectedTemplate!, fields);
    final draft = AgreementDraft(
      id: createAgreementId(),
      title: selectedTemplate!.title,
      terms: reviewText,
      amountVnd: amount,
      createdAt: DateTime.now().toUtc(),
      templateId: selectedTemplate!.id,
      fields: fields,
    );
    final digest = hash.canonicalObjectHash(draft.toJson());
    final signature = await signer.sign(
      role: 'partyA',
      digest: hexToBytes(digest),
      identity: identityA!,
    );
    final initial = SigningSession(
      draft: draft,
      state: AgreementState.partyASigned,
      frozenDigest: digest,
      partyA: signature,
    );
    final created = await repository.create(initial);
    session = initial;
    owner = created.owner;
    version = created.version;
    expiresAt = created.expiresAt;
    final fragment = created.participant.toInviteFragment();
    inviteUrl = Uri.base.replace(fragment: 'join=$fragment').toString();
    stage = 4;
    message = 'Đã khóa nội dung. Gửi link cho Bên B để xác minh và ký.';
  });

  Future<void> confirmAndCreateSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Khóa nội dung và ký?'),
        content: const Text(
          'Sau bước này, Bên A và Bên B sẽ ký đúng nội dung đang hiển thị. '
          'Muốn sửa điều khoản, bạn phải tạo phiên và chữ ký mới.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại xem'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Khóa và ký'),
          ),
        ],
      ),
    );
    if (confirmed == true) await createSession();
  }

  Future<void> copyInvite() async {
    await Clipboard.setData(ClipboardData(text: inviteUrl!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép link mời riêng tư.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> refresh() => _run(() async {
    final snapshot = await repository.read(owner!);
    await SessionValidator(hash, signer).validate(snapshot.value);
    session = snapshot.value;
    version = snapshot.version;
    if (session!.state == AgreementState.paymentPending) {
      message = 'Bên B báo đã chuyển khoản. Hãy kiểm tra app ngân hàng.';
    } else if (session!.partyB != null) {
      message = 'Bên B đã ký, đang chờ Bên B chuyển khoản.';
    } else {
      message = 'Bên B chưa hoàn tất ký.';
    }
  });

  Future<void> finalize() => _run(() async {
    if (session?.state != AgreementState.paymentPending) {
      throw StateError('Bên B chưa đánh dấu đã chuyển khoản.');
    }
    await SessionValidator(
      hash,
      signer,
    ).validate(session!, requirePartyB: true);
    final paid = session!.copyWith(
      state: AgreementState.paymentConfirmed,
      payment: PaymentReceipt(
        confirmedByPartyA: true,
        confirmedAt: DateTime.now().toUtc(),
        reference:
            controllers['paymentReference']?.text.trim().isNotEmpty == true
            ? controllers['paymentReference']!.text.trim()
            : 'Xác nhận thủ công bởi Bên A',
      ),
    );
    version = await repository.update(owner!, paid, version!);
    var result = await ArtifactService(hash).build(paid);
    try {
      final sct = await NotaryClient(widget.config.notaryBaseUrl)
          .submit(result.evidence.documentHash);
      result = ArtifactService(hash).attachNotary(result, sct.toJson());
      notaryReceived = true;
      message = 'Đã tạo PDF và nhận phản hồi SCT. Chữ ký SCT chưa được app tự kiểm chứng.';
    } catch (error) {
      notaryReceived = false;
      message = 'Hoàn tất offline. Notary chưa sẵn sàng: $error';
    }
    try {
      version = await repository.finalize(owner!);
    } catch (error) {
      message = '$message Không thể đóng phiên coordinator: $error';
    }
    bundle = result;
    session = paid;
    stage = 5;
    await FileSaver.instance.saveFile(
      name: 'civiltrust-${paid.draft.id}',
      bytes: result.zip,
      fileExtension: 'zip',
      mimeType: MimeType.zip,
    );
  });

  Future<void> refreshNotaryStatus() => _run(() async {
    final status = await NotaryClient(widget.config.notaryBaseUrl)
        .status(bundle!.evidence.documentHash);
    final value = status['status']?.toString();
    notaryStatus = value;
    message = switch (value) {
      'pending' => 'Notary báo đang chờ gom batch. Chưa có xác minh on-chain.',
      'batched' => 'Notary báo đã gom batch. App chưa tải proof hoặc tự kiểm tra on-chain.',
      _ => 'Notary trả trạng thái: ${value ?? 'không xác định'}.',
    };
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

  void reset() {
    setState(() {
      stage = 0;
      selectedTemplate = null;
      identityA = null;
      session = null;
      owner = null;
      version = null;
      inviteUrl = null;
      bundle = null;
      confirmedReview = false;
      identityConsent = false;
      notaryReceived = false;
      notaryStatus = null;
      expiresAt = null;
      message = '';
    });
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
    children: [
      const FlowHeader(
        title: 'Tạo hợp đồng mới',
        subtitle: 'Chọn mẫu, xác minh danh tính, điền điều khoản và mời Bên B ký từ xa.',
      ),
      FlowProgress(
        current: stage.clamp(0, 5),
        labels: const [
          'Chọn mẫu',
          'Danh tính A',
          'Điều khoản',
          'Xem lại',
          'B ký & chuyển',
          'Hoàn tất',
        ],
      ),
      const SizedBox(height: 24),
      if (busy) const LinearProgressIndicator(),
      if (message.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(
          message,
          style: TextStyle(
            color: message.startsWith('Không')
                ? Colors.red.shade700
                : const Color(0xff0f766e),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
      const SizedBox(height: 16),
      if (stage == 0) _templatePicker(),
      if (stage == 1) _identityStep(),
      if (stage == 2) _detailsStep(),
      if (stage == 3) _reviewStep(),
      if (stage == 4) _shareStep(),
      if (stage == 5) _completedStep(),
    ],
  );

  Widget _templatePicker() => Column(
    children: [
      const TrustNotice(
        title: 'Bằng chứng kỹ thuật, không phải công chứng',
        message:
            'CivilTrust giúp hai bên khóa nội dung, ký bản demo và kiểm tra tính toàn vẹn. '
            'Các bên vẫn chịu trách nhiệm về nội dung và giao dịch thực tế.',
      ),
      const SizedBox(height: 16),
      for (final template in ContractTemplateService.templates) ...[
        _TemplateCard(
          template: template,
          onTap: () => selectTemplate(template),
        ),
        const SizedBox(height: 14),
      ],
    ],
  );

  Widget _identityStep() => SectionCard(
    title: selectedTemplate!.kind == ContractKind.loan
        ? 'Danh tính Bên A · Bên vay'
        : 'Danh tính Bên A · Bên nhận đặt cọc',
    icon: Icons.badge_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TrustNotice(
          title: 'Đang sử dụng dữ liệu mô phỏng',
          message:
              'Bước này kiểm thử luồng tự điền và không đọc chip CCCD thật. '
              'Không sử dụng dữ liệu này như bằng chứng định danh ngoài đời.',
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: identityConsent,
          onChanged: (value) =>
              setState(() => identityConsent = value ?? false),
          title: const Text(
            'Tôi đồng ý dùng dữ liệu CCCD mô phỏng cho bản demo',
          ),
          subtitle: const Text(
            'Consent này tách biệt với việc đồng ý nội dung hợp đồng.',
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: busy || !identityConsent ? null : readIdentity,
          icon: const Icon(Icons.nfc),
          label: const Text('Quét CCCD mock của Bên A'),
        ),
        TextButton(
          onPressed: () => setState(() => stage = 0),
          child: const Text('Chọn lại mẫu'),
        ),
      ],
    ),
  );

  Widget _detailsStep() {
    controllers.putIfAbsent('paymentReference', TextEditingController.new);
    return Form(
      key: formKey,
      child: Column(
        children: [
          SectionCard(
            title: selectedTemplate!.kind == ContractKind.loan
                ? 'Bên A · Bên vay'
                : 'Bên A · Bên nhận đặt cọc',
            icon: Icons.badge_outlined,
            child: IdentitySummary(
              identity: identityA!.toJson(),
              role: selectedTemplate!.kind == ContractKind.loan
                  ? 'Bên A · Bên vay'
                  : 'Bên A · Bên nhận đặt cọc',
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: selectedTemplate!.title,
            icon: selectedTemplate!.kind == ContractKind.loan
                ? Icons.payments_outlined
                : Icons.handshake_outlined,
            child: Column(
              children: [
                for (final field in selectedTemplate!.fields) ...[
                  TextFormField(
                    controller: controllers[field.key],
                    readOnly: _isDateField(field.key),
                    onTap: _isDateField(field.key)
                        ? () => _pickDate(field.key)
                        : null,
                    maxLines: field.multiline ? 3 : 1,
                    keyboardType: field.numeric
                        ? TextInputType.number
                        : TextInputType.text,
                    inputFormatters: field.numeric
                        ? [FilteringTextInputFormatter.digitsOnly]
                        : null,
                    decoration: InputDecoration(
                      labelText: field.label,
                      hintText: field.hint,
                      suffixIcon: _isDateField(field.key)
                          ? const Icon(Icons.calendar_month_outlined)
                          : null,
                    ),
                    validator: (value) => validator.validateField(
                      selectedTemplate!,
                      field,
                      value,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Tài khoản nhận tiền và VietQR',
            icon: Icons.qr_code_2,
            child: Column(
              children: [
                TrustNotice(
                  title: 'Chiều chuyển tiền',
                  message: selectedTemplate!.kind == ContractKind.loan
                      ? 'Bên B là bên cho vay, giải ngân khoản vay vào tài khoản của Bên A.'
                      : 'Bên B là bên đặt cọc, chuyển tiền đặt cọc vào tài khoản của Bên A.',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: controllers['bankBin'],
                  decoration: const InputDecoration(
                    labelText: 'Mã BIN ngân hàng',
                    helperText: '970436 là Vietcombank',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: validator.validateBankBin,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: controllers['accountNumber'],
                  decoration: const InputDecoration(
                    labelText: 'Số tài khoản nhận tiền',
                  ),
                  validator: validator.validateAccountNumber,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: controllers['accountName'],
                  decoration: const InputDecoration(
                    labelText: 'Tên chủ tài khoản',
                  ),
                  validator: _required,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => stage = 1),
                  child: const Text('Quay lại'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: validateDetails,
                  child: const Text('Tiếp tục xem lại'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Không được để trống' : null;

  Widget _reviewStep() => Column(
    children: [
      SectionCard(
        title: 'Bản xem trước nội dung',
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
              reviewText,
              style: const TextStyle(height: 1.55),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      const TrustNotice(
        title: 'Phạm vi chữ ký',
        message:
            'Hai bên ký digest của nội dung bên trên. Xác nhận nhận tiền và PDF cuối '
            'được tạo sau đó, được ghi thành bằng chứng riêng trong hồ sơ.',
      ),
      const SizedBox(height: 8),
      CheckboxListTile(
        value: confirmedReview,
        onChanged: (value) => setState(() => confirmedReview = value ?? false),
        title: const Text(
          'Tôi đã đọc, thông tin đúng và đồng ý khóa nội dung này.',
        ),
        subtitle: const Text(
          'Sau bước này, mọi sửa đổi phải tạo hợp đồng mới.',
        ),
        controlAffinity: ListTileControlAffinity.leading,
      ),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => stage = 2),
              child: const Text('Chỉnh sửa'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: busy || !confirmedReview
                  ? null
                  : confirmAndCreateSession,
              icon: const Icon(Icons.lock),
              label: const Text('Khóa và ký với danh tính A'),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _shareStep() {
    final draft = session!.draft;
    final qr = const VietQrService().build(
      bankBin: draft.fields['bankBin']!,
      accountNumber: draft.fields['accountNumber']!,
      amount: draft.amountVnd,
      purpose: 'CIVILTRUST ${draft.id.substring(0, 8)}',
    );
    final bSigned = session!.partyB != null;
    final transferSent = session!.state == AgreementState.paymentPending;
    return Column(
      children: [
        SectionCard(
          title: 'Gửi link ký cho Bên B',
          icon: Icons.link,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Link chứa capability và khóa giải mã. Chỉ gửi trực tiếp cho Bên B.',
              ),
              if (expiresAt != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Phiên hết hạn: ${DisplayFormatters.dateTime(expiresAt!)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 8),
              TextFormField(
                key: ValueKey(inviteUrl),
                initialValue: inviteUrl,
                readOnly: true,
                maxLines: null,
                decoration: const InputDecoration(border: InputBorder.none),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: copyInvite,
                icon: const Icon(Icons.copy),
                label: const Text('Sao chép link mời'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Mã QR chuyển khoản',
          icon: Icons.qr_code_2,
          child: Center(
            child: Column(
              children: [
                QrImageView(data: qr, size: 210),
                Text(
                  '${draft.fields['accountName']} · ${draft.fields['accountNumber']}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(DisplayFormatters.vnd(draft.amountVnd)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Trạng thái Bên B',
          icon: bSigned ? Icons.check_circle : Icons.hourglass_top,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatusLine(
                done: bSigned,
                text: bSigned
                    ? 'Bên B đã dùng danh tính mock và ký digest'
                    : 'Chờ Bên B đọc, dùng danh tính mock và ký',
              ),
              _StatusLine(
                done: transferSent,
                text: transferSent
                    ? 'Bên B báo đã chuyển khoản'
                    : 'Chờ Bên B chuyển khoản',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: busy ? null : refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Làm mới trạng thái'),
              ),
            ],
          ),
        ),
        if (transferSent) ...[
          const SizedBox(height: 16),
          SectionCard(
            title: 'A xác nhận tiền thực tế',
            icon: Icons.account_balance,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Mở app ngân hàng và kiểm tra đã nhận đủ '
                  '${DisplayFormatters.vnd(draft.amountVnd)}, đúng nội dung và người gửi. '
                  'CivilTrust không kết nối ngân hàng.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controllers['paymentReference'],
                  decoration: const InputDecoration(
                    labelText: 'Mã giao dịch hoặc ghi chú xác nhận',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: busy ? null : finalize,
                  icon: const Icon(Icons.verified),
                  label: Text(
                    'Tôi xác nhận đã nhận đủ ${DisplayFormatters.vnd(draft.amountVnd)}',
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _completedStep() => SectionCard(
    child: Column(
      children: [
        const CircleAvatar(
          radius: 34,
          backgroundColor: Color(0xffd1fae5),
          child: Icon(Icons.check, size: 38, color: Color(0xff047857)),
        ),
        const SizedBox(height: 14),
        const Text(
          'Hồ sơ đã được tạo',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          notaryReceived
              ? 'PDF cuối đã được đóng băng và đã nhận phản hồi SCT. App chưa tự xác minh chữ ký SCT hoặc Merkle proof.'
              : 'PDF cuối đã được đóng băng. Notary chưa sẵn sàng nên ZIP hiện chưa có SCT.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        SelectableText(
          'Hash PDF: ${bundle!.evidence.documentHash}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            const Chip(
              avatar: Icon(Icons.check_circle_outline, size: 18),
              label: Text('PDF hash đã tính'),
            ),
            Chip(
              avatar: Icon(
                notaryReceived ? Icons.receipt_long : Icons.cloud_off,
                size: 18,
              ),
              label: Text(
                notaryReceived ? 'Có SCT · chưa tự xác minh' : 'Chưa có SCT',
              ),
            ),
            Chip(
              avatar: const Icon(Icons.schedule, size: 18),
              label: Text(
                notaryStatus == null
                    ? 'On-chain chưa kiểm tra'
                    : 'Service: $notaryStatus · chưa tự kiểm',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: busy ? null : refreshNotaryStatus,
          icon: const Icon(Icons.sync),
          label: const Text('Kiểm tra trạng thái Notary'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => FileSaver.instance.saveFile(
            name: 'civiltrust-${session!.draft.id}',
            bytes: bundle!.zip,
            fileExtension: 'zip',
            mimeType: MimeType.zip,
          ),
          icon: const Icon(Icons.download),
          label: const Text('Tải lại hồ sơ ZIP'),
        ),
        TextButton(onPressed: reset, child: const Text('Tạo hợp đồng khác')),
      ],
    ),
  );
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, required this.onTap});
  final ContractTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: const Color(0xffccfbf1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                template.kind == ContractKind.loan
                    ? Icons.payments_outlined
                    : Icons.handshake_outlined,
                color: const Color(0xff0f766e),
                size: 32,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.title,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(template.subtitle),
                  const SizedBox(height: 7),
                  Text(
                    'Mẫu tham chiếu: ${template.sourceFile}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 18),
          ],
        ),
      ),
    ),
  );
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.done, required this.text});
  final bool done;
  final String text;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      done ? Icons.check_circle : Icons.radio_button_unchecked,
      color: done ? const Color(0xff059669) : Colors.grey,
    ),
    title: Text(text),
  );
}
