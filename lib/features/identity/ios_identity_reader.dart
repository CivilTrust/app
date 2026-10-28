import '../../core/models/identity_evidence.dart';
import 'identity_reader.dart';

/// Stable seam for the future Core NFC implementation.
///
/// The MVP intentionally does not fake successful NFC reads. A later iOS
/// plugin/platform channel must implement ISO 7816/APDU exchange, certificate
/// validation and raw-buffer zeroization behind this interface.
class IosIdentityReader implements IdentityReader {
  @override
  Future<bool> isSupported() async => false;

  @override
  Future<IdentityEvidence> read({required String role}) {
    throw const IdentityReaderException(
      'Core NFC CCCD adapter chưa được cấu hình. Không đọc CCCD thật hoặc tự chuyển sang mock.',
      code: IdentityErrorCode.misconfigured,
    );
  }

  @override
  Future<void> cancel() async {}
}
