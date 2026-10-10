import 'dart:convert';

import '../../core/encoding/encoding_utils.dart';

class EncryptedEnvelope {
  const EncryptedEnvelope({
    required this.nonce,
    required this.ciphertext,
    required this.mac,
  });

  factory EncryptedEnvelope.fromJson(Map<String, dynamic> json) =>
      EncryptedEnvelope(
        nonce: json['nonce'] as String,
        ciphertext: json['ciphertext'] as String,
        mac: json['mac'] as String,
      );

  final String nonce;
  final String ciphertext;
  final String mac;

  Map<String, Object?> toJson() => {
    'nonce': nonce,
    'ciphertext': ciphertext,
    'mac': mac,
  };
}

class SessionCapabilities {
  const SessionCapabilities({
    required this.sessionId,
    required this.token,
    required this.encryptionKey,
    required this.isOwner,
  });

  final String sessionId;
  final String token;
  final List<int> encryptionKey;
  final bool isOwner;

  String toInviteFragment() {
    final value = canonicalJson({
      'id': sessionId,
      'token': token,
      'key': base64UrlNoPadding(encryptionKey),
      'owner': isOwner,
    });
    return base64UrlNoPadding(value.codeUnits);
  }

  factory SessionCapabilities.fromInviteFragment(String fragment) {
    final decoded = String.fromCharCodes(base64UrlDecodeNoPadding(fragment));
    final json = jsonDecodeObject(decoded);
    return SessionCapabilities(
      sessionId: json['id'] as String,
      token: json['token'] as String,
      encryptionKey: base64UrlDecodeNoPadding(json['key'] as String),
      isOwner: json['owner'] as bool? ?? false,
    );
  }
}

Map<String, dynamic> jsonDecodeObject(String value) {
  final decoded = jsonDecode(value);
  if (decoded is! Map) {
    throw const FormatException('Invite must contain an object');
  }
  return Map<String, dynamic>.from(decoded);
}

class RemoteSessionSnapshot<T> {
  const RemoteSessionSnapshot({
    required this.value,
    required this.version,
    required this.finalized,
    required this.expiresAt,
  });

  final T value;
  final int version;
  final bool finalized;
  final DateTime expiresAt;
}
