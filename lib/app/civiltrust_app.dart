import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
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
    final pages = [
      CreateAgreementPage(config: config),
      JoinAgreementPage(config: config),
      VerifyBundlePage(config: config),
      _AboutPage(config: config),
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

class _AboutPage extends StatelessWidget {
  const _AboutPage({required this.config});
  final AppConfig config;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Text(
        'Cấu hình và giới hạn MVP',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SelectableText(
            'Coordinator: ${config.coordinatorBaseUrl}\n'
            'Notary: ${config.notaryBaseUrl}\n'
            'Chain ID: ${config.chainId}\nRegistry: ${config.registryContract}',
          ),
        ),
      ),
      const SizedBox(height: 16),
      const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'CCCD và chữ ký thiết bị hiện là mock có thể kiểm chứng. NFC thật trên iPhone '
            'sẽ thay IdentityReader bằng Core NFC mà không đổi luồng hợp đồng. App không tự '
            'khẳng định tiền đã đến; Bên A phải kiểm tra app ngân hàng trước khi xác nhận.',
          ),
        ),
      ),
    ],
  );
}
