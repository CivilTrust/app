import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../../core/crypto/hash_service.dart';
import '../../core/encoding/encoding_utils.dart';

/// Separate per-ceremony action key. Persist only inside the encrypted vault;
/// bind its public key in each party's signed identity evidence when signing.
class WorkflowKey {
  WorkflowKey(this.seed);
  final List<int> seed;
  final _algorithm = Ed25519();
  static Future<WorkflowKey> create() async {
    final key = await Ed25519().newKeyPair();
    return WorkflowKey(await key.extractPrivateKeyBytes());
  }

  Future<SimpleKeyPair> get _pair => _algorithm.newKeyPairFromSeed(seed);
  Future<String> get publicKey async =>
      base64UrlNoPadding((await (await _pair).extractPublicKey()).bytes);
  Future<String> sign(Map<String, Object?> body) async => base64UrlNoPadding(
    (await _algorithm.sign(
      utf8.encode(canonicalJson(body)),
      keyPair: await _pair,
    )).bytes,
  );

  static Future<bool> verify(
    Map<String, dynamic> body,
    String key,
    String signature,
  ) async {
    try {
      return await Ed25519().verify(
        utf8.encode(canonicalJson(body)),
        signature: Signature(
          base64UrlDecodeNoPadding(signature),
          publicKey: SimplePublicKey(
            base64UrlDecodeNoPadding(key),
            type: KeyPairType.ed25519,
          ),
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

String workflowEventHash(Map<String, dynamic> event) =>
    const HashService().canonicalObjectHash(event);
