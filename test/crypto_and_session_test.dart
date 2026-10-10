import 'package:civiltrust_app/core/crypto/hash_service.dart';
import 'package:civiltrust_app/core/encoding/encoding_utils.dart';
import 'package:civiltrust_app/core/ids/agreement_id.dart';
import 'package:civiltrust_app/features/identity/mock_identity_reader.dart';
import 'package:civiltrust_app/features/sessions/session_cipher.dart';
import 'package:civiltrust_app/features/sessions/session_models.dart';
import 'package:civiltrust_app/features/signing/mock_party_signer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('agreement id generation is safe for Flutter Web', () {
    final ids = List.generate(100, (_) => createAgreementId());
    expect(ids.toSet(), hasLength(ids.length));
    expect(
      ids.every((id) => RegExp(r'^\d+-[0-9a-f]{16}$').hasMatch(id)),
      isTrue,
    );
  });

  test('invite capability round-trips', () {
    const original = SessionCapabilities(
      sessionId: 'session-1',
      token: 'participant-token',
      encryptionKey: [1, 2, 3, 4],
      isOwner: false,
    );
    final decoded = SessionCapabilities.fromInviteFragment(
      original.toInviteFragment(),
    );
    expect(decoded.sessionId, original.sessionId);
    expect(decoded.token, original.token);
    expect(decoded.encryptionKey, original.encryptionKey);
    expect(decoded.isOwner, isFalse);
  });

  test('AES-GCM session envelope round-trips', () async {
    final cipher = SessionCipher();
    final key = await cipher.createKey();
    final encrypted = await cipher.encrypt({
      'hello': 'CivilTrust',
      'version': 1,
    }, key);
    expect(await cipher.decrypt(encrypted, key), {
      'hello': 'CivilTrust',
      'version': 1,
    });
  });

  test('mock party signature is verifiable', () async {
    final signer = MockPartySigner();
    final identity = await MockIdentityReader().read(role: 'partyA');
    final digest = const HashService().keccakBytes('agreement'.codeUnits);
    final signature = await signer.sign(
      role: 'partyA',
      digest: digest,
      identity: identity,
    );
    expect(signature.signedDigest, bytesToHex(digest));
    expect(await signer.verify(signature), isTrue);
  });
}
