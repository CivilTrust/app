class AppConfig {
  const AppConfig({
    required this.coordinatorBaseUrl,
    required this.notaryBaseUrl,
    required this.rpcUrl,
    required this.registryContract,
    required this.chainId,
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
  );

  final String coordinatorBaseUrl;
  final String notaryBaseUrl;
  final String rpcUrl;
  final String registryContract;
  final int chainId;

  bool get hasRegistry =>
      registryContract != '0x0000000000000000000000000000000000000000';
}
