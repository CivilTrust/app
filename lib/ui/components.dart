import 'package:flutter/material.dart';

import '../core/formatting/display_formatters.dart';
import 'app_theme.dart';

/// Small coloured label for a record state.
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {required this.tone, super.key});
  final String label;
  final AppTone tone;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: tone.background,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: tone.border),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: tone.foreground,
      ),
    ),
  );
}

/// Centered placeholder for empty lists.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    super.key,
  });
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
    child: Column(
      children: [
        Icon(icon, size: 44, color: AppColors.inkMuted),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (message != null) ...[
          const SizedBox(height: 6),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.inkMuted),
          ),
        ],
        if (action != null) ...[const SizedBox(height: 14), action!],
      ],
    ),
  );
}

/// One entry of a vertical progress timeline.
class TimelineEntry {
  const TimelineEntry(
    this.label, {
    this.done = false,
    this.current = false,
    this.at,
  });
  final String label;
  final bool done;
  final bool current;
  final DateTime? at;
}

class ProgressTimeline extends StatelessWidget {
  const ProgressTimeline({required this.entries, super.key});
  final List<TimelineEntry> entries;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < entries.length; i++)
        _TimelineRow(entry: entries[i], last: i == entries.length - 1),
    ],
  );
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry, required this.last});
  final TimelineEntry entry;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = entry.done
        ? AppTone.success.foreground
        : entry.current
        ? AppColors.primary
        : AppColors.border;
    final state = entry.done
        ? 'đã xong'
        : entry.current
        ? 'đang chờ'
        : 'chưa tới';
    return Semantics(
      label: '${entry.label}, $state',
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 28,
              child: Column(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: entry.done ? color : Colors.white,
                      border: Border.all(color: color, width: 2),
                    ),
                    child: entry.done
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : entry.current
                        ? Center(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color,
                              ),
                            ),
                          )
                        : null,
                  ),
                  if (!last)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: entry.done
                            ? AppTone.success.border
                            : AppColors.border,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: last ? 0 : 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.label,
                      style: TextStyle(
                        fontWeight: entry.current
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: entry.done || entry.current
                            ? AppColors.ink
                            : AppColors.inkMuted,
                      ),
                    ),
                    if (entry.at != null)
                      Text(
                        DisplayFormatters.dateTime(entry.at!),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.inkMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Confirmation before an action that cannot be undone. Bottom sheet on
/// phones, dialog on wider screens. Returns true only on explicit confirm.
Future<bool> confirmIrreversible(
  BuildContext context, {
  required String title,
  required List<String> points,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final body = Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final point in points)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  '),
              Expanded(child: Text(point)),
            ],
          ),
        ),
      const SizedBox(height: 4),
      Text(
        'Thao tác này không thể hoàn tác.',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppTone.warning.foreground,
        ),
      ),
    ],
  );
  List<Widget> buttons(BuildContext ctx) => [
    OutlinedButton(
      onPressed: () => Navigator.pop(ctx, false),
      child: const Text('Quay lại xem'),
    ),
    FilledButton(
      style: destructive
          ? FilledButton.styleFrom(backgroundColor: AppTone.danger.foreground)
          : null,
      onPressed: () => Navigator.pop(ctx, true),
      child: Text(confirmLabel),
    ),
  ];
  final phone = MediaQuery.sizeOf(context).width < AppBreakpoints.rail;
  final result = phone
      ? await showModalBottomSheet<bool>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (ctx) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                body,
                const SizedBox(height: 16),
                for (final button in buttons(ctx).reversed) ...[
                  button,
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        )
      : await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: body,
            ),
            actions: buttons(ctx),
          ),
        );
  return result == true;
}
