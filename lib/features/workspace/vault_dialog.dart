import 'package:flutter/material.dart';

import '../../app/flow_widgets.dart';
import '../../ui/app_theme.dart';
import 'agreement_vault.dart';

/// Rough strength hint for a vault password; not a security guarantee.
({String label, AppTone tone, double value}) vaultPasswordStrength(
  String password,
) {
  if (password.length < 12) {
    return (label: 'Cần ít nhất 12 ký tự', tone: AppTone.danger, value: 0.2);
  }
  var classes = 0;
  for (final pattern in [r'[a-z]', r'[A-Z]', r'\d', r'[^A-Za-z0-9]']) {
    if (RegExp(pattern).hasMatch(password)) classes++;
  }
  if (password.length >= 16 && classes >= 3) {
    return (label: 'Mạnh', tone: AppTone.success, value: 1);
  }
  if (classes >= 2) {
    return (
      label: 'Khá — nên dài hơn 16 ký tự',
      tone: AppTone.info,
      value: 0.65,
    );
  }
  return (
    label: 'Yếu — thêm chữ hoa, số hoặc ký hiệu',
    tone: AppTone.warning,
    value: 0.4,
  );
}

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
  var busy = false;
  var obscure = true;
  var understood = exists;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final strength = vaultPasswordStrength(controller.text);
        Future<void> submit() async {
          if (!exists && controller.text != confirmation.text) {
            setState(() => error = 'Mật khẩu nhập lại không khớp.');
            return;
          }
          setState(() {
            busy = true;
            error = null;
          });
          try {
            await vault.unlock(controller.text);
            if (dialogContext.mounted) Navigator.pop(dialogContext, true);
          } catch (e) {
            if (dialogContext.mounted) {
              setState(() {
                error = exists
                    ? 'Không mở được kho. Kiểm tra lại mật khẩu.'
                    : friendlyError(e);
                busy = false;
              });
            }
          }
        }

        final canSubmit =
            !busy &&
            controller.text.length >= 12 &&
            (exists || (understood && confirmation.text.isNotEmpty));
        return AlertDialog(
          icon: Icon(
            exists ? Icons.lock_outline : Icons.shield_outlined,
            color: AppColors.primary,
          ),
          title: Text(exists ? 'Mở kho hợp đồng' : 'Tạo kho hợp đồng mã hóa'),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    exists
                        ? 'Nhập mật khẩu kho trên thiết bị này để xem và tiếp tục hợp đồng.'
                        : 'Kho lưu bản nháp, quyền truy cập phiên ký và gói bằng chứng '
                              'trên thiết bị này, được mã hóa bằng mật khẩu của bạn.',
                  ),
                  if (!exists) ...[
                    const SizedBox(height: 10),
                    for (final line in const [
                      'Mật khẩu từ 12 ký tự; không dùng số căn cước, ngày sinh.',
                      'Không có chức năng quên mật khẩu.',
                      'Sau khi tạo, vào mục Hồ sơ, chọn Xuất gói khôi phục và cất ở nơi an toàn.',
                      'Không gửi gói khôi phục cho bên kia của hợp đồng.',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('•  '),
                            Expanded(child: Text(line)),
                          ],
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    obscureText: obscure,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofocus: true,
                    autofillHints: [
                      exists
                          ? AutofillHints.password
                          : AutofillHints.newPassword,
                    ],
                    onChanged: (_) => setState(() => error = null),
                    onSubmitted: (_) => canSubmit ? submit() : null,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu kho',
                      suffixIcon: IconButton(
                        tooltip: obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                        icon: Icon(
                          obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () => setState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  if (!exists) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: strength.value,
                      color: strength.tone.foreground,
                      backgroundColor: AppColors.border,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Độ mạnh: ${strength.label}',
                      style: TextStyle(
                        fontSize: 13,
                        color: strength.tone.foreground,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmation,
                      obscureText: obscure,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const [AutofillHints.newPassword],
                      onChanged: (_) => setState(() => error = null),
                      decoration: const InputDecoration(
                        labelText: 'Nhập lại mật khẩu',
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: understood,
                      onChanged: busy
                          ? null
                          : (v) => setState(() => understood = v ?? false),
                      title: const Text(
                        'Tôi hiểu mật khẩu không thể khôi phục nếu quên.',
                      ),
                    ),
                  ],
                  if (busy) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                  ],
                  if (error != null)
                    StatusMessage(error!, tone: AppTone.danger),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: canSubmit ? submit : null,
              child: Text(exists ? 'Mở kho' : 'Tạo kho'),
            ),
          ],
        );
      },
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
