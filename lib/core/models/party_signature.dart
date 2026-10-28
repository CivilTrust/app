class PartySignature {
  const PartySignature({
    required this.role,
    required this.algorithm,
    required this.signedDigest,
    required this.publicKey,
    required this.signature,
    required this.signedAt,
    required this.identity,
    this.schemaVersion = 1,
    this.envelope,
  });

  factory PartySignature.fromJson(Map<String, dynamic> json) => PartySignature(
    role: json['role'] as String,
    algorithm: json['algorithm'] as String,
    signedDigest: json['signedDigest'] as String,
    publicKey: json['publicKey'] as String,
    signature: json['signature'] as String,
    signedAt: DateTime.parse(json['signedAt'] as String),
    identity: Map<String, dynamic>.from(json['identity'] as Map),
    schemaVersion: json['schemaVersion'] as int? ?? 1,
    envelope: json['envelope'] == null
        ? null
        : Map<String, dynamic>.from(json['envelope'] as Map),
  );

  final String role;
  final String algorithm;
  final String signedDigest;
  final String publicKey;
  final String signature;
  final DateTime signedAt;
  final Map<String, dynamic> identity;
  final int schemaVersion;
  final Map<String, dynamic>? envelope;

  Map<String, Object?> toJson() => {
    'role': role,
    'algorithm': algorithm,
    'signedDigest': signedDigest,
    'publicKey': publicKey,
    'signature': signature,
    'signedAt': signedAt.toUtc().toIso8601String(),
    'identity': identity,
    if (schemaVersion != 1 || envelope != null) ...{
      'schemaVersion': schemaVersion,
      'envelope': envelope,
    },
  };
}
