import 'package:flutter/material.dart';

import 'agreement_vault.dart';

Future<bool> unlockVaultDialog(
  BuildContext context,
  AgreementVault vault,
) async {
  if (vault.unlocked) return true;
  final exists = await vault.exists;
  if (!context.mounted) return false;
  final controller = TextEditingController();
  final confirmation = TextEditingController();
  String? error;
  bool busy = false;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(
          exists ? 'Mở khóa hợp đồng của tôi' : 'Tạo kho hợp đồng mã hóa',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Mật khẩu từ 12 ký tự. Không có quên mật khẩu. Giữ mật khẩu và gói khôi phục ở nơi an toàn; không dùng số CCCD. Không chia sẻ gói quyền truy cập cho đối tác.',
              ),
              TextField(
                controller: controller,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(labelText: 'Mật khẩu kho'),
              ),
              if (!exists)
                TextField(
                  controller: confirmation,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Nhập lại mật khẩu',
                  ),
                ),
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (!exists && controller.text != confirmation.text) {
                      setState(() => error = 'Mật khẩu nhập lại không khớp.');
                      return;
                    }
                    setState(() => busy = true);
                    try {
                      await vault.unlock(controller.text);
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, true);
                      }
                    } catch (e) {
                      if (dialogContext.mounted) {
                        setState(() {
                          error = e.toString();
                          busy = false;
                        });
                      }
                    }
                  },
            child: Text(exists ? 'Mở khóa' : 'Tạo kho'),
          ),
        ],
      ),
    ),
  );
  controller.clear();
  confirmation.clear();
  // Dialog exit animation may still hold the TextFields until the next frame.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    controller.dispose();
    confirmation.dispose();
  });
  return result == true;
}
