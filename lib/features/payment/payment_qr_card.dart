import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/flow_widgets.dart';
import '../../core/formatting/display_formatters.dart';
import '../../core/models/agreement.dart';
import 'payment_details.dart';
import 'payment_qr_actions.dart';

class PaymentQrCard extends StatefulWidget {
  const PaymentQrCard({
    required this.draft,
    this.footer,
    this.actions = const PaymentQrActions(),
    super.key,
  });
  final AgreementDraft draft;
  final Widget? footer;
  final PaymentQrActions actions;
  @override
  State<PaymentQrCard> createState() => _PaymentQrCardState();
}

class _PaymentQrCardState extends State<PaymentQrCard> {
  PaymentDetails? details;
  Uint8List? png;
  var generation = 0;
  var imageFailed = false;
  var busy = false;
  String message = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant PaymentQrCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft != widget.draft ||
        oldWidget.actions != widget.actions) {
      load();
    }
  }

  void load() {
    generation++;
    details = null;
    png = null;
    busy = false;
    imageFailed = false;
    message = '';
    try {
      details = PaymentDetails.fromDraft(widget.draft);
    } on FormatException {
      return;
    } on ArgumentError {
      return;
    }
    prepareImage(generation);
  }

  Future<void> prepareImage(int expected) async {
    try {
      final image = await widget.actions.render(details!.payload);
      if (!mounted || expected != generation) return;
      setState(() => png = image);
    } catch (_) {
      if (!mounted || expected != generation) return;
      setState(() => imageFailed = true);
    }
  }

  Future<void> copy(String value) async {
    final expected = generation;
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (mounted && expected == generation) {
        setState(
          () => message = 'Đã sao chép. Kiểm tra lại trong app ngân hàng.',
        );
      }
    } catch (_) {
      if (mounted && expected == generation) {
        setState(
          () => message = 'Không sao chép được. Bạn có thể chọn và sao chép phần thông tin bên dưới.',
        );
      }
    }
  }

  Future<void> imageAction({required bool share, Rect? origin}) async {
    final expected = generation;
    final data = png;
    final payment = details;
    if (busy || data == null || payment == null) return;
    setState(() {
      busy = true;
      message = '';
    });
    final fileBase =
        'civiltrust-vietqr-${PaymentDetails.purposeFor(widget.draft.id).split(' ').last}';
    try {
      // No image generation/network await before invoking the share API.
      if (share) {
        final outcome = await widget.actions.share(data, fileBase, origin!);
        if (mounted && expected == generation) {
          setState(
            () => message = switch (outcome) {
              QrShareOutcome.completed =>
                'Thao tác chia sẻ ảnh đã hoàn tất; chưa xác nhận chuyển tiền.',
              QrShareOutcome.dismissed => 'Đã hủy chia sẻ ảnh.',
              QrShareOutcome.unknown => 'Đã yêu cầu chia sẻ ảnh. Kiểm tra thao tác trên thiết bị; chưa xác nhận chuyển tiền.',
            },
          );
        }
      } else {
        await widget.actions.save(data, fileBase);
        if (mounted && expected == generation) {
          setState(
            () => message =
                'Đã yêu cầu tải ảnh QR. Kiểm tra Tệp/Tải về trên thiết bị.',
          );
        }
      }
    } catch (_) {
      if (mounted && expected == generation) {
        setState(
          () => message = share
              ? 'Thiết bị chưa chia sẻ được ảnh. Hãy dùng Tải ảnh QR hoặc sao chép thông tin.'
              : 'Chưa tải được ảnh. Hãy thử chia sẻ ảnh hoặc sao chép thông tin.',
        );
      }
    } finally {
      if (mounted && expected == generation) setState(() => busy = false);
    }
  }

  Widget detail(String label, String display, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              SelectableText(display),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Sao chép $label',
          onPressed: () => copy(value),
          icon: const Icon(Icons.copy, size: 20),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final payment = details;
    if (payment == null) {
      return const TrustNotice(
        title: 'Chưa tạo được VietQR cho hồ sơ này',
        message:
            'Thông tin chuyển khoản thiếu, sai định dạng hoặc thuộc phiên bản chưa hỗ trợ. '
            'Không sửa hồ sơ đã ký để ép tạo QR; hãy kiểm tra và tạo phiên mới.',
      );
    }
    return SectionCard(
      title: 'Chuyển khoản cho Bên A',
      icon: Icons.account_balance,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (png != null)
            Center(
              child: Image.memory(
                png!,
                width: 240,
                height: 240,
                filterQuality: FilterQuality.none,
                semanticLabel: 'VietQR chuyển cho Bên A',
              ),
            )
          else if (imageFailed)
            TextButton(
              onPressed: () {
                setState(() => imageFailed = false);
                prepareImage(generation);
              },
              child: const Text('Thử tạo lại ảnh QR'),
            )
          else
            const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
          detail('BIN ngân hàng', payment.bankBin, payment.bankBin),
          detail('Số tài khoản', payment.accountNumber, payment.accountNumber),
          detail(
            'Tên do Bên A cung cấp',
            payment.accountName,
            payment.accountName,
          ),
          detail(
            'Số tiền',
            DisplayFormatters.vnd(payment.amount),
            payment.amount.toString(),
          ),
          detail('Nội dung chuyển khoản', payment.purpose, payment.purpose),
          if (payment.legacyReference)
            const Text(
              'Hồ sơ cũ: giữ nội dung chuyển khoản đã dùng. Nội dung này có thể trùng với hồ sơ khác; kiểm tra cả tài khoản và số tiền.',
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: busy || png == null
                    ? null
                    : () => imageAction(share: false),
                icon: const Icon(Icons.download),
                label: const Text('Tải ảnh QR'),
              ),
              Builder(
                builder: (buttonContext) => OutlinedButton.icon(
                  onPressed: busy || png == null
                      ? null
                      : () {
                          final box =
                              buttonContext.findRenderObject() as RenderBox;
                          imageAction(
                            share: true,
                            origin: box.localToGlobal(Offset.zero) & box.size,
                          );
                        },
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Chia sẻ ảnh QR'),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => copy(payment.copyText),
                icon: const Icon(Icons.copy),
                label: const Text('Sao chép thông tin'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Dùng một điện thoại: lưu/chia sẻ ảnh, rồi chọn ảnh QR trong app ngân hàng nếu được hỗ trợ. '
            'Nếu không, sao chép thông tin và nhập tay. Đối chiếu tên người nhận do ngân hàng hiển thị, tài khoản, số tiền và nội dung trước khi xác nhận. '
            'CivilTrust chưa xác minh chủ tài khoản và không tự kiểm tra tiền đã đến. Hạn mức tùy ngân hàng.',
          ),
          if (message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(liveRegion: true, child: Text(message)),
            ),
          if (widget.footer != null) ...[
            const SizedBox(height: 16),
            widget.footer!,
          ],
        ],
      ),
    );
  }
}
