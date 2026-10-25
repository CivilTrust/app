import 'dart:typed_data';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:civiltrust_app/core/crypto/hash_service.dart';
import 'package:civiltrust_app/core/encoding/encoding_utils.dart';
import 'package:civiltrust_app/core/models/agreement.dart';
import 'package:civiltrust_app/features/artifacts/artifact_service.dart';
import 'package:civiltrust_app/features/identity/mock_identity_reader.dart';
import 'package:civiltrust_app/features/signing/mock_party_signer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  final artifactService = ArtifactService(
    const HashService(),
    regularFont: () async => pw.Font.helvetica(),
    boldFont: () async => pw.Font.helveticaBold(),
  );

  test('final PDF and evidence ZIP round-trip offline', () async {
    final session = await _signedPaidSession();
    final bundle = await artifactService.build(session);

    expect(bundle.pdf, isNotEmpty);
    expect(bundle.evidence.documentHash, startsWith('0x'));
    expect(_containsBytes(bundle.zip, const [0x50, 0x4b, 0x01, 0x02]), isTrue);
    expect(_containsBytes(bundle.zip, const [0x50, 0x4b, 0x05, 0x06]), isTrue);
    final imported = artifactService.importZip(bundle.zip);
    expect(imported.documentHash, bundle.evidence.documentHash);
    expect(imported.session.partyA?.signedDigest, session.frozenDigest);
    expect(imported.session.partyB?.signedDigest, session.frozenDigest);
  });

  test('adding SCT changes sidecar only and preserves PDF hash', () async {
    final bundle = await artifactService.build(await _signedPaidSession());
    final withSct = artifactService.attachNotary(bundle, {
      'version': '1.3.0',
      'message': {'agreementHash': bundle.evidence.documentHash},
    });
    expect(withSct.pdf, bundle.pdf);
    expect(withSct.evidence.documentHash, bundle.evidence.documentHash);
    final imported = artifactService.importZip(withSct.zip);
    expect(imported.documentHash, bundle.evidence.documentHash);
    expect(imported.signedCommitment?['version'], '1.3.0');
  });

  test('tampered PDF is rejected during ZIP import', () async {
    final bundle = await artifactService.build(await _signedPaidSession());
    final source = ZipDecoder().decodeBytes(bundle.zip);
    final evidence = source.findFile('evidence.civiltrust.json')!;
    final tampered = Archive()
      ..addFile(
        ArchiveFile.bytes('agreement.pdf', Uint8List.fromList([1, 2, 3])),
      )
      ..addFile(
        ArchiveFile.bytes(
          'evidence.civiltrust.json',
          evidence.content as List<int>,
        ),
      );
    final bytes = Uint8List.fromList(ZipEncoder().encodeBytes(tampered));

    expect(
      () => artifactService.importZip(bytes),
      throwsA(isA<FormatException>()),
    );
  });

  test('unsupported evidence schema is rejected', () async {
    final bundle = await artifactService.build(await _signedPaidSession());
    final source = ZipDecoder().decodeBytes(bundle.zip);
    final pdf = source.findFile('agreement.pdf')!;
    final evidence = source.findFile('evidence.civiltrust.json')!;
    final decoded = jsonDecode(
      utf8.decode(evidence.content as List<int>),
    ) as Map<String, dynamic>;
    decoded['schema'] = 'civiltrust-evidence/99.0';
    final changed = Archive()
      ..addFile(ArchiveFile.bytes('agreement.pdf', pdf.content as List<int>))
      ..addFile(
        ArchiveFile.bytes(
          'evidence.civiltrust.json',
          utf8.encode(jsonEncode(decoded)),
        ),
      );

    expect(
      () => artifactService.importZip(
        Uint8List.fromList(ZipEncoder().encodeBytes(changed)),
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

bool _containsBytes(List<int> bytes, List<int> pattern) {
  for (var offset = 0; offset <= bytes.length - pattern.length; offset++) {
    var matches = true;
    for (var index = 0; index < pattern.length; index++) {
      if (bytes[offset + index] != pattern[index]) {
        matches = false;
        break;
      }
    }
    if (matches) return true;
  }
  return false;
}

Future<SigningSession> _signedPaidSession() async {
  const hash = HashService();
  final signer = MockPartySigner();
  final identityReader = MockIdentityReader();
  final draft = AgreementDraft(
    id: 'agreement-test',
    title: 'Loan agreement',
    terms: 'Party B repays Party A before the due date.',
    amountVnd: 1000000,
    createdAt: DateTime.utc(2026, 10, 10),
  );
  final digest = hash.canonicalObjectHash(draft.toJson());
  final partyA = await signer.sign(
    role: 'partyA',
    digest: hexToBytes(digest),
    identity: await identityReader.read(role: 'partyA'),
  );
  final partyB = await signer.sign(
    role: 'partyB',
    digest: hexToBytes(digest),
    identity: await identityReader.read(role: 'partyB'),
  );
  return SigningSession(
    draft: draft,
    state: AgreementState.paymentConfirmed,
    frozenDigest: digest,
    partyA: partyA,
    partyB: partyB,
    payment: PaymentReceipt(
      confirmedByPartyA: true,
      confirmedAt: DateTime.utc(2026, 10, 10, 12),
      reference: 'BANK-TEST-001',
    ),
  );
}
