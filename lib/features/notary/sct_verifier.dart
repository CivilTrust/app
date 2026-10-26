import 'dart:convert';
import 'dart:typed_data';

import 'package:web3dart/web3dart.dart' as web3;

import '../../core/crypto/hash_service.dart';
import '../../core/encoding/encoding_utils.dart';
import 'signed_commitment_token.dart';

enum SctVerificationStatus { valid, invalid, unsupported, notConfigured }

class SctVerificationResult {
  const SctVerificationResult({
    required this.status,
    required this.reason,
    this.digest,
    this.recoveredSigner,
  });

  final SctVerificationStatus status;
  final String reason;
  final String? digest;
  final String? recoveredSigner;

  bool get isValid => status == SctVerificationStatus.valid;
}

/// Trust configuration for one immutable registry deployment.
///
/// Signers must come from deployment/configuration, never from the SCT itself.
class SctTrustPolicy {
  SctTrustPolicy({
    required this.chainId,
    required String verifyingContract,
    required Set<String> trustedSigners,
  }) : verifyingContract = _address(verifyingContract, 'verifyingContract'),
       trustedSigners = Set.unmodifiable(
         trustedSigners.map((value) => _address(value, 'trustedSigner')),
       ) {
    if (chainId <= 0) {
      throw const FormatException('chainId must be positive');
    }
    if (this.trustedSigners.isEmpty) {
      throw const FormatException('At least one trusted signer is required');
    }
  }

  final int chainId;
  final String verifyingContract;
  final Set<String> trustedSigners;
}

class SctVerifier {
  const SctVerifier({this._hash = const HashService()});

  static const domainType =
      'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)';
  static const receiptType =
      'Receipt(bytes32 agreementHash,uint256 dateKey,uint64 timestamp,bytes32 nonce)';

  static final BigInt _curveOrder = BigInt.parse(
    'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141',
    radix: 16,
  );
  static final BigInt _halfCurveOrder = _curveOrder >> 1;

  final HashService _hash;

  /// Parses an untrusted sidecar value and reports unsupported schemas without
  /// attempting signature recovery.
  SctVerificationResult verifyJson(
    Object? value, {
    required String documentHash,
    SctTrustPolicy? policy,
  }) {
    try {
      return verify(
        SignedCommitmentToken.fromJson(value),
        documentHash: documentHash,
        policy: policy,
      );
    } on UnsupportedError catch (error) {
      return SctVerificationResult(
        status: SctVerificationStatus.unsupported,
        reason: error.message?.toString() ?? 'Unsupported SCT format',
      );
    } on FormatException catch (error) {
      return SctVerificationResult(
        status: SctVerificationStatus.invalid,
        reason: error.message.toString(),
      );
    }
  }

  SctVerificationResult verify(
    SignedCommitmentToken sct, {
    required String documentHash,
    SctTrustPolicy? policy,
  }) {
    if (!_isBytes(documentHash, 32)) {
      return const SctVerificationResult(
        status: SctVerificationStatus.invalid,
        reason: 'PDF hash must be a 32-byte hex string',
      );
    }
    if (!sct.matchesAgreementHash(documentHash)) {
      return const SctVerificationResult(
        status: SctVerificationStatus.invalid,
        reason: 'SCT agreementHash does not match the PDF hash',
      );
    }
    if (policy != null &&
        (sct.domain.chainId != policy.chainId ||
            sct.domain.verifyingContract.toLowerCase() !=
                policy.verifyingContract)) {
      return const SctVerificationResult(
        status: SctVerificationStatus.invalid,
        reason: 'SCT domain does not match the configured deployment',
      );
    }

    late final Uint8List digest;
    late final String recovered;
    try {
      digest = typedDataDigest(sct);
      recovered = _recoverSigner(digest, sct.signature);
    } on FormatException catch (error) {
      return SctVerificationResult(
        status: SctVerificationStatus.invalid,
        reason: error.message.toString(),
      );
    } catch (_) {
      return const SctVerificationResult(
        status: SctVerificationStatus.invalid,
        reason: 'ECDSA public-key recovery failed',
      );
    }

    final digestHex = bytesToHex(digest);
    if (sct.signer != null && sct.signer!.toLowerCase() != recovered) {
      return SctVerificationResult(
        status: SctVerificationStatus.invalid,
        reason: 'SCT signer metadata does not match the recovered signer',
        digest: digestHex,
        recoveredSigner: recovered,
      );
    }

    if (policy == null) {
      return SctVerificationResult(
        status: SctVerificationStatus.notConfigured,
        reason: 'Signature recovered, but no trusted deployment is configured',
        digest: digestHex,
        recoveredSigner: recovered,
      );
    }
    if (!policy.trustedSigners.contains(recovered)) {
      return SctVerificationResult(
        status: SctVerificationStatus.invalid,
        reason: 'Recovered signer is not trusted for this deployment',
        digest: digestHex,
        recoveredSigner: recovered,
      );
    }

    return SctVerificationResult(
      status: SctVerificationStatus.valid,
      reason: 'EIP-712 signature and configured signer are valid',
      digest: digestHex,
      recoveredSigner: recovered,
    );
  }

  Uint8List typedDataDigest(SignedCommitmentToken sct) {
    final domainSeparator = _hash.keccakBytes([
      ..._typeHash(domainType),
      ..._hash.keccakBytes(utf8.encode(sct.domain.name)),
      ..._hash.keccakBytes(utf8.encode(sct.domain.version)),
      ...uint256Bytes(BigInt.from(sct.domain.chainId)),
      ..._addressWord(sct.domain.verifyingContract),
    ]);
    final structHash = _hash.keccakBytes([
      ..._typeHash(receiptType),
      ...hexToBytes(sct.message.agreementHash),
      ...uint256Bytes(BigInt.from(sct.message.dateKey)),
      ...uint256Bytes(BigInt.from(sct.message.timestamp)),
      ...hexToBytes(sct.message.nonce),
    ]);
    return _hash.keccakBytes([0x19, 0x01, ...domainSeparator, ...structHash]);
  }

  Uint8List _typeHash(String type) => _hash.keccakBytes(utf8.encode(type));

  Uint8List _addressWord(String value) {
    final address = hexToBytes(value);
    return Uint8List(32)..setRange(12, 32, address);
  }

  String _recoverSigner(Uint8List digest, String encodedSignature) {
    final bytes = hexToBytes(encodedSignature);
    if (bytes.length != 65) {
      throw const FormatException('ECDSA signature must be 65 bytes');
    }
    final r = _unsigned(bytes.sublist(0, 32));
    final s = _unsigned(bytes.sublist(32, 64));
    final v = bytes[64];
    if (r <= BigInt.zero || r >= _curveOrder) {
      throw const FormatException('ECDSA r is out of range');
    }
    if (s <= BigInt.zero || s > _halfCurveOrder) {
      throw const FormatException('ECDSA s is not canonical');
    }
    if (v != 27 && v != 28) {
      throw const FormatException('ECDSA recovery id must be 27 or 28');
    }
    var publicKey = web3.ecRecover(digest, web3.MsgSignature(r, s, v));
    if (publicKey.length > 64) {
      publicKey = Uint8List.fromList(publicKey.sublist(publicKey.length - 64));
    } else if (publicKey.length < 64) {
      final padded = Uint8List(64);
      padded.setRange(64 - publicKey.length, 64, publicKey);
      publicKey = padded;
    }
    return bytesToHex(web3.publicKeyToAddress(publicKey)).toLowerCase();
  }

  BigInt _unsigned(List<int> bytes) =>
      BigInt.parse(bytesToHex(bytes, include0x: false), radix: 16);
}

bool _isBytes(String value, int length) =>
    RegExp('^0x[0-9a-fA-F]{${length * 2}}\$').hasMatch(value);

String _address(String value, String field) {
  if (!_isBytes(value, 20)) {
    throw FormatException('$field must be a 20-byte hex address');
  }
  return value.toLowerCase();
}
