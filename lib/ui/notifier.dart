import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Single entry point for transient feedback so every screen uses the same
/// colours, icons, duration and close affordance.
void showAppToast(
  BuildContext context,
  String message, {
  AppTone tone = AppTone.success,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: tone == AppTone.danger
            ? tone.foreground
            : AppColors.ink,
        duration: Duration(seconds: tone == AppTone.danger ? 6 : 4),
        showCloseIcon: true,
        content: Row(
          children: [
            Icon(
              tone.icon,
              color: tone == AppTone.danger ? Colors.white : tone.border,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: onAction,
              ),
      ),
    );
}
