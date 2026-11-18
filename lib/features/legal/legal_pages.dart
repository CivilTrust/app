import 'package:flutter/material.dart';

import '../../app/flow_widgets.dart';
import '../../ui/app_theme.dart';
import 'legal_content.dart';

/// Opens a legal document or the FAQ as a full page.
Future<void> openLegalPage(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

class _ReadableColumn extends StatelessWidget {
  const _ReadableColumn({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: children,
      ),
    ),
  );
}

class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({required this.document, super.key});
  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(document.title)),
      body: SelectionArea(
        child: _ReadableColumn(
          children: [
            Text(document.title, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              document.version,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: 16),
            const TrustNotice(
              tone: AppTone.warning,
              title: 'Bản dự thảo',
              message: LegalInfo.draftNotice,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(document.summary, style: theme.textTheme.bodyLarge),
              ),
            ),
            for (final section in document.sections) ...[
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(section.heading, style: theme.textTheme.titleLarge),
              ),
              for (final paragraph in section.paragraphs)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(paragraph, style: theme.textTheme.bodyLarge),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Câu hỏi thường gặp')),
    body: _ReadableColumn(
      children: [
        Text(
          'Câu hỏi thường gặp',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        const FaqList(),
      ],
    ),
  );
}

/// Expandable question list, reused on the home page.
class FaqList extends StatelessWidget {
  const FaqList({this.limit, super.key});
  final int? limit;

  @override
  Widget build(BuildContext context) {
    final items = limit == null ? faqItems : faqItems.take(limit!).toList();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(
                items[i].question,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(items[i].answer)],
            ),
          ],
        ],
      ),
    );
  }
}

/// Footer links shared by the home page and consent notices.
class LegalLinks extends StatelessWidget {
  const LegalLinks({this.alignment = WrapAlignment.center, super.key});
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: alignment,
    spacing: 4,
    children: [
      TextButton(
        onPressed: () => openLegalPage(
          context,
          const LegalDocumentPage(document: termsOfUse),
        ),
        child: const Text('Điều khoản sử dụng'),
      ),
      TextButton(
        onPressed: () => openLegalPage(
          context,
          const LegalDocumentPage(document: privacyPolicy),
        ),
        child: const Text('Chính sách quyền riêng tư'),
      ),
      TextButton(
        onPressed: () => openLegalPage(context, const FaqPage()),
        child: const Text('Câu hỏi thường gặp'),
      ),
    ],
  );
}

/// Personal-data processing notice shown before reading identity data
/// (Luật Bảo vệ dữ liệu cá nhân 2025: inform before consent).
class IdentityDataNotice extends StatelessWidget {
  const IdentityDataNotice({required this.mock, super.key});
  final bool mock;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTone.info.background,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTone.info.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.privacy_tip_outlined, color: AppTone.info.foreground),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Thông báo xử lý dữ liệu cá nhân',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTone.info.foreground,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final line in [
          'Dữ liệu: họ tên, ngày sinh, số căn cước, ngày/nơi cấp, địa chỉ'
              '${mock ? ' (bản thử nghiệm dùng dữ liệu mô phỏng)' : ''}.',
          'Mục đích: ghi đúng thông tin các bên vào hợp đồng và kiểm tra đủ '
              '18 tuổi.',
          'Ai thấy: bạn và bên còn lại của hợp đồng. Máy chủ chỉ giữ bản mã '
              'hóa, tự xóa sau 7 ngày nếu chưa hoàn tất hoặc 30 ngày sau khi '
              'hoàn tất.',
          'Bạn có thể không đồng ý; khi đó chưa thể ký hợp đồng.',
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
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () => openLegalPage(
              context,
              const LegalDocumentPage(document: privacyPolicy),
            ),
            child: const Text('Đọc Chính sách quyền riêng tư'),
          ),
        ),
      ],
    ),
  );
}
