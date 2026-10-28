import 'dart:convert';

import 'package:civiltrust_app/core/crypto/hash_service.dart';
import 'package:civiltrust_app/core/encoding/encoding_utils.dart';
import 'package:civiltrust_app/core/models/agreement.dart';
import 'package:civiltrust_app/core/models/identity_evidence.dart';
import 'package:civiltrust_app/core/models/party_signature.dart';
import 'package:civiltrust_app/features/identity/identity_reader.dart';
import 'package:civiltrust_app/features/signing/mock_party_signer.dart';
import 'package:civiltrust_app/features/signing/session_validator.dart';
import 'package:civiltrust_app/features/signing/signing_context.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/identity_v2_fixture.dart';

Map<String, dynamic> clone(Map<String, Object?> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

void main() {
  const hash = HashService();
  final draft = AgreementDraft(
    id: 'test-agreement',
    title: 'Synthetic',
    terms: 'Synthetic terms',
    amountVnd: 1,
    createdAt: identityTestTime,
    fields: {
      'signingProtocol': SigningContext.protocol,
      'identityCeremonyId': identityTestCeremony,
    },
  );
  final digest = hash.keccakBytes(utf8.encode(canonicalJson(draft.toJson())));
  final context = SigningContext.fromDraft(draft);

  Future<PartySignature> sign({
    MockPartySigner? signer,
    IdentityEvidence? identity,
    String role = 'partyA',
    SigningContext? signingContext,
  }) => (signer ?? MockPartySigner(clock: () => identityTestTime)).sign(
    role: role,
    digest: digest,
    identity:
        identity ?? testIdentity(context: testIdentityContext(role: role)),
    context: signingContext ?? context,
  );

  test(
    'v2 signs identity role draft key challenge and time, round trips',
    () async {
      final signature = await sign();
      expect(signature.schemaVersion, 2);
      expect(signature.signedDigest, bytesToHex(digest));
      expect(
        await MockPartySigner().verify(
          PartySignature.fromJson(clone(signature.toJson())),
        ),
        isTrue,
      );
      // Historical verification uses signedAt, not wall-clock expiry today.
      expect(
        await MockPartySigner(
          clock: () => identityTestTime.add(const Duration(days: 100)),
        ).verify(signature),
        isTrue,
      );
    },
  );

  final mutations = <String, void Function(Map<String, dynamic>)>{
    'identity B/name': (json) =>
        (json['identity'] as Map)['displayName'] = 'ATTACKER',
    'identity source': (json) =>
        (json['identity'] as Map)['source'] = 'ios-nfc',
    'self-reported assurance': (json) =>
        (json['identity'] as Map)['assurance'] = 'chipAuthenticated',
    'role': (json) => json['role'] = 'partyA',
    'draft digest': (json) => json['signedDigest'] = hash.keccakHex([1]),
    'public key': (json) =>
        json['publicKey'] = base64UrlNoPadding(List.filled(32, 1)),
    'signature': (json) =>
        json['signature'] = base64UrlNoPadding(List.filled(64, 1)),
    'signed time': (json) => json['signedAt'] = identityTestTime
        .add(const Duration(seconds: 1))
        .toIso8601String(),
    'ceremony': (json) => (json['envelope'] as Map)['ceremonyId'] = 'OTHER',
    'agreement': (json) => (json['envelope'] as Map)['agreementId'] = 'other',
    'challenge': (json) =>
        ((json['envelope'] as Map)['challenge'] as Map)['challengeId'] =
            'OTHER',
    'identity hash': (json) =>
        (json['envelope'] as Map)['identityHash'] = hash.keccakHex([2]),
    'key fingerprint': (json) =>
        (json['envelope'] as Map)['publicKeyFingerprint'] = hash.keccakHex([2]),
    'domain': (json) => (json['envelope'] as Map)['domain'] = 'other-protocol',
    'extra envelope field': (json) => (json['envelope'] as Map)['extra'] = true,
    'algorithm suffix': (json) => json['algorithm'] = 'Ed25519-unknown',
    'schema downgrade': (json) => json['schemaVersion'] = 1,
    'schema upgrade': (json) => json['schemaVersion'] = 99,
    'missing envelope': (json) => json.remove('envelope'),
  };
  for (final mutation in mutations.entries) {
    test('reject tampered ${mutation.key}', () async {
      final json = clone((await sign(role: 'partyB')).toJson());
      mutation.value(json);
      expect(
        await MockPartySigner().verify(PartySignature.fromJson(json)),
        isFalse,
      );
    });
  }
  test('signer rejects wrong role and cross-ceremony identity', () async {
    await expectLater(
      sign(role: 'partyB', identity: testIdentity()),
      throwsA(isA<IdentityReaderException>()),
    );
    await expectLater(
      sign(
        signingContext: const SigningContext(
          agreementId: 'test',
          ceremonyId: 'other',
        ),
      ),
      throwsA(isA<IdentityReaderException>()),
    );
  });
  test('signer refuses expired or future context', () async {
    await expectLater(
      sign(
        signer: MockPartySigner(
          clock: () => identityTestTime.add(const Duration(minutes: 15)),
        ),
      ),
      throwsA(isA<IdentityReaderException>()),
    );
    await expectLater(
      sign(
        signer: MockPartySigner(
          clock: () => identityTestTime.subtract(const Duration(seconds: 1)),
        ),
      ),
      throwsA(isA<IdentityReaderException>()),
    );
  });
  test(
    'local challenge may sign once, including concurrent attempts',
    () async {
      final signer = MockPartySigner(clock: () => identityTestTime);
      final identity = testIdentity();
      final first = sign(signer: signer, identity: identity);
      await expectLater(
        sign(signer: signer, identity: identity),
        throwsA(
          isA<IdentityReaderException>().having(
            (e) => e.code,
            'code',
            IdentityErrorCode.replay,
          ),
        ),
      );
      expect(await MockPartySigner().verify(await first), isTrue);
    },
  );
  test(
    'mock signer cannot promote native proof to authenticated identity',
    () async {
      final json = clone(testIdentity().toJson());
      json['source'] = 'ios-nfc';
      json['assurance'] = 'chipAuthenticated';
      json['chipAuthentication'] = 'verified';
      json['proof'] = {'verified': true};
      await expectLater(
        sign(identity: IdentityEvidence.fromJson(json)),
        throwsA(isA<IdentityReaderException>()),
      );
    },
  );
  test('session checks both A/B and rejects signature replay from another agreement', () async {
    final session = SigningSession(
      draft: draft,
      state: AgreementState.partyBSigned,
      frozenDigest: bytesToHex(digest),
      partyA: await sign(),
      partyB: await sign(role: 'partyB'),
    );
    await SessionValidator(
      hash,
      MockPartySigner(),
    ).validate(session, requirePartyB: true);
    final replay = await sign(
      signingContext: SigningContext(
        agreementId: 'other-agreement',
        ceremonyId: identityTestCeremony,
      ),
    );
    expect(await MockPartySigner().verify(replay), isTrue);
    await expectLater(
      SessionValidator(
        hash,
        MockPartySigner(),
      ).validate(session.copyWith(partyA: replay)),
      throwsFormatException,
    );
  });
  test('new signatures cannot downgrade to v1 identity', () async {
    final legacy = IdentityEvidence(
      source: 'mock',
      displayName: 'SYNTHETIC',
      documentNumberMasked: '***',
      readAt: identityTestTime,
      chipAuthentication: 'mock',
      identityCommitment: 'mock',
    );
    await expectLater(
      sign(identity: legacy),
      throwsA(isA<IdentityReaderException>()),
    );
    final old = await MockPartySigner().sign(
      role: 'partyA',
      digest: digest,
      identity: legacy,
    );
    expect(await MockPartySigner().verify(old), isTrue);
    expect(old.toJson().containsKey('schemaVersion'), isFalse);
  });
}
