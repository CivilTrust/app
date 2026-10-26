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
    this.environment = 'local',
    this.notaryEnabled = true,
  });

  factory AppConfig.fromEnvironment({Uri? pageUri}) => AppConfig(
    coordinatorBaseUrl: resolveEndpoint(
      const String.fromEnvironment(
        'COORDINATOR_URL',
        defaultValue: 'http://localhost:8788',
      ),
      pageUri ?? Uri.base,
    ),
    notaryBaseUrl: resolveEndpoint(
      const String.fromEnvironment(
        'NOTARY_URL',
        defaultValue: 'http://localhost:8787',
      ),
      pageUri ?? Uri.base,
    ),
    rpcUrl: const String.fromEnvironment(
      'ARBITRUM_RPC_URL',
      defaultValue: 'https://sepolia-rollup.arbitrum.io/rpc',
    ),
    registryContract: const String.fromEnvironment(
      'REGISTRY_CONTRACT',
      defaultValue: '0x0000000000000000000000000000000000000000',
    ),
    chainId: const int.fromEnvironment('CHAIN_ID', defaultValue: 421614),
    batchSigner: const String.fromEnvironment('SCT_BATCH_SIGNER'),
    receiptSigner: const String.fromEnvironment('SCT_RECEIPT_SIGNER'),
    environment: const String.fromEnvironment('APP_ENV', defaultValue: 'local'),
    notaryEnabled: const bool.fromEnvironment(
      'NOTARY_ENABLED',
      defaultValue: true,
    ),
  );

  final String coordinatorBaseUrl;
  final String notaryBaseUrl;
  final String rpcUrl;
  final String registryContract;
  final int chainId;
  final String batchSigner;
  final String receiptSigner;
  final String environment;
  final bool notaryEnabled;

  /// Only root-relative endpoints are supported. Never inherit an invite's
  /// query or fragment when constructing a network endpoint.
  static String resolveEndpoint(String value, Uri pageUri) {
    if (!value.startsWith('/') || value.startsWith('//')) {
      return value.replaceFirst(RegExp(r'/+$'), '');
    }
    final relative = Uri.tryParse(value);
    if (relative == null) return value;
    return Uri(
      scheme: pageUri.scheme,
      host: pageUri.host,
      port: pageUri.hasPort ? pageUri.port : null,
      path: relative.path.replaceFirst(RegExp(r'/+$'), ''),
      query: relative.hasQuery ? relative.query : null,
      fragment: relative.hasFragment ? relative.fragment : null,
    ).toString();
  }

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
