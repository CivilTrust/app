class IdentityEvidence {
  const IdentityEvidence({
    required this.source,
    required this.displayName,
    required this.documentNumberMasked,
    required this.readAt,
    required this.chipAuthentication,
    required this.identityCommitment,
    this.attributes = const {},
  });

  factory IdentityEvidence.fromJson(Map<String, dynamic> json) =>
      IdentityEvidence(
        source: json['source'] as String,
        displayName: json['displayName'] as String,
        documentNumberMasked: json['documentNumberMasked'] as String,
        readAt: DateTime.parse(json['readAt'] as String),
        chipAuthentication: json['chipAuthentication'] as String,
        identityCommitment: json['identityCommitment'] as String,
        attributes: json['attributes'] == null
            ? const {}
            : Map<String, String>.from(json['attributes'] as Map),
      );

  final String source;
  final String displayName;
  final String documentNumberMasked;
  final DateTime readAt;
  final String chipAuthentication;
  final String identityCommitment;
  final Map<String, String> attributes;

  Map<String, Object?> toJson() => {
    'source': source,
    'displayName': displayName,
    'documentNumberMasked': documentNumberMasked,
    'readAt': readAt.toUtc().toIso8601String(),
    'chipAuthentication': chipAuthentication,
    'identityCommitment': identityCommitment,
    'attributes': attributes,
  };
}
