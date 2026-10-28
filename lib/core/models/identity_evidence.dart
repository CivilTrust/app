import '../../features/identity/identity_context.dart';

enum IdentityAssurance {
  mock,
  read,
  dataAuthenticated,
  chipAuthenticated,
  failed,
}

class IdentityEvidence {
  const IdentityEvidence({
    required this.source,
    required this.displayName,
    required this.documentNumberMasked,
    required this.readAt,
    required this.chipAuthentication,
    required this.identityCommitment,
    this.attributes = const {},
    this.schemaVersion = 1,
    this.assurance = IdentityAssurance.mock,
    this.context,
    this.verifierId,
    this.policyVersion,
    this.proof,
  });

  factory IdentityEvidence.fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'] ?? 1;
    if (version != 1 && version != 2) {
      throw const FormatException('Unsupported identity evidence version');
    }
    if (version == 2 &&
        json.keys.toSet().difference({
          'source',
          'displayName',
          'documentNumberMasked',
          'readAt',
          'chipAuthentication',
          'identityCommitment',
          'attributes',
          'schemaVersion',
          'assurance',
          'context',
          'verifierId',
          'policyVersion',
          'proof',
          'holderCheck',
        }).isNotEmpty) {
      throw const FormatException('Unknown identity evidence field');
    }
    if (version == 2 && json['holderCheck'] != 'unchecked') {
      throw const FormatException('Holder verification is not implemented');
    }
    return IdentityEvidence(
      source: json['source'] as String,
      displayName: json['displayName'] as String,
      documentNumberMasked: json['documentNumberMasked'] as String,
      readAt: DateTime.parse(json['readAt'] as String),
      chipAuthentication: json['chipAuthentication'] as String,
      identityCommitment: json['identityCommitment'] as String,
      attributes: json['attributes'] == null
          ? const {}
          : Map<String, String>.unmodifiable(
              Map<String, String>.from(json['attributes'] as Map),
            ),
      schemaVersion: version as int,
      assurance: version == 1
          ? IdentityAssurance.mock
          : IdentityAssurance.values.byName(json['assurance'] as String),
      context: json['context'] == null
          ? null
          : IdentityContext.fromJson(
              Map<String, dynamic>.from(json['context'] as Map),
            ),
      verifierId: json['verifierId'] as String?,
      policyVersion: json['policyVersion'] as String?,
      proof: json['proof'] == null
          ? null
          : Map<String, dynamic>.from(json['proof'] as Map),
    );
  }

  final String source;
  final String displayName;
  final String documentNumberMasked;
  final DateTime readAt;
  final String chipAuthentication;
  final String identityCommitment;
  final Map<String, String> attributes;
  final int schemaVersion;
  final IdentityAssurance assurance;
  final IdentityContext? context;
  final String? verifierId;
  final String? policyVersion;
  final Map<String, dynamic>? proof;

  Map<String, Object?> toJson() => {
    'source': source,
    'displayName': displayName,
    'documentNumberMasked': documentNumberMasked,
    'readAt': readAt.toUtc().toIso8601String(),
    'chipAuthentication': chipAuthentication,
    'identityCommitment': identityCommitment,
    'attributes': attributes,
    if (schemaVersion == 2) ...{
      'schemaVersion': 2,
      'assurance': assurance.name,
      'context': context?.toJson(),
      'verifierId': verifierId,
      'policyVersion': policyVersion,
      'proof': proof,
      'holderCheck': 'unchecked',
    },
  };
}
