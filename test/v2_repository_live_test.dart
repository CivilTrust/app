import 'package:civiltrust_app/core/crypto/hash_service.dart';
import 'package:civiltrust_app/core/models/agreement.dart';
import 'package:civiltrust_app/features/sessions/invite_url.dart';
import 'package:civiltrust_app/features/sessions/remote_session_repository.dart';
import 'package:civiltrust_app/features/signing/mock_party_signer.dart';
import 'package:civiltrust_app/features/signing/session_validator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'v2_artifact_test.dart' show v2PaidSession;

void main() {
  const endpoint = String.fromEnvironment('LIVE_COORDINATOR_URL');
  test(
    'v2 signatures survive real encrypted A/B coordinator exchange',
    () async {
      final full = await v2PaidSession();
      final initial = SigningSession(
        draft: full.draft,
        state: AgreementState.partyASigned,
        frozenDigest: full.frozenDigest,
        partyA: full.partyA,
      );
      final repository = RemoteSessionRepository(endpoint);
      final created = await repository.create(initial);
      final invite = parseParticipantInvite(
        'join=${created.participant.toInviteFragment()}',
      );
      final viewB = await repository.read(invite);
      final validator = SessionValidator(
        const HashService(),
        MockPartySigner(),
      );
      await validator.validate(viewB.value);
      await repository.update(
        invite,
        viewB.value.copyWith(
          partyB: full.partyB,
          state: AgreementState.partyBSigned,
        ),
        viewB.version,
      );
      final viewA = await repository.read(created.owner);
      await validator.validate(viewA.value, requirePartyB: true);
      expect(viewA.value.partyB!.envelope, full.partyB!.envelope);
      expect(viewA.value.partyB!.identity, full.partyB!.identity);
      await repository.finalize(created.owner);
      expect((await repository.read(invite)).finalized, isTrue);
    },
    skip: endpoint.isEmpty
        ? 'Set LIVE_COORDINATOR_URL for real HTTP exchange.'
        : false,
  );
}
