import 'package:civiltrust_app/features/diagnostics/environment_page.dart';
import 'package:civiltrust_app/features/diagnostics/connectivity_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'environment_config_test.dart' show staging;

void main() {
  testWidgets(
    'phone diagnostics checks health and labels NFC/offline honestly',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = ConnectivityService(
        client: MockClient(
          (_) async => http.Response(
            '{"status":"healthy","service":"app-coordinator"}',
            200,
          ),
        ),
      );
      addTearDown(service.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnvironmentPage(
              config: staging(),
              pageUri: Uri.parse('https://demo.test/#join=private-capability'),
              service: service,
            ),
          ),
        ),
      );
      expect(find.text('NFC chưa sẵn sàng'), findsOneWidget);
      expect(find.textContaining('private-capability'), findsNothing);
      await tester.ensureVisible(find.text('Kiểm tra kết nối'));
      await tester.tap(find.text('Kiểm tra kết nối'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Health hợp lệ;'), findsOneWidget);
      expect(find.textContaining('Đã tắt trong bản demo.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
