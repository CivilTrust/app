import '../../core/crypto/hash_service.dart';
import '../../core/models/agreement.dart';
import '../../core/models/party_signature.dart';
import 'party_signer.dart';
import 'signing_context.dart';

class SessionValidator {
  const SessionValidator(this.hash, this.signer);

  final HashService hash;
  final PartySigner signer;

  Future<void> validate(
    SigningSession session, {
    bool requirePartyB = false,
  }) async {
    final isV2 =
        session.draft.fields['signingProtocol'] == SigningContext.protocol;
    if (session.draft.fields.containsKey('signingProtocol') && !isV2) {
      throw const FormatException('Signing protocol không được hỗ trợ.');
    }
    bool contextMatches(PartySignature signature) => !isV2
        ? signature.schemaVersion == 1
        : signature.schemaVersion == 2 &&
              signature.envelope?['agreementId'] == session.draft.id &&
              signature.envelope?['ceremonyId'] ==
                  session.draft.fields['identityCeremonyId'];
    final digest = session.frozenDigest;
    if (digest == null ||
        hash.canonicalObjectHash(session.draft.toJson()) != digest) {
      throw const FormatException('Nội dung không khớp mã đã khóa.');
    }
    final partyA = session.partyA;
    if (partyA == null ||
        partyA.role != 'partyA' ||
        partyA.signedDigest != digest ||
        !contextMatches(partyA) ||
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
            !contextMatches(partyB) ||
            !await signer.verify(partyB))) {
      throw const FormatException('Chữ ký Bên B không hợp lệ.');
    }
    if (isV2 &&
        partyB != null &&
        partyA.envelope?['challenge'] is Map &&
        partyB.envelope?['challenge'] is Map &&
        (partyA.envelope!['challenge'] as Map)['challengeId'] ==
            (partyB.envelope!['challenge'] as Map)['challengeId']) {
      throw const FormatException('A/B không được dùng cùng challenge.');
    }
  }
}
