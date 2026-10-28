import 'package:civiltrust_app/core/models/agreement.dart';
import 'package:civiltrust_app/core/models/party_role.dart';
import 'package:civiltrust_app/features/identity/identity_context.dart';
import 'package:civiltrust_app/features/identity/identity_service.dart';
import 'package:civiltrust_app/features/identity/mock_identity_reader.dart';
import 'package:civiltrust_app/features/payment/payment_details.dart';
import 'package:civiltrust_app/features/sessions/session_models.dart';
import 'package:civiltrust_app/features/signing/signing_context.dart';
import 'package:civiltrust_app/features/workspace/agreement_vault.dart';
import 'package:civiltrust_app/features/workspace/vault_storage.dart';
import 'package:civiltrust_app/features/workspace/workflow_rules.dart';
import 'package:civiltrust_app/features/workspace/workspace_repository.dart';
import 'package:civiltrust_app/features/workspace/workspace_service.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AgreementDraft> newWorkspaceDraft(PartyRole creator) async {
  final identity = await MockIdentityReader().read(role: creator.name);
  final id = createIdentityNonce();
  return AgreementDraft(
    id: id,
    title: 'Synthetic workspace',
    terms: 'Synthetic terms',
    amountVnd: 100000,
    createdAt: DateTime.now().toUtc(),
    fields: {
      'workflowProfile': WorkflowRules.profile,
      'creatorRole': creator.name,
      'payerRole': 'partyB',
      'payeeRole': 'partyA',
      'revision': '1',
      'creatorIdentityCommitment': identity.identityCommitment,
      'identityCeremonyId': createIdentityNonce(),
      'signingProtocol': SigningContext.protocol,
      'bankBin': '970436',
      'accountNumber': '000000000001',
      'accountName': 'SYNTHETIC',
      'paymentQrProfile': PaymentDetails.profile,
      'paymentPurpose': PaymentDetails.purposeFor(id),
    },
  );
}

void main() {
  const endpoint = String.fromEnvironment('LIVE_WORKSPACE_URL');
  for (final creator in PartyRole.values) {
    test(
      '${creator.name} creates, closes vault and resumes A/B over real HTTP',
      () async {
        final creatorStorage = MemoryVaultStorage();
        final ownerVault = AgreementVault(creatorStorage);
        await ownerVault.unlock('synthetic owner password');
        final peerVault = AgreementVault(MemoryVaultStorage());
        await peerVault.unlock('synthetic peer password');
        final ownerRepo = WorkspaceRepository(endpoint),
            peerRepo = WorkspaceRepository(endpoint);
        final owner = WorkspaceService(ownerVault, ownerRepo),
            peer = WorkspaceService(peerVault, peerRepo);
        try {
          final local = await owner.create(await newWorkspaceDraft(creator));
          final ownerId = local['localId'] as String;
          final invitation = SessionCapabilities.fromInviteFragment(
            owner.invite(local),
          );
          final joined = await peer.join(invitation);
          final peerId = joined['localId'] as String;
          expect(joined['role'], creator.other.name);
          final payee = creator == PartyRole.partyA ? owner : peer;
          final payer = creator == PartyRole.partyB ? owner : peer;
          final payeeId = creator == PartyRole.partyA ? ownerId : peerId;
          final payerId = creator == PartyRole.partyB ? ownerId : peerId;
          await expectLater(
            payer.act(payerId, WorkflowAction.approve),
            throwsFormatException,
          );
          await payee.act(payeeId, WorkflowAction.approve);
          await owner.sync(ownerId);
          await owner.act(
            ownerId,
            WorkflowAction.sign,
            identityService: IdentityService.forMode(IdentityMode.mock),
            consent: true,
          );
          ownerVault.lock();
          await ownerVault.unlock('synthetic owner password');
          await peer.sync(peerId);
          await peer.act(
            peerId,
            WorkflowAction.sign,
            identityService: IdentityService.forMode(IdentityMode.mock),
            consent: true,
          );
          await payer.sync(payerId);
          await payer.act(payerId, WorkflowAction.reportTransfer);
          await payee.sync(payeeId);
          await payee.act(payeeId, WorkflowAction.confirmReceived);
          final restored = await owner.sync(ownerId);
          expect(
            owner.session(restored).state,
            AgreementState.paymentConfirmed,
          );
          expect(owner.session(restored).events, hasLength(5));
        } finally {
          ownerRepo.close();
          peerRepo.close();
          ownerVault.dispose();
          peerVault.dispose();
        }
      },
      skip: endpoint.isEmpty
          ? 'Set LIVE_WORKSPACE_URL for HTTP integration.'
          : false,
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}
