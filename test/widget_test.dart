import 'dart:ui';

import 'package:civiltrust_app/app/civiltrust_app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart' show BackButton, ListView, Scrollable;

void main() {
  testWidgets('opens on the home page with honest demo notice', (tester) async {
    await tester.pumpWidget(const CivilTrustApp());
    await tester.pumpAndSettle();
    expect(find.text('Tạo hợp đồng'), findsOneWidget);
    expect(find.text('Tôi được mời ký'), findsOneWidget);
    expect(find.text('Trang chủ'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('dữ liệu mô phỏng', findRichText: true),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.text('Câu hỏi thường gặp'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.text('Chính sách quyền riêng tư'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Chính sách quyền riêng tư'));
    await tester.pumpAndSettle();
    expect(find.text('Bản dự thảo'), findsOneWidget);
    expect(find.textContaining('91/2025/QH15'), findsWidgets);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, 3000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tôi được mời ký'));
    await tester.pumpAndSettle();
    expect(find.text('Bên B tham gia ký'), findsOneWidget);
  });

  testWidgets('shows the CivilTrust template chooser', (tester) async {
    await tester.pumpWidget(const CivilTrustApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo mới'));
    await tester.pumpAndSettle();

    expect(find.text('CivilTrust'), findsOneWidget);
    expect(find.text('Tạo hợp đồng mới'), findsOneWidget);
    expect(find.text('Hợp đồng đặt cọc'), findsOneWidget);
    expect(find.text('Hợp đồng vay tiền'), findsOneWidget);
    expect(find.text('Tạo mới'), findsOneWidget);
    expect(find.text('Tham gia'), findsOneWidget);
    expect(find.text('Kiểm chứng'), findsOneWidget);
  });

  testWidgets('create flow fits a phone-sized viewport', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CivilTrustApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo mới'));
    await tester.pumpAndSettle();
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
      await tester.tap(find.text('Tạo mới'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      expect(find.text('Tạo hợp đồng mới'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
