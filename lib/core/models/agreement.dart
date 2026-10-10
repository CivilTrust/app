import 'party_signature.dart';

enum AgreementState {
  draft,
  contentFrozen,
  partyASigned,
  partyBSigned,
  paymentPending,
  paymentConfirmed,
  finalized,
  committedPendingAnchor,
  batched,
}

class AgreementDraft {
  const AgreementDraft({
    required this.id,
    required this.title,
    required this.terms,
    required this.amountVnd,
    required this.createdAt,
    this.templateId = 'custom-v1',
    this.fields = const {},
  });

  factory AgreementDraft.fromJson(Map<String, dynamic> json) => AgreementDraft(
    id: json['id'] as String,
    title: json['title'] as String,
    terms: json['terms'] as String,
    amountVnd: json['amountVnd'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String),
    templateId: json['templateId'] as String? ?? 'custom-v1',
    fields: json['fields'] == null
        ? const {}
        : Map<String, String>.from(json['fields'] as Map),
  );

  final String id;
  final String title;
  final String terms;
  final int amountVnd;
  final DateTime createdAt;
  final String templateId;
  final Map<String, String> fields;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'terms': terms,
    'amountVnd': amountVnd,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'templateId': templateId,
    'fields': fields,
  };
}

class PaymentReceipt {
  const PaymentReceipt({
    required this.confirmedByPartyA,
    required this.confirmedAt,
    required this.reference,
  });

  factory PaymentReceipt.fromJson(Map<String, dynamic> json) => PaymentReceipt(
    confirmedByPartyA: json['confirmedByPartyA'] as bool,
    confirmedAt: DateTime.parse(json['confirmedAt'] as String),
    reference: json['reference'] as String,
  );

  final bool confirmedByPartyA;
  final DateTime confirmedAt;
  final String reference;

  Map<String, Object?> toJson() => {
    'confirmedByPartyA': confirmedByPartyA,
    'confirmedAt': confirmedAt.toUtc().toIso8601String(),
    'reference': reference,
  };
}

class SigningSession {
  const SigningSession({
    required this.draft,
    required this.state,
    this.frozenDigest,
    this.partyA,
    this.partyB,
    this.payment,
  });

  factory SigningSession.fromJson(Map<String, dynamic> json) => SigningSession(
    draft: AgreementDraft.fromJson(
      Map<String, dynamic>.from(json['draft'] as Map),
    ),
    state: AgreementState.values.byName(json['state'] as String),
    frozenDigest: json['frozenDigest'] as String?,
    partyA: json['partyA'] == null
        ? null
        : PartySignature.fromJson(
            Map<String, dynamic>.from(json['partyA'] as Map),
          ),
    partyB: json['partyB'] == null
        ? null
        : PartySignature.fromJson(
            Map<String, dynamic>.from(json['partyB'] as Map),
          ),
    payment: json['payment'] == null
        ? null
        : PaymentReceipt.fromJson(
            Map<String, dynamic>.from(json['payment'] as Map),
          ),
  );

  final AgreementDraft draft;
  final AgreementState state;
  final String? frozenDigest;
  final PartySignature? partyA;
  final PartySignature? partyB;
  final PaymentReceipt? payment;

  SigningSession copyWith({
    AgreementState? state,
    String? frozenDigest,
    PartySignature? partyA,
    PartySignature? partyB,
    PaymentReceipt? payment,
  }) => SigningSession(
    draft: draft,
    state: state ?? this.state,
    frozenDigest: frozenDigest ?? this.frozenDigest,
    partyA: partyA ?? this.partyA,
    partyB: partyB ?? this.partyB,
    payment: payment ?? this.payment,
  );

  Map<String, Object?> toJson() => {
    'draft': draft.toJson(),
    'state': state.name,
    'frozenDigest': frozenDigest,
    'partyA': partyA?.toJson(),
    'partyB': partyB?.toJson(),
    'payment': payment?.toJson(),
  };
}
