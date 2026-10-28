import 'package:civiltrust_app/features/sessions/invite_url.dart';
import 'package:civiltrust_app/features/sessions/session_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final capability = SessionCapabilities(
    sessionId: 'test-session',
    token: 'synthetic-token-123456',
    encryptionKey: List.filled(32, 7),
    isOwner: false,
  );
  test(
    'native paste accepts raw code, join code and full safe URL locally',
    () {
      final code = capability.toInviteFragment();
      for (final text in [
        code,
        'join=$code',
        'https://demo.test/#join=$code',
      ]) {
        expect(parseParticipantInvite(text).token, capability.token);
        expect(parseParticipantInvite(text).isOwner, isFalse);
      }
    },
  );
  test('rejects malformed, query, executable URL and oversized input without leaking it', () {
    final code = capability.toInviteFragment();
    for (final text in [
      '',
      '%%%SECRET%%%',
      'x' * 8193,
      'javascript:SECRET#join=$code',
      'https://user:SECRET@demo.test/#join=$code',
      'https://demo.test/?SECRET=1#join=$code',
      'https://demo.test/#join=$code#SECRET',
    ]) {
      try {
        parseParticipantInvite(text);
        fail('Accepted unsafe invite');
      } on FormatException catch (e) {
        expect(e.toString(), isNot(contains('SECRET')));
      }
    }
  });
  test('rejects owner privileges and invalid key length', () {
    for (final invalid in [
      SessionCapabilities(
        sessionId: 'id',
        token: capability.token,
        encryptionKey: capability.encryptionKey,
        isOwner: true,
      ),
      SessionCapabilities(
        sessionId: 'id',
        token: capability.token,
        encryptionKey: [1, 2],
        isOwner: false,
      ),
    ]) {
      expect(
        () => parseParticipantInvite(invalid.toInviteFragment()),
        throwsFormatException,
      );
    }
  });
}
