import 'package:civiltrust_app/core/config/app_config.dart';
import 'package:civiltrust_app/features/agreements/create_agreement_page.dart';
import 'package:civiltrust_app/features/identity/identity_service.dart';
import 'package:civiltrust_app/features/identity/nfc_readiness_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('readiness is honest on narrow iPhone-sized viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: NfcReadinessPage(mode: IdentityMode.verifiedNative),
      ),
    );
    expect(find.textContaining('iOS 26.2'), findsOneWidget);
    expect(find.textContaining('nhóm chưa có'), findsOneWidget);
    await tester.ensureVisible(find.text('Kiểm tra adapter hiện tại'));
    await tester.tap(find.text('Kiểm tra adapter hiện tại'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa khả dụng:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('native mode cannot advance A using a hidden mock reader', (
    tester,
  ) async {
    const config = AppConfig(
      coordinatorBaseUrl: 'http://localhost:8788',
      notaryBaseUrl: '',
      rpcUrl: '',
      registryContract: '',
      chainId: 421614,
      notaryEnabled: false,
      identityMode: IdentityMode.verifiedNative,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CreateAgreementPage(config: config)),
      ),
    );
    await tester.ensureVisible(find.text('Hợp đồng đặt cọc'));
    await tester.tap(find.text('Hợp đồng đặt cọc'));
    await tester.pumpAndSettle();
    expect(find.text('Quét CCCD mock của Bên A'), findsNothing);
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Kiểm tra NFC Bên A'));
    await tester.tap(find.text('Kiểm tra NFC Bên A'));
    await tester.pumpAndSettle();
    expect(find.textContaining('không chạy trên Web/Windows'), findsOneWidget);
    expect(find.text('Tiếp tục xem lại'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
