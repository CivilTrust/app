import 'package:civiltrust_app/core/models/agreement.dart';
import 'package:civiltrust_app/features/payment/payment_details.dart';
import 'package:civiltrust_app/features/workspace/contract_reader_page.dart';
import 'package:civiltrust_app/features/workspace/workflow_rules.dart';
import 'package:civiltrust_app/features/workspace/workspace_overview.dart';
import 'package:civiltrust_app/ui/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SigningSession session(
  AgreementState state, {
  String creator = 'partyA',
  bool payer = false,
}) => SigningSession(
  draft: AgreementDraft(
    id: '1700000000000000-0123456789abcdef',
    title: 'Hợp đồng đặt cọc',
    terms: 'Nội dung',
    amountVnd: 5000000,
    createdAt: DateTime.utc(2026, 11, 18),
    templateId: 'deposit-v1',
    fields: {
      'workflowProfile': payer
          ? WorkflowRules.payerProfile
          : WorkflowRules.profile,
      'creatorRole': creator,
    },
  ),
  state: state,
);

Map<String, dynamic> record(String role, {Map<String, dynamic>? extra}) => {
  'role': role,
  'version': 3,
  ...?extra,
};

void main() {
  test('agreement code is the prefix of the VietQR transfer memo', () {
    const id = '1700000000000000-0123456789abcdef';
    final code = agreementCode(id);
    expect(code, matches(RegExp(r'^CT-[0-9A-F]{8}$')));
    expect(
      PaymentDetails.purposeFor(id),
      startsWith('CIVILTRUST ${code.substring(3)}'),
    );
  });

  group('overviewOf', () {
    test('A-created: A approves first, B waits', () {
      final s = session(AgreementState.draft);
      expect(overviewOf(record('partyA'), s).bucket, RecordBucket.action);
      final b = overviewOf(record('partyB'), s);
      expect(b.bucket, RecordBucket.waiting);
      expect(b.headline, contains('Bên A'));
    });

    test('payer proposal: A signs before B', () {
      final s = session(
        AgreementState.contentFrozen,
        creator: 'partyB',
        payer: true,
      );
      expect(overviewOf(record('partyA'), s).headline, contains('ký'));
      expect(overviewOf(record('partyB'), s).headline, 'Chờ Bên A ký');
    });

    test('payment steps follow the B to A money direction', () {
      final both = session(AgreementState.bothSigned);
      expect(
        overviewOf(record('partyB'), both).headline,
        contains('Chuyển khoản'),
      );
      expect(overviewOf(record('partyA'), both).bucket, RecordBucket.waiting);
      final pending = session(AgreementState.paymentPending);
      expect(
        overviewOf(record('partyA'), pending).headline,
        contains('xác nhận đã nhận'),
      );
    });

    test('finalized, declined, pending and read-only records', () {
      final s = session(AgreementState.paymentConfirmed);
      expect(
        overviewOf(record('partyB', extra: {'finalized': true}), s).bucket,
        RecordBucket.done,
      );
      expect(
        overviewOf(record('partyA'), session(AgreementState.declined)).bucket,
        RecordBucket.done,
      );
      expect(
        overviewOf(
          record('partyA', extra: {'pending': {}}),
          session(AgreementState.draft),
        ).headline,
        contains('Làm mới'),
      );
      expect(
        overviewOf(
          record('partyA', extra: {'readOnly': true}),
          session(AgreementState.draft),
        ).bucket,
        RecordBucket.waiting,
      );
    });
  });

  test('timeline marks completed and current steps', () {
    final steps = timelineOf(session(AgreementState.bothSigned));
    expect(steps, hasLength(7));
    expect(steps.take(4).every((s) => s.done), isTrue);
    expect(steps[4].current, isTrue);
    expect(steps[4].label, contains('chuyển khoản'));
    final done = timelineOf(
      session(AgreementState.paymentConfirmed),
      finalized: true,
    );
    expect(done.every((s) => s.done), isTrue);
    final closed = timelineOf(session(AgreementState.declined));
    expect(closed.any((s) => s.current), isFalse);
  });

  testWidgets('reader enables confirmation only after scrolling to the end', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await ContractReaderPage.open(
              context,
              title: 'Hợp đồng',
              text: List.filled(200, 'Điều khoản dài.').join('\n'),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    FilledButton button() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Tôi đã đọc hết nội dung'),
    );
    expect(button().onPressed, isNull);
    await tester.scrollUntilVisible(
      find.text('— Hết nội dung —'),
      800,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(button().onPressed, isNotNull);
    await tester.tap(find.text('Tôi đã đọc hết nội dung'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('irreversible confirmation returns false unless confirmed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final results = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await confirmIrreversible(
                context,
                title: 'Ký hợp đồng?',
                points: const ['Điểm'],
                confirmLabel: 'Ký hợp đồng',
              ),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Thao tác này không thể hoàn tác.'), findsOneWidget);
    await tester.tap(find.text('Quay lại xem'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Ký hợp đồng'));
    await tester.pumpAndSettle();
    expect(results, [false, true]);
  });
}
