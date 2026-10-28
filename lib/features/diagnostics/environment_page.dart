import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/app_config.dart';
import '../../core/config/environment_check.dart';
import '../../app/flow_widgets.dart';
import 'connectivity_service.dart';
import '../payment/vietqr_preview_page.dart';
import '../identity/nfc_readiness_page.dart';

class EnvironmentPage extends StatefulWidget {
  const EnvironmentPage({
    required this.config,
    this.pageUri,
    this.service,
    super.key,
  });
  final AppConfig config;
  final Uri? pageUri;
  final ConnectivityService? service;
  @override
  State<EnvironmentPage> createState() => _EnvironmentPageState();
}

class _EnvironmentPageState extends State<EnvironmentPage> {
  late final service = widget.service ?? ConnectivityService();
  var busy = false;
  List<ConnectionResult> results = const [];
  @override
  void dispose() {
    if (widget.service == null) service.close();
    super.dispose();
  }

  Future<void> check() async {
    setState(() {
      busy = true;
      results = const [];
    });
    final checked = await service.check(
      widget.config,
      widget.pageUri ?? Uri.base,
      isWeb: widget.pageUri != null || kIsWeb,
    );
    if (!mounted) return;
    setState(() {
      busy = false;
      results = checked;
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final issues = checkEnvironment(
      config,
      widget.pageUri ?? Uri.base,
      isWeb: widget.pageUri != null || kIsWeb,
    );
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const FlowHeader(
          title: 'Kiểm tra trước khi demo',
          subtitle: 'Mở trang này trên cả Windows và iPhone để kiểm kết nối. Chỉ dùng dữ liệu mô phỏng trong bản demo.',
        ),
        SectionCard(
          title: 'Môi trường ${config.environment}',
          icon: Icons.settings,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText(
                'Coordinator: ${endpointOrigin(config.coordinatorBaseUrl)}\n'
                'Notary: ${config.notaryEnabled ? endpointOrigin(config.notaryBaseUrl) : 'đã tắt — offline'}\n'
                'Chain ID: ${config.chainId}\nRegistry: ${config.hasRegistry ? config.registryContract : 'chưa cấu hình'}',
              ),
              const SizedBox(height: 12),
              if (issues.isEmpty)
                const Text(
                  'Định dạng URL phù hợp. Cần kiểm kết nối thực tế bên dưới.',
                )
              else
                for (final issue in issues)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${issue.target}: ${issue.message}',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: busy ? null : check,
                icon: const Icon(Icons.network_check),
                label: const Text('Kiểm tra kết nối'),
              ),
              if (busy) const LinearProgressIndicator(),
              for (final result in results)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    result.status == ConnectionStatus.ready
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                  ),
                  title: Text(result.target),
                  subtitle: Text(result.message),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const VietQrPreviewPage()),
          ),
          icon: const Icon(Icons.qr_code),
          label: const Text('Thử VietQR cục bộ'),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => NfcReadinessPage(mode: config.identityMode),
            ),
          ),
          icon: const Icon(Icons.nfc),
          label: const Text('Kiểm tra NFC readiness'),
        ),
        const SizedBox(height: 16),
        const TrustNotice(
          title: 'NFC chưa sẵn sàng',
          message:
              'Bản hiện tại dùng CCCD mock. Safari không chạy adapter Core NFC của app iOS. '
              'Đọc chip thật còn cần môi trường macOS/Xcode (có thể dùng CI), app iOS đã ký, giao thức/SDK CCCD, AID và trust anchor. '
              'Chưa đưa dữ liệu CCCD thật vào bản demo.',
        ),
        const SizedBox(height: 16),
        const Text(
          'Kết quả này chỉ kiểm health và cấu hình mạng, không xác nhận đã ký, đã nhận tiền hoặc đã neo blockchain. '
          'Coordinator lưu trong bộ nhớ; khởi động lại sẽ mất phiên. Không chia sẻ link mời trong log hoặc ảnh chụp.',
        ),
      ],
    );
  }
}
