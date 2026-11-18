import 'package:civiltrust_app/app/civiltrust_app.dart';
import 'package:civiltrust_app/features/legal/legal_content.dart';
import 'package:civiltrust_app/features/legal/legal_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs Flutter's built-in accessibility guidelines on one screen.
Future<void> expectAccessible(WidgetTester tester) async {
  final handle = tester.ensureSemantics();
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  handle.dispose();
}

void phone(WidgetTester tester, {double textScale = 1}) {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  group('accessibility guidelines on a phone', () {
    testWidgets('home', (tester) async {
      phone(tester);
      await tester.pumpWidget(const CivilTrustApp());
      await tester.pumpAndSettle();
      await expectAccessible(tester);
    });

    testWidgets('create: template chooser', (tester) async {
      phone(tester);
      await tester.pumpWidget(const CivilTrustApp());
      await tester.pumpAndSettle();
      await openTab(tester, 'Tạo mới');
      await expectAccessible(tester);
    });

    testWidgets('records (vault locked)', (tester) async {
      phone(tester);
      await tester.pumpWidget(const CivilTrustApp());
      await tester.pumpAndSettle();
      await openTab(tester, 'Hồ sơ');
      await expectAccessible(tester);
    });

    testWidgets('verify', (tester) async {
      phone(tester);
      await tester.pumpWidget(const CivilTrustApp());
      await tester.pumpAndSettle();
      await openTab(tester, 'Kiểm chứng');
      await expectAccessible(tester);
    });

    testWidgets('privacy policy', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        const MaterialApp(home: LegalDocumentPage(document: privacyPolicy)),
      );
      await tester.pumpAndSettle();
      await expectAccessible(tester);
    });
  });

  group('200% text size does not break layout', () {
    for (final tab in [
      'Trang chủ',
      'Tạo mới',
      'Tham gia',
      'Hồ sơ',
      'Kiểm chứng',
    ]) {
      testWidgets(tab, (tester) async {
        phone(tester, textScale: 2);
        await tester.pumpWidget(const CivilTrustApp());
        await tester.pumpAndSettle();
        // Nav labels may be hidden at large sizes; tap by icon order instead.
        final index = [
          'Trang chủ',
          'Tạo mới',
          'Tham gia',
          'Hồ sơ',
          'Kiểm chứng',
        ].indexOf(tab);
        await tester.tap(find.byType(NavigationDestination).at(index));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('create flow at 200% text: identity and terms steps', (
    tester,
  ) async {
    phone(tester, textScale: 2);
    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.exceptionAsString());
    addTearDown(() => FlutterError.onError = previous);
    await tester.pumpWidget(const CivilTrustApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Hợp đồng vay tiền'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    // Lift the card above the bottom navigation bar before tapping.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hợp đồng vay tiền'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byType(CheckboxListTile).first,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Quét CCCD mock của Bên A'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quét CCCD mock của Bên A'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Tiếp tục xem lại'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Tiếp tục xem lại'), findsOneWidget);
    expect(errors, isEmpty);
  }, timeout: const Timeout(Duration(seconds: 90)));
}
