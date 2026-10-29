import '../../core/models/agreement.dart';

class EvidenceManifest {
  const EvidenceManifest({
    this.schema = currentSchema,
    required this.documentHash,
    required this.evidenceHash,
    required this.session,
    this.signedCommitment,
    this.merkleProof,
    this.signedSnapshotHash,
  });

  factory EvidenceManifest.fromJson(Map<String, dynamic> json) {
    final schema = json['schema'] as String? ?? legacySchema;
    if (schema != currentSchema &&
        schema != legacySchema &&
        schema != payerSchema) {
      throw FormatException('Phiên bản evidence không được hỗ trợ: $schema');
    }
    return EvidenceManifest(
      schema: schema,
      documentHash: json['documentHash'] as String,
      evidenceHash: json['evidenceHash'] as String,
      session: SigningSession.fromJson(
        Map<String, dynamic>.from(json['session'] as Map),
      ),
      signedCommitment: json['signedCommitment'] == null
          ? null
          : Map<String, dynamic>.from(json['signedCommitment'] as Map),
      merkleProof: (json['merkleProof'] as List?)?.cast<String>(),
      signedSnapshotHash: json['signedSnapshotHash'] as String?,
    );
  }

  static const legacySchema = 'civiltrust-evidence/1.0';
  static const currentSchema = 'civiltrust-evidence/2.0';
  static const payerSchema = 'civiltrust-evidence/3.0';

  final String schema;
  final String documentHash;
  final String evidenceHash;
  final SigningSession session;
  final Map<String, dynamic>? signedCommitment;
  final List<String>? merkleProof;
  final String? signedSnapshotHash;

  Map<String, Object?> toJson() => {
    'schema': schema,
    'documentHash': documentHash,
    'evidenceHash': evidenceHash,
    'session': session.toJson(),
    'signedCommitment': signedCommitment,
    'merkleProof': merkleProof,
    if (signedSnapshotHash != null) 'signedSnapshotHash': signedSnapshotHash,
  };
}
