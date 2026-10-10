import '../../core/models/identity_evidence.dart';

abstract interface class IdentityReader {
  Future<bool> isSupported();

  Future<IdentityEvidence> read({required String role});

  Future<void> cancel();
}

class IdentityReaderException implements Exception {
  const IdentityReaderException(this.message);

  final String message;

  @override
  String toString() => message;
}
