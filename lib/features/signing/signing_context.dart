import '../../core/models/agreement.dart';

class SigningContext {
  const SigningContext({required this.agreementId, required this.ceremonyId});
  static const protocol = 'civiltrust-signing/2';

  factory SigningContext.fromDraft(AgreementDraft draft) {
    if (draft.fields['signingProtocol'] != protocol ||
        draft.fields['identityCeremonyId'] == null) {
      throw const FormatException(
        'Phiên ký chưa có context v2. Hãy tạo phiên mới.',
      );
    }
    return SigningContext(
      agreementId: draft.id,
      ceremonyId: draft.fields['identityCeremonyId']!,
    );
  }

  final String agreementId;
  final String ceremonyId;
}
