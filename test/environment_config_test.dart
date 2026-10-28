import 'package:civiltrust_app/core/config/app_config.dart';
import 'package:civiltrust_app/core/config/environment_check.dart';
import 'package:civiltrust_app/features/diagnostics/connectivity_service.dart';
import 'package:civiltrust_app/features/sessions/invite_url.dart';
import 'package:civiltrust_app/features/sessions/session_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

AppConfig staging({
  String coordinator = 'https://demo.test/coordinator',
  String notary = 'https://notary.test',
  bool notaryEnabled = false,
}) => AppConfig(
  coordinatorBaseUrl: coordinator,
  notaryBaseUrl: notary,
  rpcUrl: 'https://rpc.test',
  registryContract: '',
  chainId: 421614,
  environment: 'staging',
  notaryEnabled: notaryEnabled,
);

void main() {
  test(
    'native staging validates endpoints without requiring a browser origin',
    () {
      final issues = checkEnvironment(
        staging(),
        Uri.parse('file:///native-app'),
        isWeb: false,
      );
      expect(issues.where((e) => e.target == 'Trang Web'), isEmpty);
      expect(
        checkEnvironment(
          staging(),
          Uri.parse('file:///native-app'),
        ).where((e) => e.target == 'Trang Web'),
        isNotEmpty,
      );
    },
  );
  final page = Uri.parse(
    'https://demo.test/?tracking=discard#join=private-capability',
  );
  test('same-origin endpoints never inherit an invite or query', () {
    expect(
      AppConfig.resolveEndpoint('/coordinator', page),
      'https://demo.test/coordinator',
    );
    final config = staging(
      coordinator: AppConfig.resolveEndpoint('/coordinator', page),
    );
    expect(checkEnvironment(config, page), isEmpty);
    expect(endpointOrigin(config.coordinatorBaseUrl), 'https://demo.test');
    expect(
      AppConfig.resolveEndpoint('https://demo.test/', page),
      'https://demo.test',
    );
  });
  test('staging rejects loopback, HTTP, credentials and capability-bearing endpoints', () {
    for (final value in [
      'http://demo.test',
      'https://localhost',
      'https://[::1]',
      'https://127.0.0.2',
      'https://user:secret@demo.test',
      'https://demo.test?q=token',
      'https://demo.test#token',
      '//demo.test',
      'invalid',
    ]) {
      expect(
        checkEnvironment(staging(coordinator: value), page),
        isNotEmpty,
        reason: value,
      );
    }
    expect(
      checkEnvironment(staging(), Uri.parse('http://demo.test')),
      isNotEmpty,
    );
    expect(checkEnvironment(staging(notary: 'invalid'), page), isEmpty);
    expect(
      checkEnvironment(staging(notary: 'invalid', notaryEnabled: true), page),
      isNotEmpty,
    );
    final queryEndpoint = AppConfig.resolveEndpoint(
      '/coordinator?secret=value',
      page,
    );
    expect(
      checkEnvironment(staging(coordinator: queryEndpoint), page),
      isNotEmpty,
    );
    expect(
      endpointOrigin('https://demo.test?q=secret#capability'),
      'https://demo.test',
    );
    expect(endpointOrigin('https://user:secret@demo.test'), 'URL không hợp lệ');
  });
  test('local HTTP config is rejected on an HTTPS page', () {
    const local = AppConfig(
      coordinatorBaseUrl: 'http://localhost:8788',
      notaryBaseUrl: '',
      notaryEnabled: false,
      rpcUrl: 'https://rpc.test',
      registryContract: '',
      chainId: 421614,
    );
    expect(
      checkEnvironment(local, Uri.parse('http://localhost:8080')),
      isEmpty,
    );
    expect(checkEnvironment(local, page).single.target, 'Coordinator');
  });
  test(
    'invite round trips capabilities while stripping the old page query',
    () {
      final capability = SessionCapabilities(
        sessionId: 'session-demo',
        token: 'test-token',
        encryptionKey: List.filled(32, 1),
        isOwner: false,
      );
      final link = Uri.parse(
        buildInviteUrl(page, capability.toInviteFragment()),
      );
      expect(link.hasQuery, isFalse);
      final decoded = SessionCapabilities.fromInviteFragment(
        link.fragment.substring(5),
      );
      expect(decoded.token, capability.token);
      expect(decoded.encryptionKey, capability.encryptionKey);
      expect(link.removeFragment().toString(), 'https://demo.test/');
    },
  );
  test(
    'connectivity uses health only and skips notary when disabled',
    () async {
      var requests = 0;
      final service = ConnectivityService(
        client: MockClient((request) async {
          requests++;
          expect(
            request.url.toString(),
            'https://demo.test/coordinator/health',
          );
          expect(request.method, 'GET');
          expect(request.headers['authorization'], 'Bearer connectivity-check');
          expect(request.body, isEmpty);
          return http.Response(
            '{"status":"healthy","service":"app-coordinator"}',
            200,
          );
        }),
      );
      addTearDown(service.close);
      final results = await service.check(staging(), page);
      expect(results[0].status, ConnectionStatus.ready);
      expect(results[1].status, ConnectionStatus.disabled);
      expect(requests, 1);
    },
  );
  test('invalid config never makes a request; failures cannot leak endpoint secrets', () async {
    var requests = 0;
    final service = ConnectivityService(
      client: MockClient((request) async {
        requests++;
        throw http.ClientException('private-capability in exception');
      }),
    );
    addTearDown(service.close);
    final invalid = await service.check(
      staging(coordinator: 'http://localhost'),
      page,
    );
    expect(invalid.first.status, ConnectionStatus.failed);
    expect(requests, 0);
    final failed = await service.check(staging(), page);
    expect(failed.first.message, isNot(contains('private-capability')));
    expect(failed.first.status, ConnectionStatus.failed);
  });
  test('health rejects HTML, wrong services and HTTP failures', () async {
    for (final response in [
      http.Response('html', 200),
      http.Response('{"status":"healthy","service":"other"}', 200),
      http.Response('{}', 503),
    ]) {
      final service = ConnectivityService(
        client: MockClient((_) async => response),
      );
      expect(
        (await service.check(staging(), page)).first.status,
        ConnectionStatus.failed,
      );
      service.close();
    }
  });
  test('connectivity timeout stops waiting', () async {
    final service = ConnectivityService(
      timeout: const Duration(milliseconds: 1),
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response('{}', 200);
      }),
    );
    addTearDown(service.close);
    expect(
      (await service.check(staging(), page)).first.message,
      contains('Hết thời gian'),
    );
  });
}
