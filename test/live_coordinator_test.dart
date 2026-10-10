import 'package:civiltrust_app/core/models/agreement.dart';
import 'package:civiltrust_app/features/sessions/remote_session_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const baseUrl = String.fromEnvironment('LIVE_COORDINATOR_URL');

  test(
    'real coordinator supports a two-device state exchange',
    () async {
      final repository = RemoteSessionRepository(baseUrl);
      final initial = SigningSession(
        draft: AgreementDraft(
          id: 'live-test',
          title: 'Live coordinator test',
          terms: 'A and B use the same encrypted session.',
          amountVnd: 1000000,
          createdAt: DateTime.utc(2026, 10, 10),
        ),
        state: AgreementState.partyASigned,
        frozenDigest: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );

      final created = await repository.create(initial);
      final partyBView = await repository.read(created.participant);
      expect(partyBView.value.draft.title, initial.draft.title);
      expect(partyBView.version, 1);

      final newVersion = await repository.update(
        created.participant,
        partyBView.value.copyWith(state: AgreementState.partyBSigned),
        partyBView.version,
      );
      expect(newVersion, 2);

      final partyAView = await repository.read(created.owner);
      expect(partyAView.version, 2);
      expect(partyAView.value.state, AgreementState.partyBSigned);

      final finalizedVersion = await repository.finalize(created.owner);
      expect(finalizedVersion, 3);
      final finalized = await repository.read(created.participant);
      expect(finalized.finalized, isTrue);
    },
    skip: baseUrl.isEmpty
        ? 'Set LIVE_COORDINATOR_URL for the live HTTP test.'
        : false,
  );
}
