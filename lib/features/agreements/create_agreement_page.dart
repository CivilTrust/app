import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../app/flow_widgets.dart';
import '../../core/config/app_config.dart';
import '../../core/config/environment_check.dart';
import '../../core/crypto/hash_service.dart';
import '../../core/encoding/encoding_utils.dart';
import '../../core/formatting/display_formatters.dart';
import '../../core/ids/agreement_id.dart';
import '../../core/models/agreement.dart';
import '../../core/models/identity_evidence.dart';
import '../../core/models/party_role.dart';
import '../workspace/workflow_rules.dart';
import '../workspace/agreement_vault.dart';
import '../artifacts/artifact_service.dart';
import '../identity/identity_service.dart';
import '../identity/identity_context.dart';
import '../notary/notary_client.dart';
import '../notary/sct_verification_text.dart';
import '../notary/sct_verifier.dart';
import '../notary/signed_commitment_token.dart';
import '../payment/payment_details.dart';
import '../payment/payment_qr_card.dart';
import '../sessions/remote_session_repository.dart';
import '../sessions/invite_url.dart';
import '../sessions/session_models.dart';
import '../signing/mock_party_signer.dart';
import '../signing/session_validator.dart';
import '../signing/signing_context.dart';
import 'contract_template.dart';
import 'contract_template_service.dart';
import 'agreement_validator.dart';

class CreateAgreementPage extends StatefulWidget {
  const CreateAgreementPage({
    required this.config,
    this.identityService,
    this.onPrepared,
    this.onSaveForm,
    this.initialForm,
    this.vaultUnlocked = false,
    this.vault,
    this.onUnlockVault,
    super.key,
  });
  final AppConfig config;
  final IdentityService? identityService;
  final Future<void> Function(AgreementDraft draft, String formId)? onPrepared;
  final Future<void> Function(Map<String, dynamic> form, bool explicit)?
  onSaveForm;
  final Map<String, dynamic>? initialForm;
  final bool vaultUnlocked;
  final AgreementVault? vault;
  final Future<bool> Function()? onUnlockVault;

  @override
  State<CreateAgreementPage> createState() => _CreateAgreementPageState();
}

class _CreateAgreementPageState extends State<CreateAgreementPage>
    with WidgetsBindingObserver {
  final templateService = ContractTemplateService();
  final hash = const HashService();
  final signer = MockPartySigner();
  late final identityService =
      widget.identityService ??
      IdentityService.forMode(widget.config.identityMode);
  String ceremonyId = createIdentityNonce();
  final validator = const AgreementValidator();
  final controllers = <String, TextEditingController>{};
  final formKey = GlobalKey<FormState>();
  ContractTemplate? selectedTemplate;
  AgreementDraft? reviewDraft;
  IdentityEvidence? identityA;
  SigningSession? session;
  SessionCapabilities? owner;
  int? version;
  ArtifactBundle? bundle;
  var stage = 0;
  var confirmedReview = false;
  var identityConsent = false;
  var busy = false;
  SctVerificationResult? sctVerification;
  String? inviteUrl;
  String? notaryStatus;
  DateTime? expiresAt;
  String message = '';
  PartyRole creatorRole = PartyRole.partyA;
  String formId = 'draft:${createIdentityNonce()}';
  bool _saveQueued = false;
  bool _vaultWasOpened = false;
  bool get vaultReady => widget.vault?.unlocked ?? widget.vaultUnlocked;
  void _vaultChanged() {
    if (!mounted) return;
    if (vaultReady) {
      _vaultWasOpened = true;
    } else if (_vaultWasOpened) {
      identityService.cancel();
      identityA = null;
      identityConsent = false;
      confirmedReview = false;
      reviewDraft = null;
      if (selectedTemplate != null) stage = 1;
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _vaultWasOpened = vaultReady;
    widget.vault?.addListener(_vaultChanged);
    final saved = widget.initialForm;
    if (saved != null) {
      try {
        creatorRole = PartyRole.values.byName(saved['creatorRole'] as String);
        selectTemplate(templateService.byId(saved['templateId'] as String));
        formId = saved['localId'] as String;
        final values = Map<String, String>.from(saved['fields'] as Map);
        for (final entry in controllers.entries) {
          if (values.containsKey(entry.key)) {
            entry.value.text = values[entry.key]!;
          }
        }
      } catch (_) {
        stage = 0;
        message = 'Bản nháp không hợp lệ; chưa khôi phục dữ liệu.';
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) identityService.cancel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.vault?.removeListener(_vaultChanged);
    identityService.dispose();
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

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
    for (final controller in controllers.values) {
      controller.addListener(_scheduleSave);
    }
    setState(() {
      formId = 'draft:${createIdentityNonce()}';
      selectedTemplate = template;
      reviewDraft = null;
      stage = 1;
      identityConsent = false;
      identityA = null;
      ceremonyId = createIdentityNonce();
      message = '';
    });
  }

  Map<String, dynamic> _form() => {
    'localId': formId,
    'kind': 'form',
    'templateId': selectedTemplate!.id,
    'creatorRole': creatorRole.name,
    'fields': fields,
    'savedAt': DateTime.now().toUtc().toIso8601String(),
    'revision': widget.initialForm?['revision'] ?? 1,
    if (widget.initialForm?['supersedesAgreementId'] != null)
      'supersedesAgreementId': widget.initialForm!['supersedesAgreementId'],
  };

  void _scheduleSave() {
    if (_saveQueued || widget.onSaveForm == null || !vaultReady) {
      return;
    }
    _saveQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _saveQueued = false;
      if (!mounted || selectedTemplate == null || busy) return;
      try {
        await widget.onSaveForm!(_form(), false);
      } catch (_) {
        if (mounted) {
          setState(
            () => message = 'Chưa lưu được bản nháp. Giữ tab và kiểm tra kho.',
          );
        }
      }
    });
  }

  Future<void> saveForm() => _run(() async {
    await widget.onSaveForm!(_form(), true);
    message = 'Đã lưu bản nháp trong kho mã hóa. Không lưu kết quả NFC hoặc consent để dùng lại.';
  });

  Future<void> readIdentity() => _run(() async {
    final evidence = await identityService.identify(
      context: IdentityContext.create(
        ceremonyId: ceremonyId,
        role: creatorRole.name,
      ),
      consent: identityConsent,
    );
    if (!mounted) return;
    identityA = evidence;
    if (creatorRole == PartyRole.partyA &&
        controllers['accountName']!.text.isEmpty) {
      controllers['accountName']!.text = identityA!.displayName;
    }
    stage = 2;
    message = 'Đã điền thông tin ${creatorRole.label} từ CCCD mock.';
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
    final draftId = createAgreementId();
    final paymentFields = {
      ...fields,
      'paymentQrProfile': PaymentDetails.profile,
      'paymentPurpose': PaymentDetails.purposeFor(draftId),
      'signingProtocol': SigningContext.protocol,
      'identityCeremonyId': ceremonyId,
      if (widget.onPrepared != null) ...{
        'workflowProfile': creatorRole == PartyRole.partyB
            ? WorkflowRules.payerProfile
            : WorkflowRules.profile,
        'creatorRole': creatorRole.name,
        'payerRole': 'partyB',
        'payeeRole': 'partyA',
        'revision': (widget.initialForm?['revision'] ?? 1).toString(),
        'creatorIdentityCommitment': identityA!.identityCommitment,
        if (widget.initialForm?['supersedesAgreementId'] != null)
          'supersedesAgreementId':
              widget.initialForm!['supersedesAgreementId'] as String,
      },
    };
    if (widget.onPrepared != null && creatorRole == PartyRole.partyB) {
      paymentFields.removeWhere(
        (key, value) =>
            {'bankBin', 'accountNumber', 'accountName'}.contains(key),
      );
    }
    final reviewed = AgreementDraft(
      id: draftId,
      title: selectedTemplate!.title,
      terms: reviewText,
      amountVnd: amount,
      createdAt: DateTime.now().toUtc(),
      templateId: selectedTemplate!.id,
      fields: Map.unmodifiable(paymentFields),
    );
    // Validate everything before presenting the exact immutable snapshot A
    // will sign, including reference/version and beneficiary fields.
    if (creatorRole != PartyRole.partyB || widget.onPrepared == null) {
      PaymentDetails.fromDraft(reviewed);
    }
    setState(() {
      reviewDraft = reviewed;
      confirmedReview = false;
      stage = 3;
      message = '';
    });
    return true;
  }

  String get reviewText => templateService.renderReview(
    template: selectedTemplate!,
    fields: fields,
    partyA: identityA!,
    creatorRole: creatorRole,
  );

  Future<void> createSession() => _run(() async {
    if (!confirmedReview) {
      throw StateError('Bạn phải xác nhận đã đọc nội dung.');
    }
    final draft = reviewDraft;
    if (draft == null) throw StateError('Hãy xem lại thông tin trước khi ký.');
    if (widget.onPrepared != null) {
      await widget.onSaveForm?.call(_form(), true);
      await widget.onPrepared!(draft, formId);
      if (mounted) reset();
      return;
    }
    final digest = hash.canonicalObjectHash(draft.toJson());
    final signature = await signer.sign(
      role: 'partyA',
      digest: hexToBytes(digest),
      identity: identityA!,
      context: SigningContext.fromDraft(draft),
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
    // Native v1 intake uses an opaque paste code, not a bogus file:// invite.
    inviteUrl = {'http', 'https'}.contains(Uri.base.scheme)
        ? buildInviteUrl(Uri.base, fragment)
        : 'join=$fragment';
    stage = 4;
    message = 'Đã khóa nội dung. Gửi link cho Bên B để xác minh và ký.';
  });

  Future<void> confirmAndCreateSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.onPrepared == null
              ? 'Khóa nội dung và ký?'
              : 'Tạo đề xuất và lưu vào kho?',
        ),
        content: Text(
          widget.onPrepared == null
              ? 'Sau bước này, Bên A và Bên B sẽ ký đúng nội dung đang hiển thị. Muốn sửa điều khoản, bạn phải tạo phiên và chữ ký mới.'
              : 'Đây chưa phải chữ ký. A cung cấp/kiểm tra thông tin nhận tiền, khóa bản cuối và ký trước. B kiểm tra rồi ký. Quyền phiên được lưu trong kho mã hóa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại xem'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              widget.onPrepared == null ? 'Khóa và ký' : 'Tạo đề xuất',
            ),
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
    sctVerification = null;
    SignedCommitmentToken? receivedSct;
    try {
      if (!widget.config.notaryEnabled) {
        message = 'Hoàn tất offline. Bản demo đã tắt Notary; ZIP không có SCT.';
      } else {
        _checkNotaryConfiguration();
        receivedSct = await NotaryClient(widget.config.notaryBaseUrl)
            .submit(result.evidence.documentHash);
      }
    } catch (error) {
      message = 'Hoàn tất offline. Notary chưa sẵn sàng: $error';
    }
    if (receivedSct != null) {
      result = ArtifactService(hash).attachNotary(result, receivedSct.toJson());
      sctVerification = const SctVerifier().verify(
        receivedSct,
        documentHash: result.evidence.documentHash,
        policy: widget.config.sctTrustPolicy,
      );
      message =
          'Đã tạo PDF. ${sctVerificationLabel(sctVerification!)}. '
          '${sctVerificationDetail(sctVerification!)}';
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
    _checkNotaryConfiguration();
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

  void _checkNotaryConfiguration() {
    if (!widget.config.notaryEnabled ||
        checkEnvironment(widget.config, Uri.base, isWeb: kIsWeb).any(
          (issue) =>
              {'Notary', 'Trang Web', 'Môi trường'}.contains(issue.target),
        )) {
      throw const NotaryClientException(
        'Notary chưa được cấu hình phù hợp. Kiểm tra mục Thông tin.',
      );
    }
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (busy) return;
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
      reviewDraft = null;
      identityA = null;
      ceremonyId = createIdentityNonce();
      session = null;
      owner = null;
      version = null;
      inviteUrl = null;
      bundle = null;
      confirmedReview = false;
      identityConsent = false;
      sctVerification = null;
      notaryStatus = null;
      expiresAt = null;
      message = '';
    });
  }

  @override
  Widget build(BuildContext context) => _vaultWasOpened && !vaultReady
      ? ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const FlowHeader(
              title: 'Kho đã khóa',
              subtitle: 'Nội dung bản nháp được ẩn. Mở kho để tiếp tục; danh tính và consent sẽ đọc lại.',
            ),
            FilledButton(
              onPressed: widget.onUnlockVault,
              child: const Text('Mở khóa để tiếp tục bản nháp'),
            ),
          ],
        )
      : ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            FlowHeader(
              title: 'Tạo hợp đồng mới',
              subtitle: widget.onPrepared == null
                  ? 'Chọn mẫu, xác minh danh tính, điền điều khoản và mời Bên B ký từ xa.'
                  : 'A hoặc B đều có thể tạo. A bổ sung thông tin nhận tiền và ký trước; B kiểm tra, ký rồi chuyển khoản. Danh tính hiện là mock.',
            ),
            FlowProgress(
              current: stage.clamp(0, 5),
              labels: [
                'Chọn mẫu',
                'Danh tính ${creatorRole == PartyRole.partyA ? 'A' : 'B'}',
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
            if (selectedTemplate != null && widget.onSaveForm != null) ...[
              Text(
                vaultReady
                    ? 'Bản nháp tự lưu khi chỉnh sửa. Kết quả định danh phải đọc lại khi ký.'
                    : 'Kho chưa mở: bản nháp chỉ ở trong tab. Chọn Lưu bản nháp để bảo vệ trước khi đóng.',
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : saveForm,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Lưu bản nháp'),
              ),
            ],
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
      if (widget.onPrepared != null) ...[
        DropdownButtonFormField<PartyRole>(
          isExpanded: true,
          initialValue: creatorRole,
          decoration: const InputDecoration(
            labelText: 'Vai trò của tôi trong hợp đồng',
          ),
          items: [
            for (final role in PartyRole.values)
              DropdownMenuItem(
                value: role,
                child: Text(
                  '${role.label} · ${role == PartyRole.partyA ? 'Nhận tiền' : 'Chuyển tiền'}',
                ),
              ),
          ],
          onChanged: (role) {
            if (role != null) {
              setState(() {
                creatorRole = role;
                identityA = null;
              });
            }
          },
        ),
        const SizedBox(height: 12),
      ],
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
    title:
        'Danh tính ${creatorRole.label} · ${creatorRole.businessLabel(selectedTemplate!.id)}',
    icon: Icons.badge_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TrustNotice(
          title: identityService.isMock
              ? 'Đang sử dụng dữ liệu mô phỏng'
              : 'NFC chưa sẵn sàng',
          message: identityService.notice,
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: identityConsent,
          onChanged: (value) =>
              setState(() => identityConsent = value ?? false),
          title: Text(
            identityService.isMock
                ? 'Tôi đồng ý dùng dữ liệu CCCD mô phỏng cho bản demo'
                : 'Tôi đồng ý bắt đầu kiểm tra khả năng NFC (chưa đọc CCCD thật)',
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
          label: Text(
            identityService.isMock
                ? 'Quét CCCD mock của ${creatorRole.label}'
                : 'Kiểm tra NFC ${creatorRole.label}',
          ),
        ),
        if (busy)
          TextButton(
            onPressed: identityService.cancel,
            child: const Text('Hủy đọc danh tính'),
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
            title:
                '${creatorRole.label} · ${creatorRole.businessLabel(selectedTemplate!.id)}',
            icon: Icons.badge_outlined,
            child: IdentitySummary(
              identity: identityA!.toJson(),
              role:
                  '${creatorRole.label} · ${creatorRole.businessLabel(selectedTemplate!.id)}',
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
                if (widget.onPrepared != null &&
                    creatorRole == PartyRole.partyB)
                  const TrustNotice(
                    title: 'B chỉ soạn điều khoản của đề xuất',
                    message: 'Bạn không cần nhập danh tính hoặc tài khoản của A. Sau lời mời, A đọc mock, bổ sung tài khoản và ký trước; bạn kiểm tra bản cuối rồi ký.',
                  ),
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
          if (widget.onPrepared == null || creatorRole == PartyRole.partyA)
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
              reviewDraft!.terms,
              style: const TextStyle(height: 1.55),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      SectionCard(
        title: 'Thông tin chuyển khoản sẽ được khóa',
        icon: Icons.account_balance,
        child: SelectableText(
          creatorRole == PartyRole.partyB && widget.onPrepared != null
              ? 'A sẽ tự cung cấp danh tính và tài khoản nhận tiền sau khi được mời. A ký trước; bạn kiểm tra bản cuối rồi ký.'
              : PaymentDetails.fromDraft(reviewDraft!).copyText,
        ),
      ),
      const SizedBox(height: 12),
      const TrustNotice(
        title: 'Phạm vi chữ ký',
        message:
            'Chữ ký demo v2 ràng buộc nội dung, vai trò và danh tính mô phỏng; không xác thực CCCD thật. Xác nhận nhận tiền và PDF cuối '
            'được tạo sau đó, được ghi thành bằng chứng riêng trong hồ sơ.',
      ),
      if (widget.onPrepared != null)
        const TrustNotice(
          title: 'Đây là đề xuất, chưa ký',
          message: 'Sau khi tạo, A kiểm tra và có thể sửa thông tin tài khoản nhận trước khi khóa. Người tạo và đối tác đều phải xem lại bản đã khóa và đọc danh tính mới khi ký. B luôn chuyển cho A.',
        ),
      const SizedBox(height: 8),
      CheckboxListTile(
        value: confirmedReview,
        onChanged: (value) => setState(() => confirmedReview = value ?? false),
        title: Text(
          widget.onPrepared == null
              ? 'Tôi đã đọc, thông tin đúng và đồng ý khóa nội dung này.'
              : 'Tôi đã đọc và đồng ý gửi bản đề xuất; chữ ký là bước riêng sau khi A duyệt.',
        ),
        subtitle: Text(
          widget.onPrepared == null
              ? 'Sau bước này, mọi sửa đổi phải tạo hợp đồng mới.'
              : 'Thông tin nhận tiền có thể được A sửa trước khi khóa; cả hai bên sẽ xem lại bản khóa trước khi ký.',
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
              label: Text(
                widget.onPrepared == null
                    ? 'Khóa và ký với danh tính A'
                    : 'Tạo đề xuất và lưu hồ sơ',
              ),
            ),
          ),
        ],
      ),
      TextButton(
        onPressed: busy
            ? null
            : () => setState(() {
                identityA = null;
                reviewDraft = null;
                confirmedReview = false;
                identityConsent = false;
                ceremonyId = createIdentityNonce();
                stage = 1;
              }),
        child: const Text('Đọc lại danh tính / làm mới challenge'),
      ),
    ],
  );

  Widget _shareStep() {
    final draft = session!.draft;
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
        PaymentQrCard(draft: draft),
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
          sctVerification == null
              ? 'PDF cuối đã được đóng băng. ZIP hiện chưa có SCT.'
              : 'PDF cuối đã được đóng băng. '
                    '${sctVerificationDetail(sctVerification!)}',
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
                sctVerification == null
                    ? Icons.cloud_off
                    : sctVerification!.isValid
                    ? Icons.verified
                    : Icons.receipt_long,
                size: 18,
              ),
              label: Text(
                sctVerification == null
                    ? 'Chưa có SCT'
                    : sctVerificationLabel(sctVerification!),
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
          onPressed: busy || !widget.config.notaryEnabled
              ? null
              : refreshNotaryStatus,
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
