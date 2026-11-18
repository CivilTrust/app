import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../ui/app_theme.dart';
import '../ui/components.dart';
import '../ui/notifier.dart';
import '../app/flow_widgets.dart';
import '../core/formatting/display_formatters.dart';
import '../features/workspace/workspace_watcher.dart';
import '../features/home/home_page.dart';
import '../features/identity/identity_service.dart';
import '../features/legal/legal_content.dart';
import '../features/legal/legal_pages.dart';

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
  late final watcher = WorkspaceWatcher(workspace);
  int _announced = 0;
  late int index;
  final _bodyKey = GlobalKey(debugLabel: 'civiltrust-body');

  @override
  void initState() {
    super.initState();
    vault.addListener(changed);
    watcher.addListener(_watcherChanged);
    WidgetsBinding.instance.addObserver(this);
    index = Uri.base.fragment.startsWith('join=') ? _joinTab : _homeTab;
  }

  void changed() {
    if (mounted) setState(() {});
  }

  /// Announces newly detected remote changes once, with a shortcut to open.
  void _watcherChanged() {
    if (!mounted) return;
    final unread = watcher.unread;
    if (unread > _announced && watcher.notifications.isNotEmpty) {
      final latest = watcher.notifications.first;
      showAppToast(
        context,
        latest.message,
        tone: latest.needsAction ? AppTone.warning : AppTone.info,
        actionLabel: 'Mở',
        onAction: () => _openFromNotification(latest),
      );
    }
    _announced = unread;
    setState(() {});
  }

  Future<void> _openFromNotification(AppNotification item) async {
    try {
      await openRecord(item.localId);
    } catch (e) {
      if (mounted) {
        showAppToast(context, friendlyError(e), tone: AppTone.danger);
      }
    }
  }

  Future<void> showNotifications() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheet) => ListenableBuilder(
      listenable: watcher,
      builder: (sheet, _) {
        final items = watcher.notifications;
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Thông báo',
                        style: Theme.of(sheet).textTheme.titleLarge,
                      ),
                    ),
                    if (watcher.unread > 0)
                      TextButton(
                        onPressed: watcher.markAllRead,
                        child: const Text('Đánh dấu đã đọc'),
                      ),
                  ],
                ),
              ),
              if (!vault.unlocked)
                const EmptyState(
                  icon: Icons.lock_outline,
                  title: 'Mở kho để nhận thông báo',
                  message: 'App chỉ kiểm tra thay đổi khi kho hợp đồng đang mở và app đang hiển thị.',
                )
              else if (items.isEmpty)
                const EmptyState(
                  icon: Icons.notifications_none,
                  title: 'Chưa có thông báo mới',
                  message: 'App tự kiểm tra khoảng mỗi 45 giây khi đang mở. Mở hồ sơ để xem trạng thái mới nhất.',
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final item = items[i];
                      return ListTile(
                        leading: Icon(
                          item.needsAction
                              ? Icons.notification_important_outlined
                              : Icons.info_outline,
                          color: item.needsAction
                              ? AppTone.warning.foreground
                              : AppTone.info.foreground,
                        ),
                        title: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: item.read
                                ? FontWeight.w500
                                : FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          '${item.message}\n${DisplayFormatters.dateTime(item.at)}',
                        ),
                        isThreeLine: true,
                        trailing: item.read
                            ? null
                            : const Icon(
                                Icons.circle,
                                size: 10,
                                color: AppColors.primary,
                              ),
                        onTap: () {
                          Navigator.pop(sheet);
                          _openFromNotification(item);
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    ),
  );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      watcher.setActive(false);
      vault.lock();
    } else if (state == AppLifecycleState.resumed) {
      watcher.setActive(true);
    }
  }

  @override
  void dispose() {
    vault.removeListener(changed);
    watcher.removeListener(_watcherChanged);
    watcher.dispose();
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
    // The detail page syncs on open; the stored copy is now current.
    watcher.markSeen(id);
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

  static const _homeTab = 0, _createTab = 1, _joinTab = 2, _recordsTab = 3;
  static const _verifyTab = 4;
  static const _destinations = [
    (Icons.home_outlined, Icons.home, 'Trang chủ', 'Trang chủ'),
    (Icons.add_box_outlined, Icons.add_box, 'Tạo mới', 'Tạo hợp đồng'),
    (Icons.qr_code_scanner, Icons.qr_code_scanner, 'Tham gia', 'Tham gia ký'),
    (Icons.folder_open_outlined, Icons.folder_open, 'Hồ sơ', 'Hồ sơ hợp đồng'),
    (Icons.verified_outlined, Icons.verified, 'Kiểm chứng', 'Kiểm chứng'),
  ];

  void openTools() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Công cụ & chẩn đoán')),
        body: EnvironmentPage(config: config),
      ),
    ),
  );

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
      onDetails: openTools,
    );
    void go(int tab) => setState(() => index = tab);
    final pages = [
      HomePage(
        onCreate: () => go(_createTab),
        onJoin: () => go(_joinTab),
        onRecords: () => go(_recordsTab),
        onVerify: () => go(_verifyTab),
        mockIdentity: config.identityMode == IdentityMode.mock,
      ),
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
        hasUpdate: watcher.hasUpdate,
        unlock: unlock,
        open: openRecord,
        resumeForm: resumeForm,
      ),
      VerifyBundlePage(config: config),
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
    return Title(
      title: watcher.unread == 0
          ? 'CivilTrust'
          : '(${watcher.unread}) CivilTrust',
      color: AppColors.primary,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 64,
          titleSpacing: 16,
          title: const _BrandTitle(),
          actions: [
            IconButton(
              tooltip: watcher.unread == 0
                  ? 'Thông báo'
                  : 'Thông báo: ${watcher.unread} chưa đọc',
              onPressed: showNotifications,
              icon: Badge(
                isLabelVisible: watcher.unread > 0,
                label: Text('${watcher.unread}'),
                child: Icon(
                  watcher.unread > 0
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_none,
                ),
              ),
            ),
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
            PopupMenuButton<String>(
              tooltip: 'Thêm',
              icon: const Icon(Icons.more_vert),
              onSelected: (value) => switch (value) {
                'faq' => openLegalPage(context, const FaqPage()),
                'terms' => openLegalPage(
                  context,
                  const LegalDocumentPage(document: termsOfUse),
                ),
                'privacy' => openLegalPage(
                  context,
                  const LegalDocumentPage(document: privacyPolicy),
                ),
                _ => openTools(),
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'faq',
                  child: ListTile(
                    leading: Icon(Icons.help_outline),
                    title: Text('Câu hỏi thường gặp'),
                  ),
                ),
                PopupMenuItem(
                  value: 'terms',
                  child: ListTile(
                    leading: Icon(Icons.description_outlined),
                    title: Text('Điều khoản sử dụng'),
                  ),
                ),
                PopupMenuItem(
                  value: 'privacy',
                  child: ListTile(
                    leading: Icon(Icons.privacy_tip_outlined),
                    title: Text('Chính sách quyền riêng tư'),
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: 'tools',
                  child: ListTile(
                    leading: Icon(Icons.build_outlined),
                    title: Text('Công cụ & chẩn đoán'),
                    subtitle: Text('Kết nối, thử VietQR, NFC'),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
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
                          label: Text(d.$3),
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
