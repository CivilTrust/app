import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../core/encoding/encoding_utils.dart';
import '../../core/models/identity_evidence.dart';
import '../../core/models/party_signature.dart';
import '../../core/crypto/hash_service.dart';
import '../identity/identity_reader.dart';
import 'party_signer.dart';
import 'signing_context.dart';

/// Cryptographically verifiable demo signer.
///
/// Keys are ephemeral and are not evidence of a legal identity. The later iOS
/// implementation should replace this with a Keychain/Secure Enclave-backed
/// key and LocalAuthentication prompt while keeping the same interface.
class MockPartySigner implements PartySigner {
  MockPartySigner({DateTime Function()? clock})
    : _algorithm = Ed25519(),
      _clock = clock ?? DateTime.now;

  final Ed25519 _algorithm;
  final DateTime Function() _clock;
  final _hash = const HashService();
  // Local demo guard only; cross-device/global replay protection needs a trusted
  // challenge issuer/consumer. This set is deliberately NOT an online guarantee.
  final Set<String> _consumedChallenges = {};

  @override
  Future<PartySignature> sign({
    required String role,
    required Uint8List digest,
    required IdentityEvidence identity,
    SigningContext? context,
  }) async {
    if (identity.source != 'mock' ||
        identity.chipAuthentication != 'mock' ||
        identity.assurance != IdentityAssurance.mock ||
        identity.proof != null) {
      throw const IdentityReaderException(
        'Demo signer không ký danh tính NFC thật.',
        code: IdentityErrorCode.authenticationFailed,
      );
    }
    final signedAt = _clock().toUtc();
    if (context != null) {
      final binding = identity.context;
      if (identity.schemaVersion != 2 ||
          binding == null ||
          binding.role != role ||
          binding.ceremonyId != context.ceremonyId ||
          !binding.isValidAt(signedAt) ||
          identity.readAt.isBefore(binding.issuedAt) ||
          identity.readAt.isAfter(signedAt) ||
          context.agreementId.isEmpty ||
          digest.length != 32) {
        throw const IdentityReaderException(
          'Context danh tính không khớp hoặc đã hết hạn.',
          code: IdentityErrorCode.expired,
        );
      }
      if (!_consumedChallenges.add(binding.challengeId)) {
        throw const IdentityReaderException(
          'Challenge đã được dùng để ký trên thiết bị này.',
          code: IdentityErrorCode.replay,
        );
      }
    } else if (identity.schemaVersion != 1) {
      throw const FormatException(
        'Evidence v2 bắt buộc dùng signing context v2.',
      );
    }
    final keyPair = await _algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final identityJson = Map<String, dynamic>.from(identity.toJson());
    final Map<String, dynamic>? envelope = context == null
        ? null
        : {
            'domain': SigningContext.protocol,
            'agreementId': context.agreementId,
            'ceremonyId': context.ceremonyId,
            'role': role,
            'draftDigest': bytesToHex(digest),
            'identityHash': _hash.canonicalObjectHash(identityJson),
            'publicKeyFingerprint': _hash.keccakHex(publicKey.bytes),
            'challenge': identity.context!.toJson(),
            'signedAt': signedAt.toIso8601String(),
            'algorithm': 'Ed25519-demo-ephemeral-v2',
          };
    final message = envelope == null
        ? digest
        : hexToBytes(_hash.canonicalObjectHash(envelope));
    final signed = await _algorithm.sign(message, keyPair: keyPair);
    return PartySignature(
      role: role,
      algorithm: context == null
          ? 'Ed25519-demo-ephemeral'
          : 'Ed25519-demo-ephemeral-v2',
      signedDigest: bytesToHex(digest),
      publicKey: base64UrlNoPadding(publicKey.bytes),
      signature: base64UrlNoPadding(signed.bytes),
      signedAt: signedAt,
      identity: identityJson,
      schemaVersion: context == null ? 1 : 2,
      envelope: envelope,
    );
  }

  @override
  Future<bool> verify(PartySignature signature) async {
    try {
      Uint8List message;
      if (signature.schemaVersion == 1) {
        if (signature.algorithm != 'Ed25519-demo-ephemeral' ||
            signature.envelope != null) {
          return false;
        }
        message = hexToBytes(signature.signedDigest);
      } else if (signature.schemaVersion == 2) {
        if (signature.algorithm != 'Ed25519-demo-ephemeral-v2') return false;
        final evidence = IdentityEvidence.fromJson(signature.identity);
        final binding = evidence.context;
        final envelope = signature.envelope;
        if (evidence.schemaVersion != 2 ||
            evidence.source != 'mock' ||
            evidence.chipAuthentication != 'mock' ||
            evidence.assurance != IdentityAssurance.mock ||
            evidence.proof != null ||
            binding == null ||
            envelope == null ||
            !binding.isValidAt(signature.signedAt) ||
            evidence.readAt.isBefore(binding.issuedAt) ||
            evidence.readAt.isAfter(signature.signedAt) ||
            binding.role != signature.role) {
          return false;
        }
        final expected = <String, dynamic>{
          'domain': SigningContext.protocol,
          'agreementId': envelope['agreementId'],
          'ceremonyId': binding.ceremonyId,
          'role': signature.role,
          'draftDigest': signature.signedDigest,
          'identityHash': _hash.canonicalObjectHash(signature.identity),
          'publicKeyFingerprint': _hash.keccakHex(
            base64UrlDecodeNoPadding(signature.publicKey),
          ),
          'challenge': binding.toJson(),
          'signedAt': signature.signedAt.toUtc().toIso8601String(),
          'algorithm': signature.algorithm,
        };
        if (envelope['agreementId'] is! String ||
            (envelope['agreementId'] as String).isEmpty ||
            canonicalJson(envelope) != canonicalJson(expected)) {
          return false;
        }
        message = hexToBytes(_hash.canonicalObjectHash(envelope));
      } else {
        return false;
      }
      final publicKey = SimplePublicKey(
        base64UrlDecodeNoPadding(signature.publicKey),
        type: KeyPairType.ed25519,
      );
      return await _algorithm.verify(
        message,
        signature: Signature(
          base64UrlDecodeNoPadding(signature.signature),
          publicKey: publicKey,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
