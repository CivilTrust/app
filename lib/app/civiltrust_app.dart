import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

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
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff0f766e),
        primary: const Color(0xff0f766e),
        secondary: const Color(0xffd97706),
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xfff4f7f6),
      useMaterial3: true,
      cardTheme: const CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xfff8faf9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffd5dfdc)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffd5dfdc)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ),
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

  @override
  Widget build(BuildContext context) {
    final blocksSession = checkEnvironment(config, Uri.base, isWeb: kIsWeb).any(
      (issue) =>
          {'Coordinator', 'Trang Web', 'Môi trường'}.contains(issue.target),
    );
    final pages = [
      blocksSession
          ? EnvironmentPage(config: config)
          : CreateAgreementPage(
              config: config,
              vault: vault,
              onUnlockVault: unlock,
              vaultUnlocked: vault.unlocked,
              onPrepared: prepared,
              onSaveForm: saveForm,
            ),
      blocksSession
          ? EnvironmentPage(config: config)
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xfff4f7f6),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xff0f766e),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.gavel_rounded, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CivilTrust',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'Hợp đồng điện tử có thể kiểm chứng',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1060),
          child: IndexedStack(index: index, children: pages),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            selectedIcon: Icon(Icons.add_box),
            label: 'Tạo hợp đồng',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Tham gia ký',
          ),
          NavigationDestination(icon: Icon(Icons.folder_open), label: 'Hồ sơ'),
          NavigationDestination(
            icon: Icon(Icons.verified_outlined),
            selectedIcon: Icon(Icons.verified),
            label: 'Kiểm chứng',
          ),
          NavigationDestination(
            icon: Icon(Icons.info_outline),
            label: 'Thông tin',
          ),
        ],
      ),
    );
  }
}
