import 'dart:ui';

import 'package:civiltrust_app/app/civiltrust_app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart' show ListView;

void main() {
  testWidgets('shows the CivilTrust template chooser', (tester) async {
    await tester.pumpWidget(const CivilTrustApp());

    expect(find.text('CivilTrust'), findsOneWidget);
    expect(find.text('Tạo hợp đồng mới'), findsOneWidget);
    expect(find.text('Hợp đồng đặt cọc'), findsOneWidget);
    expect(find.text('Hợp đồng vay tiền'), findsOneWidget);
    expect(find.text('Tạo hợp đồng'), findsOneWidget);
    expect(find.text('Tham gia ký'), findsOneWidget);
    expect(find.text('Kiểm chứng'), findsOneWidget);
  });

  testWidgets('create flow fits a phone-sized viewport', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CivilTrustApp());
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hợp đồng vay tiền'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
    await tester.pumpAndSettle();

    expect(find.text('Bước 2/6'), findsOneWidget);
    expect(find.text('Đang sử dụng dữ liệu mô phỏng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(768, 1024), Size(1280, 800)]) {
    testWidgets('template chooser fits ${size.width.toInt()}px viewport', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const CivilTrustApp());
      await tester.pumpAndSettle();

      expect(find.text('Tạo hợp đồng mới'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
