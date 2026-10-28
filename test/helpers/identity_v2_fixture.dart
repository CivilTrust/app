import 'package:civiltrust_app/core/models/identity_evidence.dart';
import 'package:civiltrust_app/features/identity/identity_context.dart';
import 'package:civiltrust_app/features/identity/identity_reader.dart';

final identityTestTime = DateTime.utc(2026, 10, 27, 8);
final identityTestCeremony = createIdentityNonce();

IdentityContext testIdentityContext({
  String role = 'partyA',
  String? ceremony,
  DateTime? now,
}) => IdentityContext.create(
  ceremonyId: ceremony ?? identityTestCeremony,
  role: role,
  now: now ?? identityTestTime,
);

IdentityEvidence testIdentity({IdentityContext? context}) => IdentityEvidence(
  source: 'mock',
  displayName: 'SYNTHETIC TEST PERSON',
  documentNumberMasked: '********0001',
  readAt: (context ?? testIdentityContext()).issuedAt,
  chipAuthentication: 'mock',
  identityCommitment: 'synthetic-only',
  schemaVersion: 2,
  assurance: IdentityAssurance.mock,
  context: context ?? testIdentityContext(),
  verifierId: 'mock-only',
  policyVersion: 'mock-v2',
);

class ImmediateMockReader implements IdentityReader {
  int reads = 0;
  int cancellations = 0;
  @override
  Future<bool> isSupported() async => true;
  @override
  Future<IdentityEvidence> read({required String role}) async {
    reads++;
    return testIdentity();
  }

  @override
  Future<void> cancel() async {
    cancellations++;
  }
}
