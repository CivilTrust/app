import 'dart:convert';

import 'package:civiltrust_app/core/crypto/hash_service.dart';
import 'package:civiltrust_app/core/encoding/encoding_utils.dart';
import 'package:civiltrust_app/features/notary/sct_verifier.dart';
import 'package:civiltrust_app/features/notary/signed_commitment_token.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/sct_viem_v1_3_0.dart';

void main() {
  final fixture =
      jsonDecode(jsonEncode(sctViemFixture)) as Map<String, dynamic>;
  final original = Map<String, dynamic>.from(
    fixture['sct'] as Map<String, dynamic>,
  );
  final hash =
      (original['message'] as Map<String, dynamic>)['agreementHash']! as String;
  final signer = original['signer']! as String;
  final verifier = const SctVerifier();
  final policy = SctTrustPolicy(
    chainId: 421614,
    verifyingContract: '0x1234567890123456789012345678901234567890',
    trustedSigners: {signer},
  );

  Map<String, dynamic> cloneFixture() =>
      jsonDecode(jsonEncode(original)) as Map<String, dynamic>;

  test('matches Viem EIP-712 digest and recovers its signer', () {
    final sct = SignedCommitmentToken.fromJson(original);
    expect(bytesToHex(verifier.typedDataDigest(sct)), fixture['digest']);

    final result = verifier.verify(sct, documentHash: hash, policy: policy);
    expect(result.status, SctVerificationStatus.valid);
    expect(result.recoveredSigner, signer.toLowerCase());
    expect(result.digest, fixture['digest']);
  });

  test('recovers a valid signature when signer metadata is absent', () {
    final withoutSigner = cloneFixture()..remove('signer');
    final result = verifier.verifyJson(
      withoutSigner,
      documentHash: hash,
      policy: policy,
    );
    expect(result.status, SctVerificationStatus.valid);
    expect(result.recoveredSigner, signer.toLowerCase());
  });

  test('reports notConfigured only after cryptographic recovery succeeds', () {
    final result = verifier.verifyJson(original, documentHash: hash);
    expect(result.status, SctVerificationStatus.notConfigured);
    expect(result.recoveredSigner, signer.toLowerCase());
    expect(result.digest, fixture['digest']);
  });

  test('rejects a changed PDF hash and every signed message field', () {
    final documentBytes = utf8.encode('civiltrust-app-viem-fixture');
    expect(const HashService().keccakHex(documentBytes), hash);
    final changedBytes = [...documentBytes]..[documentBytes.length - 1] ^= 0x01;
    final changedDocumentHash = const HashService().keccakHex(changedBytes);
    final changedPdf = verifier.verifyJson(
      original,
      documentHash: changedDocumentHash,
      policy: policy,
    );
    expect(changedPdf.status, SctVerificationStatus.invalid);

    for (final mutation in <void Function(Map<String, dynamic>)>[
      (json) => (json['message'] as Map<String, dynamic>)['agreementHash'] =
          '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      (json) => (json['message'] as Map<String, dynamic>)['dateKey'] = 20261029,
      (json) =>
          (json['message'] as Map<String, dynamic>)['timestamp'] = 1793145601,
      (json) => (json['message'] as Map<String, dynamic>)['nonce'] =
          '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    ]) {
      final changed = cloneFixture();
      mutation(changed);
      final changedHash =
          (changed['message'] as Map<String, dynamic>)['agreementHash']!
              as String;
      expect(
        verifier
            .verifyJson(changed, documentHash: changedHash, policy: policy)
            .status,
        SctVerificationStatus.invalid,
      );
    }
  });

  test('rejects changed deployment domain and an untrusted signer', () {
    final changedChain = cloneFixture();
    (changedChain['domain'] as Map<String, dynamic>)['chainId'] = 42161;
    final changedChainResult = verifier.verifyJson(
      changedChain,
      documentHash: hash,
      policy: policy,
    );
    expect(changedChainResult.status, SctVerificationStatus.invalid);
    expect(changedChainResult.reason, contains('configured deployment'));

    final changedContract = cloneFixture();
    (changedContract['domain'] as Map<String, dynamic>)['verifyingContract'] =
        '0x2222222222222222222222222222222222222222';
    final changedContractResult = verifier.verifyJson(
      changedContract,
      documentHash: hash,
      policy: policy,
    );
    expect(changedContractResult.status, SctVerificationStatus.invalid);
    expect(changedContractResult.reason, contains('configured deployment'));

    final wrongPolicy = SctTrustPolicy(
      chainId: 421614,
      verifyingContract: '0x1234567890123456789012345678901234567890',
      trustedSigners: {'0x3333333333333333333333333333333333333333'},
    );
    expect(
      verifier
          .verifyJson(original, documentHash: hash, policy: wrongPolicy)
          .status,
      SctVerificationStatus.invalid,
    );
  });

  test('does not trust self-declared signer metadata', () {
    final changed = cloneFixture()
      ..['signer'] = '0x3333333333333333333333333333333333333333';
    final result = verifier.verifyJson(
      changed,
      documentHash: hash,
      policy: SctTrustPolicy(
        chainId: 421614,
        verifyingContract: '0x1234567890123456789012345678901234567890',
        trustedSigners: {signer},
      ),
    );
    expect(result.status, SctVerificationStatus.invalid);
    expect(result.recoveredSigner, signer.toLowerCase());
  });

  test('distinguishes unsupported schema from malformed signatures', () {
    final unsupported = cloneFixture()..['version'] = '2.0.0';
    expect(
      verifier.verifyJson(unsupported, documentHash: hash).status,
      SctVerificationStatus.unsupported,
    );

    final shortSignature = cloneFixture()..['signature'] = '0x1234';
    expect(
      verifier.verifyJson(shortSignature, documentHash: hash).status,
      SctVerificationStatus.invalid,
    );

    final badRecoveryId = cloneFixture();
    final signature = badRecoveryId['signature']! as String;
    badRecoveryId['signature'] = '${signature.substring(0, 130)}00';
    expect(
      verifier
          .verifyJson(badRecoveryId, documentHash: hash, policy: policy)
          .status,
      SctVerificationStatus.invalid,
    );
  });

  test('rejects unsupported EIP-712 domain name and version', () {
    for (final entry in [('name', 'OtherRegistry'), ('version', '2')]) {
      final changed = cloneFixture();
      (changed['domain'] as Map<String, dynamic>)[entry.$1] = entry.$2;
      expect(
        verifier.verifyJson(changed, documentHash: hash).status,
        SctVerificationStatus.unsupported,
      );
    }
  });
}
