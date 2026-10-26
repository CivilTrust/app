import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/config/environment_check.dart';
import '../features/diagnostics/environment_page.dart';
import '../features/agreements/create_agreement_page.dart';
import '../features/agreements/join_agreement_page.dart';
import '../features/artifacts/verify_bundle_page.dart';

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

class _CivilTrustHomeState extends State<CivilTrustHome> {
  final config = AppConfig.fromEnvironment();
  late int index;

  @override
  void initState() {
    super.initState();
    index = Uri.base.fragment.startsWith('join=') ? 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final blocksSession = checkEnvironment(config, Uri.base).any(
      (issue) =>
          {'Coordinator', 'Trang Web', 'Môi trường'}.contains(issue.target),
    );
    final pages = [
      blocksSession
          ? EnvironmentPage(config: config)
          : CreateAgreementPage(config: config),
      blocksSession
          ? EnvironmentPage(config: config)
          : JoinAgreementPage(config: config),
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
