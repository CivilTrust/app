import 'package:civiltrust_app/core/crypto/hash_service.dart';
import 'package:civiltrust_app/core/encoding/encoding_utils.dart';
import 'package:civiltrust_app/core/models/agreement.dart';
import 'package:civiltrust_app/core/models/identity_evidence.dart';
import 'package:civiltrust_app/core/models/party_role.dart';
import 'package:civiltrust_app/features/identity/identity_context.dart';
import 'package:civiltrust_app/features/identity/mock_identity_reader.dart';
import 'package:civiltrust_app/features/payment/payment_details.dart';
import 'package:civiltrust_app/features/signing/mock_party_signer.dart';
import 'package:civiltrust_app/features/signing/session_validator.dart';
import 'package:civiltrust_app/features/signing/signing_context.dart';
import 'package:civiltrust_app/features/workspace/workflow_engine.dart';
import 'package:civiltrust_app/features/workspace/workflow_event.dart';
import 'package:civiltrust_app/features/workspace/workflow_rules.dart';
import 'package:flutter_test/flutter_test.dart';

Future<SigningSession> workflowFixture(
  PartyRole creator, {
  bool paid = true,
}) async {
  final ceremony = createIdentityNonce();
  const id = 'synthetic-workflow';
  final draft = AgreementDraft(
    id: id,
    title: 'Synthetic',
    terms: 'Synthetic terms',
    amountVnd: 100000,
    createdAt: DateTime.now().toUtc(),
    fields: {
      'workflowProfile': WorkflowRules.profile,
      'creatorRole': creator.name,
      'payerRole': 'partyB',
      'payeeRole': 'partyA',
      'revision': '1',
      'identityCeremonyId': ceremony,
      'signingProtocol': SigningContext.protocol,
      'bankBin': '970436',
      'accountNumber': '000000000001',
      'accountName': 'SYNTHETIC',
      'paymentQrProfile': PaymentDetails.profile,
      'paymentPurpose': PaymentDetails.purposeFor(id),
    },
  );
  final keys = {
    for (final role in PartyRole.values) role: await WorkflowKey.create(),
  };
  var session = SigningSession(draft: draft, state: AgreementState.draft);
  session = await WorkflowEngine.apply(
    session,
    PartyRole.partyA,
    keys[PartyRole.partyA]!,
    WorkflowAction.approve,
  );
  for (final role in [creator, creator.other]) {
    final raw = await MockIdentityReader().read(role: role.name);
    final identity = IdentityEvidence(
      source: 'mock',
      displayName: raw.displayName,
      documentNumberMasked: raw.documentNumberMasked,
      readAt: DateTime.now().toUtc(),
      chipAuthentication: 'mock',
      identityCommitment: raw.identityCommitment,
      attributes: {
        ...raw.attributes,
        'workspaceActionKey': await keys[role]!.publicKey,
      },
      schemaVersion: 2,
      context: IdentityContext.create(
        ceremonyId: ceremony,
        role: role.name,
        now: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
      ),
    );
    final signature = await MockPartySigner().sign(
      role: role.name,
      digest: hexToBytes(
        const HashService().canonicalObjectHash(draft.toJson()),
      ),
      identity: identity,
      context: SigningContext.fromDraft(draft),
    );
    session = await WorkflowEngine.apply(
      session,
      role,
      keys[role]!,
      WorkflowAction.sign,
      signature: signature,
    );
  }
  if (paid) {
    session = await WorkflowEngine.apply(
      session,
      PartyRole.partyB,
      keys[PartyRole.partyB]!,
      WorkflowAction.reportTransfer,
    );
    session = await WorkflowEngine.apply(
      session,
      PartyRole.partyA,
      keys[PartyRole.partyA]!,
      WorkflowAction.confirmReceived,
    );
  }
  return session;
}

void main() {
  final validator = SessionValidator(const HashService(), MockPartySigner());
  for (final creator in PartyRole.values) {
    test(
      '${creator.name} full workflow verifies including receipt and archived state',
      () async {
        final session = await workflowFixture(creator);
        await validator.validate(session, requirePartyB: true);
        await validator.validate(
          session.copyWith(state: AgreementState.committedPendingAnchor),
          requirePartyB: true,
        );
        final changed = session.toJson();
        (changed['payment'] as Map)['reference'] = 'ATTACK';
        await expectLater(
          validator.validate(SigningSession.fromJson(changed)),
          throwsFormatException,
        );
      },
    );
  }
  test(
    'cannot forge A confirmation or rewrite events with another action key',
    () async {
      final session = await workflowFixture(PartyRole.partyB);
      final changed = session.toJson();
      final events = (changed['events'] as List);
      events.last = <String, dynamic>{
        ...Map<String, dynamic>.from(events.last as Map),
        'publicKey': await (await WorkflowKey.create()).publicKey,
      };
      await expectLater(
        validator.validate(SigningSession.fromJson(changed)),
        throwsFormatException,
      );
      await expectLater(
        validator.validate(
          session.copyWith(events: session.events.reversed.toList()),
        ),
        throwsA(anything),
      );
    },
  );
}
