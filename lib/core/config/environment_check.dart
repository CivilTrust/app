import 'app_config.dart';

class EnvironmentIssue {
  const EnvironmentIssue(this.target, this.message);
  final String target;
  final String message;
}

List<EnvironmentIssue> checkEnvironment(AppConfig config, Uri pageUri) {
  final issues = <EnvironmentIssue>[];
  if (!{'local', 'staging'}.contains(config.environment)) {
    issues.add(
      const EnvironmentIssue(
        'Môi trường',
        'APP_ENV phải là local hoặc staging.',
      ),
    );
  }
  final staging = config.environment == 'staging';
  if (staging && (pageUri.scheme != 'https' || isLoopback(pageUri.host))) {
    issues.add(
      const EnvironmentIssue(
        'Trang Web',
        'Bản thử trên iPhone cần mở bằng URL HTTPS truy cập được từ điện thoại.',
      ),
    );
  }
  for (final endpoint in [
    ('Coordinator', config.coordinatorBaseUrl),
    if (config.notaryEnabled) ('Notary', config.notaryBaseUrl),
    ('RPC', config.rpcUrl),
  ]) {
    final uri = Uri.tryParse(endpoint.$2);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.host == '0.0.0.0' ||
        uri.host == '::' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      issues.add(
        EnvironmentIssue(
          endpoint.$1,
          'URL phải là HTTP(S) đầy đủ, không chứa thông tin đăng nhập, query hoặc fragment.',
        ),
      );
      continue;
    }
    if (staging && (uri.scheme != 'https' || isLoopback(uri.host))) {
      issues.add(
        EnvironmentIssue(
          endpoint.$1,
          'Staging cần HTTPS và địa chỉ không trỏ về localhost của điện thoại.',
        ),
      );
    } else if (pageUri.scheme == 'https' && uri.scheme != 'https') {
      issues.add(
        EnvironmentIssue(
          endpoint.$1,
          'Trang HTTPS không được gọi endpoint HTTP (mixed content).',
        ),
      );
    } else if ({'http', 'https'}.contains(pageUri.scheme) &&
        !isLoopback(pageUri.host) &&
        isLoopback(uri.host)) {
      issues.add(
        EnvironmentIssue(
          endpoint.$1,
          'localhost trỏ về thiết bị đang mở app; hãy cấu hình endpoint truy cập được từ cả hai máy.',
        ),
      );
    }
  }
  return issues;
}

bool isLoopback(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'localhost' ||
      normalized.endsWith('.localhost') ||
      normalized == '::1' ||
      normalized == '[::1]' ||
      RegExp(r'^127\.\d+\.\d+\.\d+$').hasMatch(normalized);
}

/// Only show endpoint origins. No capability, query, path or credential is
/// included in diagnostics, including when a build is misconfigured.
String endpointOrigin(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !{'http', 'https'}.contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return 'URL không hợp lệ';
  }
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
  ).origin;
}
