import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/config/environment_check.dart';

enum ConnectionStatus { ready, failed, disabled }

class ConnectionResult {
  const ConnectionResult(this.target, this.status, this.message);
  final String target;
  final ConnectionStatus status;
  final String message;
}

class ConnectivityService {
  ConnectivityService({
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client();
  final http.Client _client;
  final Duration timeout;
  void close() => _client.close();

  Future<List<ConnectionResult>> check(
    AppConfig config,
    Uri pageUri, {
    bool isWeb = true,
  }) async {
    final issues = checkEnvironment(config, pageUri, isWeb: isWeb);
    return Future.wait([
      _probe(
        'Coordinator',
        config.coordinatorBaseUrl,
        issues,
        coordinator: true,
      ),
      if (config.notaryEnabled)
        _probe('Notary', config.notaryBaseUrl, issues)
      else
        Future.value(
          const ConnectionResult(
            'Notary',
            ConnectionStatus.disabled,
            'Đã tắt trong bản demo. Vẫn tạo ZIP offline, không có SCT.',
          ),
        ),
    ]);
  }

  Future<ConnectionResult> _probe(
    String target,
    String endpoint,
    List<EnvironmentIssue> issues, {
    bool coordinator = false,
  }) async {
    if (issues.any(
      (issue) =>
          issue.target == target ||
          issue.target == 'Trang Web' ||
          issue.target == 'Môi trường',
    )) {
      return ConnectionResult(
        target,
        ConnectionStatus.failed,
        'Cần sửa cấu hình URL trước khi kiểm kết nối.',
      );
    }
    try {
      final response = await _client
          .get(
            Uri.parse('${endpoint.replaceFirst(RegExp(r'/+$'), '')}/health'),
            // Fixed non-secret test value exercises browser preflight for the
            // same header names used by session requests; no session is created.
            headers: coordinator
                ? const {
                    'content-type': 'application/json',
                    'authorization': 'Bearer connectivity-check',
                  }
                : null,
          )
          .timeout(timeout);
      if (response.statusCode != 200) {
        return ConnectionResult(
          target,
          ConnectionStatus.failed,
          'Health trả HTTP ${response.statusCode}.',
        );
      }
      final Object? data = jsonDecode(response.body);
      if (data is! Map ||
          data['status'] != 'healthy' ||
          (coordinator && data['service'] != 'app-coordinator')) {
        return ConnectionResult(
          target,
          ConnectionStatus.failed,
          'Health không đúng định dạng dịch vụ mong đợi.',
        );
      }
      return ConnectionResult(
        target,
        ConnectionStatus.ready,
        coordinator
            ? 'Health hợp lệ; trình duyệt truy cập được với các header của API phiên. Chưa kiểm toàn bộ luồng A/B.'
            : 'Health hợp lệ. Chưa kiểm submit/SCT hoặc on-chain.',
      );
    } on TimeoutException {
      return ConnectionResult(
        target,
        ConnectionStatus.failed,
        'Hết thời gian kết nối. Kiểm tra server hoặc tunnel.',
      );
    } catch (_) {
      // Never echo URLs, capabilities or response bodies from exceptions.
      return ConnectionResult(
        target,
        ConnectionStatus.failed,
        'Không đọc được health. Kiểm tra mạng, HTTPS, CORS và định dạng JSON; trình duyệt không cho biết riêng nguyên nhân CORS.',
      );
    }
  }
}
