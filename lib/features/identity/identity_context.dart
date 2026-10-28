import 'dart:math';

import '../../core/encoding/encoding_utils.dart';

String createIdentityNonce() => base64UrlNoPadding(
  List<int>.generate(32, (_) => Random.secure().nextInt(256)),
);

/// A local ceremony challenge, NOT a trusted server attestation or live-chip proof.
class IdentityContext {
  const IdentityContext({
    required this.ceremonyId,
    required this.role,
    required this.challengeId,
    required this.issuedAt,
    required this.expiresAt,
  });

  factory IdentityContext.create({
    required String ceremonyId,
    required String role,
    DateTime? now,
  }) {
    final issued = (now ?? DateTime.now()).toUtc();
    return IdentityContext(
      ceremonyId: ceremonyId,
      role: role,
      challengeId: createIdentityNonce(),
      issuedAt: issued,
      expiresAt: issued.add(const Duration(minutes: 15)),
    );
  }

  factory IdentityContext.fromJson(Map<String, dynamic> json) {
    if (json.keys.toSet().difference({
      'ceremonyId',
      'role',
      'challengeId',
      'issuedAt',
      'expiresAt',
    }).isNotEmpty) {
      throw const FormatException('Unknown identity context field');
    }
    return IdentityContext(
      ceremonyId: json['ceremonyId'] as String,
      role: json['role'] as String,
      challengeId: json['challengeId'] as String,
      issuedAt: DateTime.parse(json['issuedAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }

  final String ceremonyId;
  final String role;
  final String challengeId;
  final DateTime issuedAt;
  final DateTime expiresAt;

  bool isValidAt(DateTime at) =>
      {'partyA', 'partyB'}.contains(role) &&
      RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(ceremonyId) &&
      RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(challengeId) &&
      expiresAt.isAfter(issuedAt) &&
      expiresAt.difference(issuedAt) <= const Duration(minutes: 15) &&
      !at.isBefore(issuedAt) &&
      at.isBefore(expiresAt);

  Map<String, Object?> toJson() => {
    'ceremonyId': ceremonyId,
    'role': role,
    'challengeId': challengeId,
    'issuedAt': issuedAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
  };
}
