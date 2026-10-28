import '../../core/models/identity_evidence.dart';

abstract interface class IdentityReader {
  Future<bool> isSupported();

  Future<IdentityEvidence> read({required String role});

  Future<void> cancel();
}

class IdentityReaderException implements Exception {
  const IdentityReaderException(
    this.message, {
    this.code = IdentityErrorCode.authenticationFailed,
  });

  final String message;
  final IdentityErrorCode code;

  @override
  String toString() => message;
}

enum IdentityErrorCode {
  unsupported,
  misconfigured,
  consentRequired,
  cancelled,
  timeout,
  tagLost,
  multipleTags,
  unsupportedCard,
  accessDenied,
  authenticationFailed,
  verifierUnavailable,
  busy,
  expired,
  replay,
}
