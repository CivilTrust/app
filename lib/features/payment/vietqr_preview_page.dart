import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/flow_widgets.dart';
import '../../core/ids/agreement_id.dart';
import '../../core/models/agreement.dart';
import '../agreements/agreement_validator.dart';
import 'payment_details.dart';
import 'payment_qr_card.dart';
import 'payment_qr_actions.dart';
import 'vietqr_service.dart';

/// Local-only device acceptance tool. No session, storage or network client.
/// Controllers are disposed on exit; PNG export/share is an explicit action.
class VietQrPreviewPage extends StatefulWidget {
  const VietQrPreviewPage({this.actions = const PaymentQrActions(), super.key});
  final PaymentQrActions actions;
  @override
  State<VietQrPreviewPage> createState() => _VietQrPreviewPageState();
}

class _VietQrPreviewPageState extends State<VietQrPreviewPage> {
  final form = GlobalKey<FormState>();
  final bank = TextEditingController(text: '970436');
  final account = TextEditingController();
  final name = TextEditingController();
  final amount = TextEditingController(text: '1000');
  AgreementDraft? preview;
  @override
  void dispose() {
    for (final controller in [bank, account, name, amount]) {
      controller.dispose();
    }
    super.dispose();
  }

  void generate() {
    if (!(form.currentState?.validate() ?? false)) return;
    final id = createAgreementId();
    setState(
      () => preview = AgreementDraft(
        id: id,
        title: 'QR thử cục bộ',
        terms: 'Không phải hợp đồng; không có chữ ký hoặc xác nhận thanh toán.',
        createdAt: DateTime.now().toUtc(),
        amountVnd: int.parse(amount.text.trim()),
        fields: Map.unmodifiable({
          'bankBin': bank.text.trim(),
          'accountNumber': account.text.trim(),
          'accountName': name.text.trim(),
          'paymentQrProfile': PaymentDetails.profile,
          'paymentPurpose': PaymentDetails.purposeFor(id),
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Thử VietQR cục bộ')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const TrustNotice(
          title: 'Chỉ thử màn xem trước ngân hàng',
          message:
              'Thông tin nhập ở đây chỉ ở trong trang này; không tạo phiên hoặc gửi tới coordinator/notary. '
              'Chỉ dùng tài khoản bạn kiểm soát. Quét/nhập ảnh để đối chiếu tên người nhận, số tiền và nội dung, rồi dừng trước bước chuyển tiền. '
              'Không chụp hoặc gửi số tài khoản thật vào báo cáo. Tải/chia sẻ ảnh là thao tác riêng do bạn chọn.',
        ),
        const SizedBox(height: 16),
        Form(
          key: form,
          onChanged: () {
            if (preview != null) setState(() => preview = null);
          },
          child: Column(
            children: [
              TextFormField(
                controller: bank,
                decoration: const InputDecoration(
                  labelText: 'BIN ngân hàng nhận',
                ),
                validator: const AgreementValidator().validateBankBin,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: account,
                decoration: const InputDecoration(
                  labelText: 'Tài khoản thử nghiệm',
                ),
                validator: const AgreementValidator().validateAccountNumber,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Tên người nhận do bạn cung cấp',
                ),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? 'Không được để trống'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: amount,
                decoration: const InputDecoration(
                  labelText: 'Số tiền thử (VND)',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  final parsed = int.tryParse(value?.trim() ?? '');
                  return parsed == null ||
                          parsed <= 0 ||
                          parsed > VietQrService.maxAmount
                      ? 'Nhập số tiền dương, không quá 13 chữ số'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: generate,
                child: const Text('Tạo QR để xem trước'),
              ),
            ],
          ),
        ),
        if (preview != null) ...[
          const SizedBox(height: 16),
          PaymentQrCard(draft: preview!, actions: widget.actions),
        ],
      ],
    ),
  );
}
