import 'dart:convert';

import 'package:civiltrust_app/core/crypto/hash_service.dart';
import 'package:civiltrust_app/core/encoding/encoding_utils.dart';
import 'package:civiltrust_app/core/models/agreement.dart';
import 'package:civiltrust_app/core/models/party_signature.dart';
import 'package:civiltrust_app/features/artifacts/artifact_service.dart';
import 'package:civiltrust_app/features/artifacts/evidence_manifest.dart';
import 'package:civiltrust_app/features/artifacts/verify_bundle_page.dart';
import 'package:civiltrust_app/features/signing/mock_party_signer.dart';
import 'package:civiltrust_app/features/signing/session_validator.dart';
import 'package:civiltrust_app/features/signing/signing_context.dart';
import 'package:civiltrust_app/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

import 'helpers/identity_v2_fixture.dart';

Future<SigningSession> v2PaidSession() async {
  const hash = HashService();
  final draft = AgreementDraft(
    id: 'v2-test',
    title: 'Synthetic',
    terms: 'Synthetic agreement',
    amountVnd: 1,
    createdAt: identityTestTime,
    fields: {
      'signingProtocol': SigningContext.protocol,
      'identityCeremonyId': identityTestCeremony,
    },
  );
  final digest = hash.canonicalObjectHash(draft.toJson());
  final signer = MockPartySigner(clock: () => identityTestTime);
  Future<PartySignature> sign(String role) => signer.sign(
    role: role,
    digest: hexToBytes(digest),
    identity: testIdentity(context: testIdentityContext(role: role)),
    context: SigningContext.fromDraft(draft),
  );
  return SigningSession(
    draft: draft,
    state: AgreementState.paymentConfirmed,
    frozenDigest: digest,
    partyA: await sign('partyA'),
    partyB: await sign('partyB'),
    payment: PaymentReceipt(
      confirmedByPartyA: true,
      confirmedAt: identityTestTime,
      reference: 'SYNTHETIC',
    ),
  );
}

void main() {
  final artifacts = ArtifactService(
    const HashService(),
    regularFont: () async => pw.Font.helvetica(),
    boldFont: () async => pw.Font.helveticaBold(),
  );
  test(
    'v2 binding survives encrypted-style JSON and ZIP; SCT keeps PDF bytes',
    () async {
      final original = await v2PaidSession();
      final session = SigningSession.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      await SessionValidator(
        const HashService(),
        MockPartySigner(),
      ).validate(session, requirePartyB: true);
      final bundle = await artifacts.build(session);
      expect(bundle.evidence.schema, EvidenceManifest.currentSchema);
      final imported = artifacts.importZip(bundle.zip);
      await SessionValidator(
        const HashService(),
        MockPartySigner(),
      ).validate(imported.session, requirePartyB: true);
      final appended = artifacts.attachNotary(bundle, {
        'fixture': 'not-real-sct',
      });
      expect(appended.pdf, bundle.pdf);
      expect(appended.evidence.documentHash, bundle.evidence.documentHash);
      expect(appended.evidence.schema, bundle.evidence.schema);
      expect(
        artifacts.importZip(appended.zip).schema,
        EvidenceManifest.currentSchema,
      );
    },
  );
  test(
    'real/self-reported NFC identity export blocked before PDF fonts/network',
    () async {
      final session = await v2PaidSession();
      final json = jsonDecode(
        jsonEncode(session.partyA!.toJson()),
      ) as Map<String, dynamic>;
      (json['identity'] as Map)['source'] = 'ios-nfc';
      final guarded = ArtifactService(
        const HashService(),
        regularFont: () async => throw StateError('FONT MUST NOT LOAD'),
      );
      await expectLater(
        guarded.build(session.copyWith(partyA: PartySignature.fromJson(json))),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('không cho xuất'),
          ),
        ),
      );
    },
  );
  test(
    'UI distinguishes signature integrity from identity authentication',
    () async {
      final session = await v2PaidSession();
      const config = AppConfig(
        coordinatorBaseUrl: '',
        notaryBaseUrl: '',
        rpcUrl: '',
        registryContract: '',
        chainId: 421614,
      );
      final rows = verificationResultsFor(
        EvidenceManifest(
          documentHash: 'hash',
          evidenceHash: 'hash',
          session: session,
        ),
        config,
      );
      expect(
        rows.firstWhere((e) => e.label == 'Chữ ký Bên B').detail,
        contains('không xác thực CCCD thật'),
      );
      expect(
        rows.firstWhere((e) => e.label == 'Xác thực CCCD / chủ thẻ').level,
        VerificationLevel.notConfigured,
      );
    },
  );
}
