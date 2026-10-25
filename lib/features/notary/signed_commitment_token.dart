/// The service's EIP-712 Receipt payload. Parsing checks its shape; signature
/// recovery and trust in the signer are separate verification steps.
class SignedCommitmentToken {
  SignedCommitmentToken._({
    required this.version,
    required this.domain,
    required this.message,
    required this.signer,
    required this.signature,
  });

  factory SignedCommitmentToken.fromJson(Object? value) {
    final json = _object(value, 'sct');
    final version = _string(json, 'version');
    if (version != '1.3.0') {
      throw UnsupportedError('Unsupported SCT version: $version');
    }
    return SignedCommitmentToken._(
      version: version,
      domain: SctDomain.fromJson(json['domain']),
      message: SctReceipt.fromJson(json['message']),
      signer: !json.containsKey('signer')
          ? null
          : _hex(_string(json, 'signer'), 20, 'sct.signer'),
      signature: _hex(_string(json, 'signature'), 65, 'sct.signature'),
    );
  }

  final String version;
  final SctDomain domain;
  final SctReceipt message;

  /// Optional because the service's idempotent HTTP 200 response omits it.
  final String? signer;
  final String signature;

  bool matchesAgreementHash(String hash) =>
      message.agreementHash.toLowerCase() == hash.toLowerCase();

  Map<String, dynamic> toJson() => {
    'version': version,
    'domain': domain.toJson(),
    'message': message.toJson(),
    if (signer != null) 'signer': signer,
    'signature': signature,
  };
}

class SctDomain {
  SctDomain._(this.name, this.version, this.chainId, this.verifyingContract);

  factory SctDomain.fromJson(Object? value) {
    final json = _object(value, 'sct.domain');
    final name = _string(json, 'name');
    final version = _string(json, 'version');
    if (name != 'CivilTrustRegistry' || version != '1') {
      throw UnsupportedError('Unsupported SCT EIP-712 domain: $name/$version');
    }
    return SctDomain._(
      name,
      version,
      _positiveInt(json, 'chainId'),
      _hex(
        _string(json, 'verifyingContract'),
        20,
        'sct.domain.verifyingContract',
      ),
    );
  }

  final String name;
  final String version;
  final int chainId;
  final String verifyingContract;

  Map<String, dynamic> toJson() => {
    'name': name,
    'version': version,
    'chainId': chainId,
    'verifyingContract': verifyingContract,
  };
}

class SctReceipt {
  SctReceipt._(this.agreementHash, this.dateKey, this.timestamp, this.nonce);

  factory SctReceipt.fromJson(Object? value) {
    final json = _object(value, 'sct.message');
    final dateKey = _positiveInt(json, 'dateKey');
    if (dateKey < 10000101 || dateKey > 99991231) {
      throw const FormatException('sct.message.dateKey must be YYYYMMDD');
    }
    return SctReceipt._(
      _hex(_string(json, 'agreementHash'), 32, 'sct.message.agreementHash'),
      dateKey,
      _positiveInt(json, 'timestamp'),
      _hex(_string(json, 'nonce'), 32, 'sct.message.nonce'),
    );
  }

  final String agreementHash;
  final int dateKey;
  final int timestamp;
  final String nonce;

  Map<String, dynamic> toJson() => {
    'agreementHash': agreementHash,
    'dateKey': dateKey,
    'timestamp': timestamp,
    'nonce': nonce,
  };
}

Map<String, dynamic> _object(Object? value, String field) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('$field must be a JSON object');
  }
  return value;
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value;
}

int _positiveInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value <= 0) {
    throw FormatException('$key must be a positive integer');
  }
  return value;
}

String _hex(String value, int bytes, String field) {
  if (!RegExp('^0x[0-9a-fA-F]{${bytes * 2}}\$').hasMatch(value)) {
    throw FormatException('$field must be a $bytes-byte hex string');
  }
  return value;
}
