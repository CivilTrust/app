import 'package:flutter/material.dart';

import '../../ui/app_theme.dart';

/// Full-screen reader for the frozen contract text. Returns true only after
/// the user has scrolled to the end and confirmed, so signing is not offered
/// on a contract that was never displayed in full.
class ContractReaderPage extends StatefulWidget {
  const ContractReaderPage({
    required this.title,
    required this.text,
    this.code,
    super.key,
  });
  final String title;
  final String text;
  final String? code;

  static Future<bool> open(
    BuildContext context, {
    required String title,
    required String text,
    String? code,
  }) async =>
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) =>
              ContractReaderPage(title: title, text: text, code: code),
        ),
      ) ==
      true;

  @override
  State<ContractReaderPage> createState() => _ContractReaderPageState();
}

class _ContractReaderPageState extends State<ContractReaderPage> {
  final controller = ScrollController();
  bool reachedEnd = false;

  @override
  void initState() {
    super.initState();
    controller.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (reachedEnd || !controller.hasClients) return;
    final position = controller.position;
    if (position.pixels >= position.maxScrollExtent - 24) {
      setState(() => reachedEnd = true);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đọc toàn văn hợp đồng')),
    body: Column(
      children: [
        Expanded(
          child: Scrollbar(
            controller: controller,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (widget.code != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Mã hồ sơ: ${widget.code}',
                            style: const TextStyle(color: AppColors.inkMuted),
                          ),
                        ),
                      const SizedBox(height: 16),
                      SelectableText(
                        widget.text,
                        style: const TextStyle(fontSize: 16, height: 1.6),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '— Hết nội dung —',
                        style: TextStyle(color: AppColors.inkMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!reachedEnd)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Cuộn hết nội dung để xác nhận đã đọc.',
                      style: TextStyle(color: AppColors.inkMuted),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: reachedEnd
                        ? () => Navigator.pop(context, true)
                        : null,
                    icon: const Icon(Icons.check),
                    label: const Text('Tôi đã đọc hết nội dung'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
