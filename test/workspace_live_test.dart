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
import 'package:civiltrust_app/core/config/app_config.dart';
import 'package:civiltrust_app/features/artifacts/artifact_service.dart';
import 'package:civiltrust_app/core/crypto/hash_service.dart';
import 'package:civiltrust_app/features/workspace/workspace_artifacts.dart';
import 'package:pdf/widgets.dart' as pw;

import 'dart:convert';

import 'package:http/http.dart' as http;

class LostPublishResponseClient extends http.BaseClient {
  final real = http.Client();
  bool dropNextPublish = false, dropNextCreate = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final createDrop =
        dropNextCreate &&
        request.method == 'POST' &&
        request.url.path.endsWith('/v2/sessions');
    final drop =
        createDrop ||
        (dropNextPublish &&
            request is http.Request &&
            request.method == 'POST' &&
            request.body.isNotEmpty &&
            (jsonDecode(request.body) as Map)['packet']?['action'] ==
                'publishArtifact');
    final response = await real.send(request);
    if (drop) {
      dropNextPublish = false;
      dropNextCreate = false;
      await response.stream.drain<void>();
      throw http.ClientException('Synthetic lost response after server commit');
    }
    return response;
  }

  @override
  void close() => real.close();
}

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
        final ownerHttp = LostPublishResponseClient(),
            peerHttp = LostPublishResponseClient();
        final ownerRepo = WorkspaceRepository(endpoint, client: ownerHttp),
            peerRepo = WorkspaceRepository(endpoint, client: peerHttp);
        final owner = WorkspaceService(ownerVault, ownerRepo),
            peer = WorkspaceService(peerVault, peerRepo);
        try {
          final draft = await newWorkspaceDraft(creator);
          ownerHttp.dropNextCreate = true;
          await expectLater(
            owner.create(draft, formId: 'synthetic-form'),
            throwsA(isA<http.ClientException>()),
          );
          final pendingId = ownerVault.records.single['sessionId'];
          expect(ownerVault.records.single['version'], 0);
          final local = await owner.create(draft, formId: 'synthetic-form');
          expect(local['sessionId'], pendingId);
          expect(ownerVault.records, hasLength(1));
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
          var fontLoads = 0;
          final output = ArtifactService(
            const HashService(),
            regularFont: () async {
              fontLoads++;
              return pw.Font.helvetica();
            },
            boldFont: () async {
              fontLoads++;
              return pw.Font.helveticaBold();
            },
          );
          final config = AppConfig(
            coordinatorBaseUrl: endpoint,
            notaryBaseUrl: '',
            rpcUrl: '',
            registryContract: '',
            chainId: 421614,
            notaryEnabled: false,
          );
          (creator == PartyRole.partyA ? ownerHttp : peerHttp).dropNextPublish =
              true;
          final manager = WorkspaceArtifacts(payee, config, artifacts: output);
          await expectLater(
            manager.finalize(payeeId),
            throwsA(isA<http.ClientException>()),
          );
          final staged = await manager.local(payeeId);
          expect(payee.record(payeeId)['pending'], isNotNull);
          await payee.sync(payeeId);
          final original = await manager.finalize(payeeId);
          expect(original.zip, staged.zip);
          expect(original.pdf, staged.pdf);
          expect(payee.record(payeeId)['finalized'], isTrue);
          final repeated = await WorkspaceArtifacts(
            payee,
            config,
            artifacts: output,
          ).finalize(payeeId);
          expect(fontLoads, 2);
          expect(repeated.pdf, original.pdf);
          expect(repeated.zip, original.zip);
          await payer.sync(payerId);
          final downloaded = await WorkspaceArtifacts(
            payer,
            config,
            artifacts: output,
          ).fetch(payerId);
          expect(downloaded.pdf, original.pdf);
          expect(downloaded.zip, original.zip);
          payer.vault.lock();
          await payer.vault.unlock(
            creator == PartyRole.partyB
                ? 'synthetic owner password'
                : 'synthetic peer password',
          );
          expect(
            (await WorkspaceArtifacts(
              payer,
              config,
              artifacts: output,
            ).local(payerId)).zip,
            original.zip,
          );
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
