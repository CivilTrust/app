import 'dart:typed_data';

import 'package:civiltrust_app/features/payment/payment_qr_actions.dart';
import 'package:civiltrust_app/features/payment/payment_qr_card.dart';
import 'package:civiltrust_app/features/payment/vietqr_preview_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

class PreviewActions extends PaymentQrActions {
  @override
  Future<Uint8List> render(String payload) async => Uint8List.fromList(
    image.encodePng(
      image.fill(
        image.Image(width: 2, height: 2, numChannels: 4),
        color: image.ColorRgba8(255, 255, 255, 255),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'local preview validates input and clears old QR when recipient changes',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: VietQrPreviewPage(actions: PreviewActions())),
      );
      Future<void> fill(String label, String value) async {
        final input = find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.labelText == label,
        );
        await tester.ensureVisible(input);
        await tester.enterText(input, value);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
      }

      await fill('Tài khoản thử nghiệm', 'A' * 20);
      await fill('Tên người nhận do bạn cung cấp', 'TEST RECEIVER');
      await tester.ensureVisible(find.text('Tạo QR để xem trước'));
      await tester.tap(find.text('Tạo QR để xem trước'));
      await tester.pumpAndSettle();
      expect(
        find.text('Số tài khoản gồm 4–19 ký tự chữ hoặc số'),
        findsOneWidget,
      );
      expect(find.byType(PaymentQrCard), findsNothing);
      await fill('Tài khoản thử nghiệm', '000000000001');
      await tester.ensureVisible(find.text('Tạo QR để xem trước'));
      await tester.tap(find.text('Tạo QR để xem trước'));
      await tester.pumpAndSettle();
      expect(find.byType(PaymentQrCard), findsOneWidget);
      expect(
        tester
            .widget<PaymentQrCard>(find.byType(PaymentQrCard))
            .draft
            .amountVnd,
        1000,
      );
      expect(find.text('Tôi đã thực hiện chuyển khoản'), findsNothing);
      await fill('Tài khoản thử nghiệm', '000000000002');
      expect(find.byType(PaymentQrCard), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
