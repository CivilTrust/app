import 'dart:convert';

import 'package:civiltrust_app/core/config/app_config.dart';
import 'package:civiltrust_app/features/artifacts/verify_bundle_page.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/sct_viem_v1_3_0.dart';

void main() {
  final original = Map<String, dynamic>.from(
    sctViemFixture['sct']! as Map<String, Object>,
  );
  final hash =
      (original['message'] as Map<String, Object>)['agreementHash']! as String;
  final signer = original['signer']! as String;

  AppConfig config({
    String registry = '0x0000000000000000000000000000000000000000',
    String batchSigner = '',
    String receiptSigner = '',
  }) => AppConfig(
    coordinatorBaseUrl: '',
    notaryBaseUrl: '',
    rpcUrl: '',
    registryContract: registry,
    chainId: 421614,
    batchSigner: batchSigner,
    receiptSigner: receiptSigner,
  );

  Map<String, dynamic> clone() =>
      jsonDecode(jsonEncode(original)) as Map<String, dynamic>;

  test(
    'runtime trust is absent until deployment address and signer arrive',
    () {
      expect(config().sctTrustPolicy, isNull);
      expect(config(batchSigner: signer).sctTrustPolicy, isNull);
      expect(
        config(registry: 'invalid', batchSigner: signer).hasRegistry,
        isFalse,
      );
      expect(
        config(registry: 'invalid', batchSigner: signer).sctTrustPolicy,
        isNull,
      );

      final ready = config(
        registry: '0x1234567890123456789012345678901234567890',
        receiptSigner: signer,
      );
      expect(ready.sctTrustPolicy, isNotNull);
      expect(
        ready.sctTrustPolicy!.trustedSigners,
        contains(signer.toLowerCase()),
      );
    },
  );

  test('ZIP SCT row distinguishes missing and unconfigured', () {
    expect(
      sctVerificationResultFor(
        null,
        documentHash: hash,
        config: config(),
      ).level,
      VerificationLevel.unavailable,
    );
    final pending = sctVerificationResultFor(
      original,
      documentHash: hash,
      config: config(),
    );
    expect(pending.level, VerificationLevel.notConfigured);
    expect(pending.detail, contains('chưa có địa chỉ contract'));
  });

  test('ZIP SCT row verifies Viem signer only against configured policy', () {
    final trusted = config(
      registry: '0x1234567890123456789012345678901234567890',
      batchSigner: signer,
    );
    final valid = sctVerificationResultFor(
      original,
      documentHash: hash,
      config: trusted,
    );
    expect(valid.level, VerificationLevel.valid);
    expect(valid.detail, contains('Chưa kiểm Merkle proof hoặc blockchain'));

    final wrongSigner = config(
      registry: '0x1234567890123456789012345678901234567890',
      receiptSigner: '0x3333333333333333333333333333333333333333',
    );
    expect(
      sctVerificationResultFor(
        original,
        documentHash: hash,
        config: wrongSigner,
      ).level,
      VerificationLevel.invalid,
    );
  });

  test('ZIP SCT row rejects altered hash and malformed signature', () {
    final changedHash = sctVerificationResultFor(
      original,
      documentHash:
          '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      config: config(),
    );
    expect(changedHash.level, VerificationLevel.invalid);

    final malformed = clone()..['signature'] = '0x1234';
    expect(
      sctVerificationResultFor(
        malformed,
        documentHash: hash,
        config: config(),
      ).level,
      VerificationLevel.invalid,
    );
  });

  test('ZIP SCT row reports newer schema as unsupported', () {
    final newer = clone()..['version'] = '2.0.0';
    expect(
      sctVerificationResultFor(
        newer,
        documentHash: hash,
        config: config(),
      ).level,
      VerificationLevel.unsupported,
    );
  });
}
