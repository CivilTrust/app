import 'package:flutter/material.dart';

import '../../app/flow_widgets.dart';
import 'identity_service.dart';

/// Diagnostics only: no read, no personal data, no network or export.
class NfcReadinessPage extends StatefulWidget {
  const NfcReadinessPage({required this.mode, super.key});
  final IdentityMode mode;
  @override
  State<NfcReadinessPage> createState() => _NfcReadinessPageState();
}

class _NfcReadinessPageState extends State<NfcReadinessPage> {
  late final service = IdentityService.forMode(widget.mode);
  IdentityCapability? result;
  bool busy = false;
  @override
  void dispose() {
    service.dispose();
    super.dispose();
  }

  Future<void> check() async {
    setState(() {
      busy = true;
      result = null;
    });
    final capability = await service.capability();
    if (!mounted) return;
    setState(() {
      result = capability;
      busy = false;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('NFC readiness · G0/G1')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TrustNotice(title: 'Chưa xác thực CCCD thật', message: service.notice),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Các điều kiện còn thiếu',
          icon: Icons.nfc,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Chế độ build: ${widget.mode.name}'),
              const Text(
                'Thiết bị đã xác nhận: iPhone 12, iOS 26.2. Chưa kiểm NFC native.',
              ),
              const Text(
                'Apple Developer team / App Store Connect: nhóm chưa có; signing / TestFlight bị chặn.',
              ),
              const Text('SDK CCCD, AID, trust anchor và verifier: chưa có.'),
              const Text(
                'macOS CI: cần cấu hình và chạy thực tế; Windows không build iOS native.',
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: busy ? null : check,
                child: const Text('Kiểm tra adapter hiện tại'),
              ),
              if (busy) const LinearProgressIndicator(),
              if (result != null)
                Text(
                  '${result!.available ? 'Adapter khả dụng' : 'Chưa khả dụng'}: ${result!.message}',
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Trang này không quét thẻ, không yêu cầu CCCD, không gọi coordinator hoặc upload dữ liệu. Reader mock khả dụng không có nghĩa NFC thật hoạt động. Đọc chip, xác thực chip và xác thực chủ thẻ là ba kết quả khác nhau.',
        ),
      ],
    ),
  );
}
