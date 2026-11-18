import 'package:civiltrust_app/app/civiltrust_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'editing reviewed payment terms requires fresh consent and snapshot',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const CivilTrustApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tạo mới'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      // Role selection and vault notice precede the template cards now.
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hợp đồng đặt cọc'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Quét CCCD mock của Bên A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quét CCCD mock của Bên A'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      Future<void> fill(String label, String value) async {
        final field = find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.labelText == label,
        );
        await tester.ensureVisible(field);
        await tester.enterText(field, value);
        await tester.pumpAndSettle();
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
      }

      await fill('Tài sản đặt cọc', 'Tài sản kiểm thử');
      await fill('Nơi giao nhận tài sản', 'Địa điểm kiểm thử');
      await fill('Tổng giá trị giao dịch', '2000000');
      await fill('Số tiền đặt cọc', '1000000');
      final date = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Hạn hoàn tất giao dịch',
      );
      await tester.ensureVisible(date);
      await tester.tap(date);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await fill('Số tài khoản nhận tiền', '000000000001');
      await tester.ensureVisible(find.text('Tiếp tục xem lại'));
      await tester.tap(find.text('Tiếp tục xem lại'));
      await tester.pumpAndSettle();
      final summary = find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText &&
            (widget.data?.contains('Nội dung:') ?? false),
      );
      final first = tester.widget<SelectableText>(summary).data!;
      expect(first, contains('Số tiền (VND): 1000000'));
      await tester.ensureVisible(find.byType(CheckboxListTile).first);
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile).first)
            .value,
        isTrue,
      );
      await tester.ensureVisible(find.text('Chỉnh sửa'));
      await tester.tap(find.text('Chỉnh sửa'));
      await tester.pumpAndSettle();
      await fill('Số tiền đặt cọc', '2000000');
      await tester.ensureVisible(find.text('Tiếp tục xem lại'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục xem lại'));
      await tester.pumpAndSettle();
      final second = tester.widget<SelectableText>(summary).data!;
      expect(second, contains('Số tiền (VND): 2000000'));
      expect(
        RegExp(r'CIVILTRUST [A-F0-9]{12}').firstMatch(first)!.group(0),
        isNot(RegExp(r'CIVILTRUST [A-F0-9]{12}').firstMatch(second)!.group(0)),
      );
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile).first)
            .value,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
