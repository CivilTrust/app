import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../ui/app_theme.dart';

import '../core/config/app_config.dart';
import '../core/config/environment_check.dart';
import '../features/diagnostics/environment_page.dart';
import '../features/agreements/create_agreement_page.dart';
import '../features/agreements/join_agreement_page.dart';
import '../features/artifacts/verify_bundle_page.dart';
import '../features/workspace/agreement_vault.dart';
import '../features/workspace/vault_storage_factory.dart';
import '../features/workspace/vault_dialog.dart';
import '../features/workspace/workspace_repository.dart';
import '../features/workspace/workspace_service.dart';
import '../features/workspace/workspace_history_page.dart';
import '../features/workspace/workspace_detail_page.dart';
import '../core/models/agreement.dart';
import '../features/sessions/session_models.dart';

class CivilTrustApp extends StatelessWidget {
  const CivilTrustApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'CivilTrust',
    theme: buildAppTheme(),
    locale: const Locale('vi', 'VN'),
    supportedLocales: const [Locale('vi', 'VN'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: const CivilTrustHome(),
  );
}

class CivilTrustHome extends StatefulWidget {
  const CivilTrustHome({super.key});

  @override
  State<CivilTrustHome> createState() => _CivilTrustHomeState();
}

class _CivilTrustHomeState extends State<CivilTrustHome>
    with WidgetsBindingObserver {
  final config = AppConfig.fromEnvironment();
  late final vault = AgreementVault(createVaultStorage());
  late final workspaceRepository = WorkspaceRepository(
    config.coordinatorBaseUrl,
  );
  late final workspace = WorkspaceService(vault, workspaceRepository);
  late int index;
  final _bodyKey = GlobalKey(debugLabel: 'civiltrust-body');

  @override
  void initState() {
    super.initState();
    vault.addListener(changed);
    WidgetsBinding.instance.addObserver(this);
    index = Uri.base.fragment.startsWith('join=') ? 1 : 0;
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      vault.lock();
    }
  }

  @override
  void dispose() {
    vault.removeListener(changed);
    WidgetsBinding.instance.removeObserver(this);
    vault.dispose();
    workspaceRepository.close();
    super.dispose();
  }

  Future<bool> unlock() => unlockVaultDialog(context, vault);
  Future<void> saveForm(Map<String, dynamic> form, bool explicit) async {
    if (!vault.unlocked && (!explicit || !await unlock())) {
      if (explicit) throw StateError('Chưa mở kho; bản nháp chưa lưu.');
      return;
    }
    await vault.put(form['localId'] as String, form);
  }

  Future<void> openRecord(String id) async {
    final local = workspace.record(id);
    await workspace.validator.validate(workspace.session(local));
    if (!{'partyA', 'partyB'}.contains(local['role'])) {
      throw const FormatException('Vai trò hồ sơ không hợp lệ.');
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkspaceDetailPage(
          service: workspace,
          localId: id,
          config: config,
          unlock: unlock,
          copyDraft: resumeForm,
        ),
      ),
    );
  }

  Future<void> prepared(AgreementDraft draft, String formId) async {
    if (!await unlock()) {
      throw StateError(
        'Chưa mở kho; không tạo phiên để tránh mất quyền truy cập.',
      );
    }
    final local = await workspace.create(draft, formId: formId);
    final previous = vault.records
        .where((r) => r['localId'] == formId)
        .firstOrNull;
    if (previous != null) {
      await vault.put(formId, {
        ...previous,
        'submittedSession': local['localId'],
      });
    }
    await openRecord(local['localId'] as String);
  }

  Future<void> resumeForm(Map<String, dynamic> form) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Tiếp tục bản nháp')),
          body: CreateAgreementPage(
            config: config,
            vault: vault,
            onUnlockVault: unlock,
            initialForm: form,
            vaultUnlocked: vault.unlocked,
            onPrepared: prepared,
            onSaveForm: saveForm,
          ),
        ),
      ),
    );
  }

  Future<void> joinWorkspace(SessionCapabilities invite) async {
    if (!await unlock()) throw StateError('Chưa mở kho; chưa nhận phiên.');
    final local = await workspace.join(invite);
    await openRecord(local['localId'] as String);
  }

  static const _destinations = [
    (Icons.add_box_outlined, Icons.add_box, 'Tạo mới', 'Tạo hợp đồng'),
    (Icons.qr_code_scanner, Icons.qr_code_scanner, 'Tham gia', 'Tham gia ký'),
    (Icons.folder_open_outlined, Icons.folder_open, 'Hồ sơ', 'Hồ sơ hợp đồng'),
    (Icons.verified_outlined, Icons.verified, 'Kiểm chứng', 'Kiểm chứng'),
    (Icons.info_outline, Icons.info, 'Thông tin', 'Thông tin & công cụ'),
  ];

  @override
  Widget build(BuildContext context) {
    final issues = checkEnvironment(config, Uri.base, isWeb: kIsWeb)
        .where(
          (issue) =>
              {'Coordinator', 'Trang Web', 'Môi trường'}.contains(issue.target),
        )
        .toList();
    Widget unavailable(String action) => _ServiceUnavailable(
      action: action,
      issues: issues,
      onDetails: () => setState(() => index = 4),
    );
    final pages = [
      issues.isNotEmpty
          ? unavailable('tạo hợp đồng')
          : CreateAgreementPage(
              config: config,
              vault: vault,
              onUnlockVault: unlock,
              vaultUnlocked: vault.unlocked,
              onPrepared: prepared,
              onSaveForm: saveForm,
            ),
      issues.isNotEmpty
          ? unavailable('tham gia ký')
          : JoinAgreementPage(config: config, onWorkspaceInvite: joinWorkspace),
      WorkspaceHistoryPage(
        service: workspace,
        unlock: unlock,
        open: openRecord,
        resumeForm: resumeForm,
      ),
      VerifyBundlePage(config: config),
      EnvironmentPage(config: config),
    ];
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= AppBreakpoints.rail;
    final extended = width >= AppBreakpoints.extendedRail;
    // GlobalKey keeps page state (e.g. a half-filled form) when the layout
    // switches between bottom bar and rail on resize/rotation.
    final body = Center(
      key: _bodyKey,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1060),
        child: IndexedStack(index: index, children: pages),
      ),
    );
    void select(int value) => setState(() => index = value);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 16,
        title: const _BrandTitle(),
        actions: [
          if (vault.unlocked)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Tooltip(
                message: 'Kho hợp đồng đang mở',
                child: Icon(
                  Icons.lock_open_rounded,
                  color: AppTone.success.foreground,
                  semanticLabel: 'Kho hợp đồng đang mở',
                ),
              ),
            ),
        ],
      ),
      body: useRail
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: select,
                  extended: extended,
                  labelType: extended
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  minExtendedWidth: 220,
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.$1),
                        selectedIcon: Icon(d.$2),
                        label: Text(extended ? d.$4 : d.$3),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: useRail
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: select,
              destinations: [
                for (final d in _destinations)
                  NavigationDestination(
                    icon: Icon(d.$1),
                    selectedIcon: Icon(d.$2),
                    label: d.$3,
                    tooltip: d.$4,
                  ),
              ],
            ),
    );
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.accent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.verified_user_outlined,
          color: Colors.white,
          size: 22,
        ),
      ),
      const SizedBox(width: 10),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'CivilTrust',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            Text(
              'Hợp đồng điện tử có thể kiểm chứng',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Shown instead of a signing flow when the deployment is misconfigured, so
/// users see a plain explanation rather than raw diagnostics.
class _ServiceUnavailable extends StatelessWidget {
  const _ServiceUnavailable({
    required this.action,
    required this.issues,
    required this.onDetails,
  });
  final String action;
  final List<EnvironmentIssue> issues;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
    children: [
      Icon(
        Icons.cloud_off_outlined,
        size: 48,
        color: AppTone.warning.foreground,
      ),
      const SizedBox(height: 12),
      Text(
        'Chưa thể $action',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 8),
      const Text(
        'Dịch vụ điều phối phiên ký chưa được cấu hình đúng cho địa chỉ này, '
        'nên app tạm khóa thao tác để không tạo phiên lỗi. Bạn vẫn có thể '
        'mở Hồ sơ đã lưu hoặc kiểm chứng gói ZIP.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 20),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dành cho người quản trị',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              for (final issue in issues)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('• ${issue.target}: ${issue.message}'),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: onDetails,
        icon: const Icon(Icons.build_outlined),
        label: const Text('Xem chi tiết kỹ thuật'),
      ),
    ],
  );
}
