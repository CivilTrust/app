import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../../core/encoding/encoding_utils.dart';
import 'session_models.dart';

class SessionCipher {
  SessionCipher() : _cipher = AesGcm.with256bits();

  final AesGcm _cipher;

  Future<List<int>> createKey() async =>
      (await _cipher.newSecretKey()).extractBytes();

  Future<EncryptedEnvelope> encrypt(
    Map<String, Object?> value,
    List<int> key,
  ) async {
    final box = await _cipher.encrypt(
      utf8.encode(canonicalJson(value)),
      secretKey: SecretKey(key),
    );
    return EncryptedEnvelope(
      nonce: base64UrlNoPadding(box.nonce),
      ciphertext: base64UrlNoPadding(box.cipherText),
      mac: base64UrlNoPadding(box.mac.bytes),
    );
  }

  Future<Map<String, dynamic>> decrypt(
    EncryptedEnvelope envelope,
    List<int> key,
  ) async {
    final clear = await _cipher.decrypt(
      SecretBox(
        base64UrlDecodeNoPadding(envelope.ciphertext),
        nonce: base64UrlDecodeNoPadding(envelope.nonce),
        mac: Mac(base64UrlDecodeNoPadding(envelope.mac)),
      ),
      secretKey: SecretKey(key),
    );
    return jsonDecodeObject(utf8.decode(clear));
  }
}
