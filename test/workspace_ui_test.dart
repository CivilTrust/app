import 'package:civiltrust_app/app/civiltrust_app.dart';
import 'package:civiltrust_app/core/models/party_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:civiltrust_app/features/agreements/create_agreement_page.dart';
import 'package:civiltrust_app/core/config/app_config.dart';

void main() {
  testWidgets('workspace chooser and role B identity fit narrow viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const CivilTrustApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byType(DropdownButtonFormField<PartyRole>));
    await tester.tap(find.byType(DropdownButtonFormField<PartyRole>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bên B · Chuyển tiền').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Hợp đồng đặt cọc'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Hợp đồng đặt cọc'));
    await tester.pumpAndSettle();
    expect(find.text('Quét CCCD mock của Bên B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'B fills only commercial terms and reaches review without A identity or bank',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateAgreementPage(
              config: AppConfig.fromEnvironment(),
              onPrepared: (draft, id) async {},
              initialForm: {
                'localId': 'draft:synthetic',
                'creatorRole': 'partyB',
                'templateId': 'deposit-v1',
                'fields': {
                  'assetDescription': 'Synthetic asset',
                  'assetAddress': 'Synthetic place',
                  'totalValue': '200000',
                  'depositAmount': '100000',
                  'completionDate': '01/12/2026',
                },
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(CheckboxListTile).first);
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Quét CCCD mock của Bên B'));
      await tester.tap(find.text('Quét CCCD mock của Bên B'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText == 'Số tài khoản nhận tiền',
        ),
        findsNothing,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is TextField && w.decoration?.labelText == 'Tên chủ tài khoản',
        ),
        findsNothing,
      );
      await tester.scrollUntilVisible(
        find.text('Tiếp tục xem lại'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục xem lại'));
      await tester.pumpAndSettle();
      expect(find.textContaining('A sẽ tự cung cấp danh tính'), findsOneWidget);
      expect(find.textContaining('Không được để trống'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
