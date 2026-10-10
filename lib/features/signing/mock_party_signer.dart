import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../core/encoding/encoding_utils.dart';
import '../../core/models/identity_evidence.dart';
import '../../core/models/party_signature.dart';
import 'party_signer.dart';

/// Cryptographically verifiable demo signer.
///
/// Keys are ephemeral and are not evidence of a legal identity. The later iOS
/// implementation should replace this with a Keychain/Secure Enclave-backed
/// key and LocalAuthentication prompt while keeping the same interface.
class MockPartySigner implements PartySigner {
  MockPartySigner() : _algorithm = Ed25519();

  final Ed25519 _algorithm;

  @override
  Future<PartySignature> sign({
    required String role,
    required Uint8List digest,
    required IdentityEvidence identity,
  }) async {
    final keyPair = await _algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final signed = await _algorithm.sign(digest, keyPair: keyPair);
    return PartySignature(
      role: role,
      algorithm: 'Ed25519-demo-ephemeral',
      signedDigest: bytesToHex(digest),
      publicKey: base64UrlNoPadding(publicKey.bytes),
      signature: base64UrlNoPadding(signed.bytes),
      signedAt: DateTime.now().toUtc(),
      identity: Map<String, dynamic>.from(identity.toJson()),
    );
  }

  @override
  Future<bool> verify(PartySignature signature) async {
    if (!signature.algorithm.startsWith('Ed25519')) return false;
    try {
      final publicKey = SimplePublicKey(
        base64UrlDecodeNoPadding(signature.publicKey),
        type: KeyPairType.ed25519,
      );
      return await _algorithm.verify(
        hexToBytes(signature.signedDigest),
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
