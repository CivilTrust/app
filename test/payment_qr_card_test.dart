import 'dart:async';

import 'package:civiltrust_app/features/payment/payment_details.dart';
import 'package:civiltrust_app/features/payment/payment_qr_actions.dart';
import 'package:civiltrust_app/features/payment/payment_qr_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import 'fixtures/payment_draft.dart';

Uint8List smallPng([int red = 255]) => Uint8List.fromList(
  image.encodePng(
    image.fill(
      image.Image(width: 2, height: 2, numChannels: 4),
      color: image.ColorRgba8(red, 255, 255, 255),
    ),
  ),
);

class TestActions extends PaymentQrActions {
  TestActions();
  int saves = 0;
  int shares = 0;
  bool shareFails = false;
  bool renderFails = false;
  QrShareOutcome outcome = QrShareOutcome.dismissed;
  Uint8List? saved;
  String? filename;
  Future<Uint8List> Function(String)? renderer;
  @override
  Future<Uint8List> render(String payload) async {
    if (renderFails) throw StateError('render failed');
    return renderer == null ? smallPng() : renderer!(payload);
  }

  @override
  Future<void> save(Uint8List png, String fileBase) async {
    saves++;
    saved = png;
    filename = fileBase;
  }

  @override
  Future<QrShareOutcome> share(
    Uint8List png,
    String fileBase,
    Rect origin,
  ) async {
    shares++;
    expect(origin.width, greaterThan(0));
    if (shareFails) throw StateError('untrusted exception 000000000001');
    return outcome;
  }
}

void main() {
  testWidgets(
    '375px card copies raw values and saves PNG without marking payment',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final actions = TestActions();
      var marked = 0;
      final draft = paymentDraft();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PaymentQrCard(
                draft: draft,
                actions: actions,
                footer: TextButton(
                  onPressed: () => marked++,
                  child: const Text('B báo chuyển mô phỏng'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2.000.000 VNĐ'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Sao chép Số tiền'));
      await tester.tap(find.byTooltip('Sao chép Số tiền'));
      await tester.pumpAndSettle();
      expect(clipboard, '2000000');
      await tester.ensureVisible(find.text('Sao chép thông tin'));
      await tester.tap(find.text('Sao chép thông tin'));
      await tester.pumpAndSettle();
      expect(clipboard, PaymentDetails.fromDraft(draft).copyText);
      expect(clipboard, isNot(contains('#join')));
      await tester.ensureVisible(find.text('Tải ảnh QR'));
      await tester.tap(find.text('Tải ảnh QR'));
      await tester.pumpAndSettle();
      expect(actions.saves, 1);
      expect(actions.saved, smallPng());
      expect(actions.filename, isNot(contains('000000000001')));
      expect(marked, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'share cancellation and unsupported sharing never trigger a download',
    (tester) async {
      final actions = TestActions();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PaymentQrCard(draft: paymentDraft(), actions: actions),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Chia sẻ ảnh QR'));
      await tester.tap(find.text('Chia sẻ ảnh QR'));
      await tester.pumpAndSettle();
      expect(find.text('Đã hủy chia sẻ ảnh.'), findsOneWidget);
      expect(actions.saves, 0);
      actions.shareFails = true;
      await tester.tap(find.text('Chia sẻ ảnh QR'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Hãy dùng Tải ảnh QR'), findsOneWidget);
      expect(find.textContaining('untrusted exception'), findsNothing);
      expect(actions.saves, 0);
    },
  );

  testWidgets(
    'invalid signed fields cannot expose a payment completion action',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaymentQrCard(
              draft: paymentDraft(
                overrides: {'accountNumber': 'too-long-account-number'},
              ),
              actions: TestActions(),
              footer: const Text('mark transferred'),
            ),
          ),
        ),
      );
      expect(find.text('Chưa tạo được VietQR cho hồ sơ này'), findsOneWidget);
      expect(find.text('mark transferred'), findsNothing);
      expect(find.text('Tải ảnh QR'), findsNothing);
    },
  );

  testWidgets('image failure preserves copy fallback', (tester) async {
    final actions = TestActions()..renderFails = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PaymentQrCard(draft: paymentDraft(), actions: actions),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Thử tạo lại ảnh QR'), findsOneWidget);
    expect(find.text('Sao chép thông tin'), findsOneWidget);
  });

  testWidgets('late QR rendering cannot replace the next agreement image', (
    tester,
  ) async {
    final pending = <String, Completer<Uint8List>>{};
    final actions = TestActions()
      ..renderer = (payload) =>
          (pending[payload] = Completer<Uint8List>()).future;
    Widget host(String id) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PaymentQrCard(
            draft: paymentDraft(id: id),
            actions: actions,
          ),
        ),
      ),
    );
    await tester.pumpWidget(host('first'));
    final first = pending.values.single;
    await tester.pumpWidget(host('second'));
    final second = pending.values.last;
    final expected = smallPng(128);
    second.complete(expected);
    await tester.pumpAndSettle();
    first.complete(smallPng());
    await tester.pumpAndSettle();
    final rendered =
        tester.widget<Image>(find.byType(Image)).image as MemoryImage;
    expect(rendered.bytes, expected);
    expect(find.text(PaymentDetails.purposeFor('second')), findsOneWidget);
    expect(find.text(PaymentDetails.purposeFor('first')), findsNothing);
  });
}
