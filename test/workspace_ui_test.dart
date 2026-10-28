import 'package:civiltrust_app/app/civiltrust_app.dart';
import 'package:civiltrust_app/core/models/party_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
