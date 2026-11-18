import 'package:flutter/material.dart';

import '../ui/app_theme.dart';

class FlowHeader extends StatelessWidget {
  const FlowHeader({required this.title, required this.subtitle, super.key});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: AppColors.inkMuted),
        ),
      ],
    ),
  );
}

class FlowProgress extends StatelessWidget {
  const FlowProgress({required this.current, required this.labels, super.key});
  final int current;
  final List<String> labels;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 620) {
        final safeCurrent = current.clamp(0, labels.length - 1);
        return Semantics(
          label:
              'Bước ${safeCurrent + 1} trên ${labels.length}: ${labels[safeCurrent]}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Bước ${safeCurrent + 1}/${labels.length}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(labels[safeCurrent]),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (safeCurrent + 1) / labels.length,
                minHeight: 7,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          ),
        );
      }
      return Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            Expanded(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: i <= current
                        ? Theme.of(context).colorScheme.primary
                        : AppColors.border,
                    foregroundColor: i <= current
                        ? Colors.white
                        : AppColors.inkMuted,
                    child: i < current
                        ? const Icon(Icons.check, size: 17)
                        : Text(
                            '${i + 1}',
                            style: const TextStyle(fontSize: 12),
                          ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: i == current
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (i < labels.length - 1)
              Container(
                width: constraints.maxWidth > 650 ? 35 : 10,
                height: 2,
                color: i < current
                    ? Theme.of(context).colorScheme.primary
                    : AppColors.border,
              ),
          ],
        ],
      );
    },
  );
}

class SectionCard extends StatelessWidget {
  const SectionCard({required this.child, this.title, this.icon, super.key});
  final Widget child;
  final String? title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null)
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                if (icon != null) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    ),
  );
}

class IdentitySummary extends StatelessWidget {
  const IdentitySummary({
    required this.identity,
    required this.role,
    super.key,
  });
  final Map<String, dynamic> identity;
  final String role;

  @override
  Widget build(BuildContext context) {
    final attributes = Map<String, dynamic>.from(
      identity['attributes'] as Map? ?? {},
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTone.mock.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTone.mock.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppTone.mock.border,
            child: Icon(Icons.person_outline, color: AppTone.mock.foreground),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$role · ${attributes['fullName'] ?? identity['displayName'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'CCCD: ${attributes['documentNumber'] ?? identity['documentNumberMasked'] ?? ''}',
                ),
                Text('Ngày sinh: ${attributes['dateOfBirth'] ?? ''}'),
                Text('Địa chỉ: ${attributes['permanentAddress'] ?? ''}'),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      AppTone.mock.icon,
                      size: 17,
                      color: AppTone.mock.foreground,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'DỮ LIỆU MÔ PHỎNG — CHƯA XÁC THỰC CHIP CCCD',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTone.mock.foreground,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TrustNotice extends StatelessWidget {
  const TrustNotice({
    required this.title,
    required this.message,
    this.tone = AppTone.warning,
    super.key,
  });

  final String title;
  final String message;
  final AppTone tone;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: title,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(tone.icon, color: tone.foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: tone.foreground,
                  ),
                ),
                const SizedBox(height: 3),
                Text(message, style: const TextStyle(color: AppColors.ink)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Removes Dart exception prefixes so users never see "Bad state:" etc.
String friendlyError(Object error) {
  var text = error.toString();
  for (final prefix in const [
    'Bad state: ',
    'FormatException: ',
    'Exception: ',
    'Invalid argument(s): ',
  ]) {
    if (text.startsWith(prefix)) text = text.substring(prefix.length);
  }
  return text.trim().isEmpty ? 'Đã xảy ra lỗi không xác định.' : text.trim();
}

/// Inline status line used by multi-step flows. Errors are announced to
/// assistive technology as live regions.
class StatusMessage extends StatelessWidget {
  const StatusMessage(this.message, {this.tone = AppTone.success, super.key});
  final String message;
  final AppTone tone;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tone.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(tone.icon, size: 20, color: tone.foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: tone.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
