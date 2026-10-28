import 'dart:async';
import 'dart:convert';

import 'package:civiltrust_app/core/models/identity_evidence.dart';
import 'package:civiltrust_app/features/identity/identity_reader.dart';
import 'package:civiltrust_app/features/identity/identity_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';

import 'helpers/identity_v2_fixture.dart';

Matcher failsWith(IdentityErrorCode code) =>
    throwsA(isA<IdentityReaderException>().having((e) => e.code, 'code', code));

class PendingReader extends ImmediateMockReader {
  final pending = Completer<IdentityEvidence>();
  @override
  Future<IdentityEvidence> read({required String role}) {
    reads++;
    return pending.future;
  }
}

class BrokenReader extends ImmediateMockReader {
  @override
  Future<IdentityEvidence> read({required String role}) async =>
      throw StateError('SECRET-CCCD-SDK-ERROR');
}

class ForgedReader extends ImmediateMockReader {
  @override
  Future<IdentityEvidence> read({required String role}) async =>
      IdentityEvidence.fromJson({
        ...testIdentity().toJson(),
        'assurance': 'chipAuthenticated',
        'proof': {'verified': true},
      });
}

void main() {
  test(
    'iOS target alone never makes the unconfigured reader supported',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final capability = await IdentityService.forMode(
        IdentityMode.verifiedNative,
      ).capability();
      expect(capability.available, isFalse);
      expect(capability.error, IdentityErrorCode.misconfigured);
    },
  );
  IdentityService service(
    IdentityReader reader, {
    Duration timeout = const Duration(seconds: 45),
  }) => IdentityService(
    mode: IdentityMode.mock,
    reader: reader,
    clock: () => identityTestTime,
    timeout: timeout,
  );

  test('known modes parse and typo never defaults to mock', () {
    expect(IdentityMode.parse('native-lab'), IdentityMode.nativeLab);
    expect(IdentityMode.parse('verified-native'), IdentityMode.verifiedNative);
    expect(() => IdentityMode.parse('verified'), throwsFormatException);
  });
  test('random ceremony and challenge are independent 256-bit tokens', () {
    final contexts = List.generate(100, (_) => testIdentityContext());
    expect(contexts.map((e) => e.challengeId).toSet(), hasLength(100));
    expect(contexts.every((e) => e.isValidAt(identityTestTime)), isTrue);
    expect(
      testIdentityContext().isValidAt(
        identityTestTime.add(const Duration(minutes: 15)),
      ),
      isFalse,
    );
  });
  test('consent mandatory before capability/read', () async {
    final reader = ImmediateMockReader();
    await expectLater(
      service(reader).identify(context: testIdentityContext(), consent: false),
      failsWith(IdentityErrorCode.consentRequired),
    );
    expect(reader.reads, 0);
  });
  test(
    'unexpected reader error is sanitized and does not expose SDK/PII',
    () async {
      try {
        await service(BrokenReader())
            .identify(context: testIdentityContext(), consent: true);
        fail('Expected reader failure');
      } on IdentityReaderException catch (e) {
        expect(e.code, IdentityErrorCode.authenticationFailed);
        expect(e.message, isNot(contains('SECRET')));
      }
    },
  );
  test(
    'reader cannot promote mock into a self-reported verified identity',
    () async {
      await expectLater(
        service(ForgedReader())
            .identify(context: testIdentityContext(), consent: true),
        failsWith(IdentityErrorCode.authenticationFailed),
      );
    },
  );
  test('expired challenge blocks read', () async {
    final reader = ImmediateMockReader();
    await expectLater(
      service(reader).identify(
        context: testIdentityContext(
          now: identityTestTime.subtract(const Duration(hours: 1)),
        ),
        consent: true,
      ),
      failsWith(IdentityErrorCode.expired),
    );
    expect(reader.reads, 0);
  });
  for (final mode in [IdentityMode.nativeLab, IdentityMode.verifiedNative]) {
    test('$mode never falls back to mock on Web/Windows', () async {
      final reader = ImmediateMockReader();
      final instance = IdentityService(
        mode: mode,
        reader: reader,
        clock: () => identityTestTime,
      );
      expect((await instance.capability()).available, isFalse);
      await expectLater(
        instance.identify(context: testIdentityContext(), consent: true),
        failsWith(IdentityErrorCode.unsupported),
      );
      expect(reader.reads, 0);
    });
    test(
      '$mode gates real reads even if an iOS reader says supported',
      () async {
        final reader = ImmediateMockReader();
        final instance = IdentityService(
          mode: mode,
          reader: reader,
          isNativeIos: true,
          clock: () => identityTestTime,
        );
        await expectLater(
          instance.identify(context: testIdentityContext(), consent: true),
          failsWith(IdentityErrorCode.verifierUnavailable),
        );
        expect(reader.reads, 0);
      },
    );
  }
  test(
    'stub on native iOS reports misconfiguration, not fake success',
    () async {
      // No MethodChannel is invoked just because the target is iOS.
      final instance = IdentityService.forMode(IdentityMode.verifiedNative);
      expect((await instance.capability()).available, isFalse);
    },
  );
  test('mock result is typed v2 and remains explicitly mock', () async {
    final evidence = await service(ImmediateMockReader())
        .identify(context: testIdentityContext(), consent: true);
    expect(evidence.schemaVersion, 2);
    expect(evidence.assurance, IdentityAssurance.mock);
    expect(evidence.proof, isNull);
    final decoded = IdentityEvidence.fromJson(
      jsonDecode(jsonEncode(evidence.toJson())) as Map<String, dynamic>,
    );
    expect(decoded.toJson(), evidence.toJson());
    expect(decoded.toJson()['holderCheck'], 'unchecked');
    expect(
      () => decoded.attributes['rawApdu'] = 'secret',
      throwsUnsupportedError,
    );
  });
  test('unknown evidence version and holder assertion are rejected', () {
    expect(
      () => IdentityEvidence.fromJson({
        ...testIdentity().toJson(),
        'schemaVersion': 99,
      }),
      throwsFormatException,
    );
    expect(
      () => IdentityEvidence.fromJson({
        ...testIdentity().toJson(),
        'holderCheck': 'verified',
      }),
      throwsFormatException,
    );
    expect(
      () => IdentityEvidence.fromJson({
        ...testIdentity().toJson(),
        'rawApdu': 'SECRET',
      }),
      throwsFormatException,
    );
  });
  test('unconfigured verifier never trusts client assertion', () async {
    await expectLater(
      service(ImmediateMockReader())
          .verifyForNativeUse(testIdentity(), testIdentityContext()),
      failsWith(IdentityErrorCode.verifierUnavailable),
    );
  });
  test(
    'concurrent scans rejected; cancel ignores late callback and drains',
    () async {
      final reader = PendingReader();
      final instance = service(reader);
      final reading = instance.identify(
        context: testIdentityContext(),
        consent: true,
      );
      final cancelled = expectLater(
        reading,
        failsWith(IdentityErrorCode.cancelled),
      );
      await Future<void>.delayed(Duration.zero);
      await expectLater(
        instance.identify(context: testIdentityContext(), consent: true),
        failsWith(IdentityErrorCode.busy),
      );
      await instance.cancel();
      await cancelled;
      await expectLater(
        instance.identify(context: testIdentityContext(), consent: true),
        failsWith(IdentityErrorCode.busy),
      );
      reader.pending.complete(testIdentity());
      await Future<void>.delayed(Duration.zero);
      expect(reader.reads, 1);
      expect(reader.cancellations, 1);
    },
  );
  test('timeout cancels underlying reader and rejects late result', () async {
    final reader = PendingReader();
    final instance = service(reader, timeout: const Duration(milliseconds: 5));
    await expectLater(
      instance.identify(context: testIdentityContext(), consent: true),
      failsWith(IdentityErrorCode.timeout),
    );
    expect(reader.cancellations, 1);
    reader.pending.complete(testIdentity());
    await Future<void>.delayed(Duration.zero);
  });
  test('dispose cancels pending read and prevents future scans', () async {
    final reader = PendingReader();
    final instance = service(reader);
    final pending = instance.identify(
      context: testIdentityContext(),
      consent: true,
    );
    final cancelled = expectLater(
      pending,
      failsWith(IdentityErrorCode.cancelled),
    );
    await Future<void>.delayed(Duration.zero);
    await instance.dispose();
    await cancelled;
    reader.pending.complete(testIdentity());
    await expectLater(
      instance.identify(context: testIdentityContext(), consent: true),
      failsWith(IdentityErrorCode.cancelled),
    );
  });
}
