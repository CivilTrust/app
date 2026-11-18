import 'package:flutter/material.dart';

import '../../ui/app_theme.dart';
import '../legal/legal_content.dart';
import '../legal/legal_pages.dart';

/// Landing page: explains the product, sets honest expectations and routes
/// to the main tasks. Contains no session data.
class HomePage extends StatelessWidget {
  const HomePage({
    required this.onCreate,
    required this.onJoin,
    required this.onRecords,
    required this.onVerify,
    this.mockIdentity = true,
    super.key,
  });

  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final VoidCallback onRecords;
  final VoidCallback onVerify;
  final bool mockIdentity;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 760;
      final pad = wide ? 32.0 : 20.0;
      return ListView(
        padding: EdgeInsets.fromLTRB(pad, 20, pad, 32),
        children: [
          _Hero(
            // Two-column hero only when there is room; otherwise the call to
            // action would fall below the fold on short landscape screens.
            wide: constraints.maxWidth >= 1000,
            onCreate: onCreate,
            onJoin: onJoin,
            onRecords: onRecords,
          ),
          if (mockIdentity) ...[
            const SizedBox(height: 20),
            _Banner(
              tone: AppTone.mock,
              title: 'Bản thử nghiệm',
              message:
                  'Danh tính và chữ ký đang dùng dữ liệu mô phỏng. Không nhập '
                  'căn cước, tài khoản ngân hàng thật và không dùng cho giao '
                  'dịch thật.',
            ),
          ],
          const SizedBox(height: 36),
          const _SectionTitle(
            'Cách hoạt động',
            'Bốn bước, mỗi bên dùng thiết bị của riêng mình.',
          ),
          const SizedBox(height: 16),
          _Grid(
            wide: wide,
            children: const [
              _Step(
                1,
                Icons.edit_note_rounded,
                'Soạn và khóa nội dung',
                'Chọn mẫu đặt cọc hoặc vay tiền, điền điều khoản. Nội dung được '
                    'khóa trước khi ký để không ai sửa được.',
              ),
              _Step(
                2,
                Icons.draw_outlined,
                'Hai bên ký từ xa',
                'Gửi link mời riêng. Bên kia mở trên điện thoại, đọc toàn văn, '
                    'xác minh danh tính và ký.',
              ),
              _Step(
                3,
                Icons.qr_code_2_rounded,
                'Chuyển khoản VietQR',
                'Bên chuyển quét mã bằng app ngân hàng. Bên nhận tự kiểm tra tài '
                    'khoản rồi xác nhận đã nhận.',
              ),
              _Step(
                4,
                Icons.inventory_2_outlined,
                'Nhận gói bằng chứng',
                'Hai bên tải cùng một gói: hợp đồng PDF và tệp kiểm chứng chữ '
                    'ký, thời điểm.',
              ),
            ],
          ),
          const SizedBox(height: 36),
          const _SectionTitle(
            'Vì sao có thể tin cậy',
            'Thiết kế để bạn không phải tin máy chủ.',
          ),
          const SizedBox(height: 16),
          _Grid(
            wide: wide,
            children: const [
              _Feature(
                Icons.lock_outline_rounded,
                'Mã hóa trên thiết bị',
                'Hợp đồng được mã hóa trước khi gửi đi. Máy chủ chỉ chuyển '
                    'bản mã hóa mà nó không đọc được.',
              ),
              _Feature(
                Icons.fingerprint_rounded,
                'Chỉ gửi đi mã băm',
                'Dịch vụ ghi nhận thời điểm chỉ nhận mã băm của tệp PDF, không '
                    'nhận nội dung hay thông tin cá nhân.',
              ),
              _Feature(
                Icons.verified_outlined,
                'Ai cũng kiểm chứng được',
                'Mở mục Kiểm chứng, chọn tệp ZIP: chữ ký và mã băm được kiểm '
                    'ngay trên trình duyệt.',
              ),
              _Feature(
                Icons.gavel_rounded,
                'Trung thực về giới hạn',
                'Không phải công chứng. Ứng dụng ghi rõ điều gì đã được kiểm, '
                    'điều gì do các bên tự khai.',
              ),
            ],
          ),
          const SizedBox(height: 36),
          const _SectionTitle('Mẫu hợp đồng hỗ trợ', null),
          const SizedBox(height: 16),
          _Grid(
            wide: wide,
            children: [
              _TemplateTeaser(
                icon: Icons.handshake_outlined,
                title: 'Mẫu đặt cọc',
                text:
                    'Thuê nhà, mua xe, mua tài sản. Phạt cọc theo Điều 328 Bộ '
                    'luật Dân sự 2015.',
                onTap: onCreate,
              ),
              _TemplateTeaser(
                icon: Icons.payments_outlined,
                title: 'Mẫu vay tiền',
                text:
                    'Ghi rõ số tiền, ngày giải ngân, hạn trả. Lãi suất không quá '
                    '20%/năm.',
                onTap: onCreate,
              ),
            ],
          ),
          const SizedBox(height: 36),
          const _SectionTitle('Câu hỏi thường gặp', null),
          const SizedBox(height: 16),
          const FaqList(limit: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => openLegalPage(context, const FaqPage()),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Xem tất cả câu hỏi'),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onVerify,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Kiểm chứng một gói hợp đồng'),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 8),
          const LegalLinks(),
          const SizedBox(height: 4),
          Text(
            'CivilTrust · ${LegalInfo.controllerName} · ${LegalInfo.version}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.inkMuted),
          ),
        ],
      );
    },
  );
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.wide,
    required this.onCreate,
    required this.onJoin,
    required this.onRecords,
  });
  final bool wide;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final VoidCallback onRecords;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'Hợp đồng điện tử có thể kiểm chứng',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
        const SizedBox(height: 14),
        Semantics(
          header: true,
          child: Text(
            'Ký hợp đồng đặt cọc, vay tiền từ xa — có bằng chứng rõ ràng',
            style: TextStyle(
              color: Colors.white,
              fontSize: wide ? 34 : 26,
              height: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Hai bên cùng đọc, cùng ký trên một nội dung đã khóa, chuyển khoản '
          'bằng VietQR và nhận cùng một gói bằng chứng.',
          style: TextStyle(color: Colors.white, fontSize: 16, height: 1.45),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
              ),
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Tạo hợp đồng'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
                minimumSize: const Size(0, 50),
              ),
              onPressed: onJoin,
              icon: const Icon(Icons.link),
              label: const Text('Tôi được mời ký'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          onPressed: onRecords,
          icon: const Icon(Icons.folder_open_outlined),
          label: const Text('Mở hồ sơ đã lưu'),
        ),
      ],
    );
    return Container(
      padding: EdgeInsets.all(wide ? 36 : 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xff1e40af), AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: wide
          ? Row(
              children: [
                Expanded(flex: 3, child: text),
                const SizedBox(width: 24),
                const Expanded(flex: 2, child: _HeroArt()),
              ],
            )
          : text,
    );
  }
}

/// Decorative contract card; excluded from the accessibility tree.
class _HeroArt extends StatelessWidget {
  const _HeroArt();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'HỢP ĐỒNG ĐẶT CỌC',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          const SizedBox(height: 10),
          for (final width in const [1.0, 0.85, 0.92, 0.6])
            FractionallySizedBox(
              widthFactor: width,
              child: Container(
                height: 8,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          const SizedBox(height: 8),
          for (final party in const ['Bên A đã ký', 'Bên B đã ký'])
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 18,
                    color: AppTone.success.foreground,
                  ),
                  const SizedBox(width: 6),
                  Text(party),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.subtitle);
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 4),
        Text(subtitle!, style: const TextStyle(color: AppColors.inkMuted)),
      ],
    ],
  );
}

/// Two columns on wide screens, one on phones.
class _Grid extends StatelessWidget {
  const _Grid({required this.wide, required this.children});
  final bool wide;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return Column(
        children: [
          for (final child in children) ...[child, const SizedBox(height: 12)],
        ],
      );
    }
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: children[i]),
              const SizedBox(width: 12),
              Expanded(
                child: i + 1 < children.length
                    ? children[i + 1]
                    : const SizedBox(),
              ),
            ],
          ),
        ),
      );
      rows.add(const SizedBox(height: 12));
    }
    return Column(children: rows);
  }
}

class _Step extends StatelessWidget {
  const _Step(this.number, this.icon, this.title, this.text);
  final int number;
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primaryContainer,
            foregroundColor: AppColors.primary,
            child: Text(
              '$number',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: AppColors.accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(text),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Feature extends StatelessWidget {
  const _Feature(this.icon, this.title, this.text);
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 28),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(text),
        ],
      ),
    ),
  );
}

class _TemplateTeaser extends StatelessWidget {
  const _TemplateTeaser({
    required this.icon,
    required this.title,
    required this.text,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(text),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.tone,
    required this.title,
    required this.message,
  });
  final AppTone tone;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
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
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$title. ',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: tone.foreground,
                  ),
                ),
                TextSpan(text: message),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
