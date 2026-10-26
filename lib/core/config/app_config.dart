import '../../features/notary/sct_verifier.dart';

class AppConfig {
  const AppConfig({
    required this.coordinatorBaseUrl,
    required this.notaryBaseUrl,
    required this.rpcUrl,
    required this.registryContract,
    required this.chainId,
    this.batchSigner = '',
    this.receiptSigner = '',
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
    coordinatorBaseUrl: String.fromEnvironment(
      'COORDINATOR_URL',
      defaultValue: 'http://localhost:8788',
    ),
    notaryBaseUrl: String.fromEnvironment(
      'NOTARY_URL',
      defaultValue: 'http://localhost:8787',
    ),
    rpcUrl: String.fromEnvironment(
      'ARBITRUM_RPC_URL',
      defaultValue: 'https://sepolia-rollup.arbitrum.io/rpc',
    ),
    registryContract: String.fromEnvironment(
      'REGISTRY_CONTRACT',
      defaultValue: '0x0000000000000000000000000000000000000000',
    ),
    chainId: int.fromEnvironment('CHAIN_ID', defaultValue: 421614),
    batchSigner: String.fromEnvironment('SCT_BATCH_SIGNER'),
    receiptSigner: String.fromEnvironment('SCT_RECEIPT_SIGNER'),
  );

  final String coordinatorBaseUrl;
  final String notaryBaseUrl;
  final String rpcUrl;
  final String registryContract;
  final int chainId;
  final String batchSigner;
  final String receiptSigner;

  bool get hasRegistry =>
      RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(registryContract) &&
      registryContract.toLowerCase() !=
          '0x0000000000000000000000000000000000000000';

  /// Null keeps SCT verification explicitly unconfigured until deployment
  /// details and at least one signer have been supplied by the team.
  SctTrustPolicy? get sctTrustPolicy {
    if (!hasRegistry || (batchSigner.isEmpty && receiptSigner.isEmpty)) {
      return null;
    }
    try {
      return SctTrustPolicy(
        chainId: chainId,
        verifyingContract: registryContract,
        trustedSigners: {
          if (batchSigner.isNotEmpty) batchSigner,
          if (receiptSigner.isNotEmpty) receiptSigner,
        },
      );
    } on FormatException {
      return null;
    }
  }
}
