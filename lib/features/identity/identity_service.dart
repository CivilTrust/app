import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/identity_evidence.dart';
import 'identity_context.dart';
import 'identity_reader.dart';
import 'ios_identity_reader.dart';
import 'mock_identity_reader.dart';

enum IdentityMode {
  mock,
  nativeLab,
  verifiedNative;

  static IdentityMode parse(String value) => switch (value) {
    'mock' => mock,
    'native-lab' => nativeLab,
    'verified-native' => verifiedNative,
    _ => throw const FormatException('IDENTITY_MODE không hợp lệ.'),
  };
}

/// Verification must be independent of a reader's self-reported assurance.
/// A future trusted verifier must also check challenge/role/key bindings.
abstract interface class IdentityVerifier {
  Future<void> verify(IdentityEvidence evidence, IdentityContext context);
}

class UnconfiguredIdentityVerifier implements IdentityVerifier {
  const UnconfiguredIdentityVerifier();
  @override
  Future<void> verify(
    IdentityEvidence evidence,
    IdentityContext context,
  ) async {
    throw const IdentityReaderException(
      'Chưa cấu hình verifier CCCD đáng tin cậy.',
      code: IdentityErrorCode.verifierUnavailable,
    );
  }
}

class IdentityCapability {
  const IdentityCapability(this.available, this.message, [this.error]);
  final bool available;
  final String message;
  final IdentityErrorCode? error;
}

class IdentityService {
  IdentityService({
    required this.mode,
    required this.reader,
    this.isNativeIos = false,
    this.timeout = const Duration(seconds: 45),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  factory IdentityService.forMode(IdentityMode mode) => IdentityService(
    mode: mode,
    reader: mode == IdentityMode.mock
        ? MockIdentityReader()
        : IosIdentityReader(),
    isNativeIos: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
  );

  final IdentityMode mode;
  final IdentityReader reader;
  final DateTime Function() _clock;
  final bool isNativeIos;
  final Duration timeout;
  Completer<void>? _cancellation;
  bool _busy = false;
  bool _disposed = false;

  bool get isMock => mode == IdentityMode.mock;
  String get notice => isMock
      ? 'Dữ liệu mô phỏng; không đọc hoặc xác thực chip CCCD. Không nhập CCCD thật.'
      : 'NFC native chưa sẵn sàng: thiếu SDK/verifier và bản iOS đã ký. Không tự chuyển sang mock; chưa đọc hoặc upload CCCD thật.';

  Future<IdentityCapability> capability() async {
    if (!isMock && !isNativeIos) {
      return const IdentityCapability(
        false,
        'Đọc NFC cần app iOS native, không chạy trên Web/Windows.',
        IdentityErrorCode.unsupported,
      );
    }
    bool supported;
    try {
      supported = await reader.isSupported().timeout(timeout);
    } catch (_) {
      return const IdentityCapability(
        false,
        'Không kiểm tra được adapter; hãy kiểm cấu hình SDK.',
        IdentityErrorCode.misconfigured,
      );
    }
    if (!supported) {
      return const IdentityCapability(
        false,
        'Core NFC/SDK CCCD chưa được cấu hình trên thiết bị.',
        IdentityErrorCode.misconfigured,
      );
    }
    return IdentityCapability(
      true,
      isMock
          ? 'Chỉ có reader mô phỏng.'
          : 'Reader khả dụng; chưa phải kết quả xác thực CCCD.',
    );
  }

  Future<IdentityEvidence> identify({
    required IdentityContext context,
    required bool consent,
  }) async {
    if (_disposed) {
      throw const IdentityReaderException(
        'Reader đã đóng.',
        code: IdentityErrorCode.cancelled,
      );
    }
    if (!consent) {
      throw const IdentityReaderException(
        'Cần đồng ý trước khi đọc danh tính.',
        code: IdentityErrorCode.consentRequired,
      );
    }
    if (_busy) {
      throw const IdentityReaderException(
        'Đang có lượt đọc.',
        code: IdentityErrorCode.busy,
      );
    }
    if (!context.isValidAt(_clock())) {
      throw const IdentityReaderException(
        'Challenge hết hạn hoặc không hợp lệ.',
        code: IdentityErrorCode.expired,
      );
    }
    _busy = true;
    final cancellation = Completer<void>();
    _cancellation = cancellation;
    try {
      final operation =
          () async {
            final available = await capability();
            if (_disposed || cancellation.isCompleted) {
              throw const IdentityReaderException(
                'Đã hủy đọc danh tính.',
                code: IdentityErrorCode.cancelled,
              );
            }
            if (!available.available) {
              throw IdentityReaderException(
                available.message,
                code: available.error!,
              );
            }
            // G1 must never read real PII into the old agreement/artifact pipeline.
            // Lab transport and real verification are gated until G2/G3.
            if (!isMock) {
              throw const IdentityReaderException(
                'Luồng CCCD thật chưa được mở ở G1.',
                code: IdentityErrorCode.verifierUnavailable,
              );
            }
            final evidence = await reader.read(role: context.role);
            if (evidence.source != 'mock' ||
                evidence.chipAuthentication != 'mock' ||
                evidence.assurance != IdentityAssurance.mock ||
                evidence.proof != null) {
              throw const IdentityReaderException(
                'Reader mock trả dữ liệu không đúng chế độ.',
                code: IdentityErrorCode.authenticationFailed,
              );
            }
            return IdentityEvidence(
              source: 'mock',
              displayName: evidence.displayName,
              documentNumberMasked: evidence.documentNumberMasked,
              readAt: _clock().toUtc(),
              chipAuthentication: 'mock',
              identityCommitment: evidence.identityCommitment,
              attributes: Map.unmodifiable(evidence.attributes),
              schemaVersion: 2,
              assurance: IdentityAssurance.mock,
              context: context,
              verifierId: 'mock-only',
              policyVersion: 'mock-v2',
            );
          }().whenComplete(() {
            _busy = false;
          });
      final result = await Future.any<IdentityEvidence>([
        operation,
        cancellation.future.then<IdentityEvidence>(
          (_) => throw const IdentityReaderException(
            'Đã hủy đọc danh tính.',
            code: IdentityErrorCode.cancelled,
          ),
        ),
      ]).timeout(timeout);
      if (_disposed || cancellation.isCompleted) {
        throw const IdentityReaderException(
          'Đã hủy đọc danh tính.',
          code: IdentityErrorCode.cancelled,
        );
      }
      if (!context.isValidAt(_clock())) {
        throw const IdentityReaderException(
          'Challenge hết hạn.',
          code: IdentityErrorCode.expired,
        );
      }
      return result;
    } on TimeoutException {
      await _cancelReader();
      throw const IdentityReaderException(
        'Hết thời gian đọc danh tính.',
        code: IdentityErrorCode.timeout,
      );
    } on IdentityReaderException {
      rethrow;
    } catch (_) {
      throw const IdentityReaderException(
        'Không đọc được danh tính. Không lưu hoặc hiển thị dữ liệu lỗi từ reader.',
        code: IdentityErrorCode.authenticationFailed,
      );
    } finally {
      if (identical(_cancellation, cancellation)) _cancellation = null;
    }
  }

  /// Fail closed until a real verifier/trust policy is integrated in G3.
  Future<void> verifyForNativeUse(
    IdentityEvidence evidence,
    IdentityContext context,
  ) => const UnconfiguredIdentityVerifier().verify(evidence, context);

  Future<void> cancel() async {
    final cancellation = _cancellation;
    if (cancellation != null && !cancellation.isCompleted) {
      cancellation.complete();
    }
    await _cancelReader();
  }

  Future<void> _cancelReader() async {
    try {
      await reader.cancel().timeout(const Duration(seconds: 2));
    } catch (_) {
      /* Reader remains busy until its operation drains; no raw SDK error/PII. */
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await cancel();
  }
}
