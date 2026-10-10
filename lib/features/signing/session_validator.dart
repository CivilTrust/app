import '../../core/crypto/hash_service.dart';
import '../../core/models/agreement.dart';
import 'party_signer.dart';

class SessionValidator {
  const SessionValidator(this.hash, this.signer);

  final HashService hash;
  final PartySigner signer;

  Future<void> validate(
    SigningSession session, {
    bool requirePartyB = false,
  }) async {
    final digest = session.frozenDigest;
    if (digest == null ||
        hash.canonicalObjectHash(session.draft.toJson()) != digest) {
      throw const FormatException('Nội dung không khớp mã đã khóa.');
    }
    final partyA = session.partyA;
    if (partyA == null ||
        partyA.role != 'partyA' ||
        partyA.signedDigest != digest ||
        !await signer.verify(partyA)) {
      throw const FormatException('Chữ ký Bên A không hợp lệ.');
    }
    final partyB = session.partyB;
    if (requirePartyB && partyB == null) {
      throw const FormatException('Thiếu chữ ký Bên B.');
    }
    if (partyB != null &&
        (partyB.role != 'partyB' ||
            partyB.signedDigest != digest ||
            !await signer.verify(partyB))) {
      throw const FormatException('Chữ ký Bên B không hợp lệ.');
    }
  }
}
