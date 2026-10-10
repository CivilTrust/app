import 'package:flutter/material.dart';

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
        Text(
          title,
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
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
                        : const Color(0xffdce5e2),
                    foregroundColor: i <= current
                        ? Colors.white
                        : Colors.black54,
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
                    : const Color(0xffdce5e2),
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
        color: const Color(0xfffffbeb),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xfffcd34d)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xfffef3c7),
            child: Icon(Icons.person_outline, color: Color(0xff92400e)),
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
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 17,
                      color: Color(0xff92400e),
                    ),
                    SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'DỮ LIỆU MÔ PHỎNG — CHƯA XÁC THỰC CHIP CCCD',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xff92400e),
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
  const TrustNotice({required this.title, required this.message, super.key});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xfffffbeb),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xfffcd34d)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, color: Color(0xff92400e)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(message),
            ],
          ),
        ),
      ],
    ),
  );
}
