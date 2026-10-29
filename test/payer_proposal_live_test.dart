import 'dart:convert';

import 'package:civiltrust_app/core/config/app_config.dart';
import 'package:civiltrust_app/core/crypto/hash_service.dart';
import 'package:civiltrust_app/core/models/agreement.dart';
import 'package:civiltrust_app/core/models/party_role.dart';
import 'package:civiltrust_app/features/artifacts/artifact_service.dart';
import 'package:civiltrust_app/features/identity/identity_service.dart';
import 'package:civiltrust_app/features/sessions/session_models.dart';
import 'package:civiltrust_app/features/workspace/agreement_vault.dart';
import 'package:civiltrust_app/features/workspace/vault_storage.dart';
import 'package:civiltrust_app/features/workspace/workflow_rules.dart';
import 'package:civiltrust_app/features/workspace/workspace_repository.dart';
import 'package:civiltrust_app/features/workspace/workspace_service.dart';
import 'package:civiltrust_app/features/workspace/workspace_artifacts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/widgets.dart' as pw;

import 'workspace_live_test.dart' show newWorkspaceDraft;

Future<AgreementDraft> payerDraft() async {
  final original = await newWorkspaceDraft(PartyRole.partyB);
  return AgreementDraft(
    id: original.id,
    title: original.title,
    terms: original.terms,
    amountVnd: original.amountVnd,
    createdAt: original.createdAt,
    fields: {...original.fields, 'workflowProfile': WorkflowRules.payerProfile}
      ..removeWhere(
        (k, v) => {'bankBin', 'accountNumber', 'accountName'}.contains(k),
      ),
  );
}

class DropResponse extends http.BaseClient {
  final real = http.Client();
  String? action;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final lose =
        action != null &&
        request is http.Request &&
        request.method == 'POST' &&
        (jsonDecode(request.body) as Map)['packet']?['action'] == action;
    final response = await real.send(request);
    if (lose) {
      action = null;
      await response.stream.drain<void>();
      throw http.ClientException('Synthetic lost response');
    }
    return response;
  }

  @override
  void close() => real.close();
}

void main() {
  const endpoint = String.fromEnvironment('LIVE_WORKSPACE_URL');
  test(
    'B proposal without A/bank -> A first -> immutable signed PDF -> transfer/issue/receipt',
    () async {
      final bv = AgreementVault(MemoryVaultStorage()),
          av = AgreementVault(MemoryVaultStorage());
      await bv.unlock('synthetic payer password');
      await av.unlock('synthetic payee password');
      final client = DropResponse();
      final br = WorkspaceRepository(endpoint, client: client),
          ar = WorkspaceRepository(endpoint);
      final b = WorkspaceService(bv, br), a = WorkspaceService(av, ar);
      final identities = IdentityService.forMode(IdentityMode.mock);
      final config = AppConfig(
        coordinatorBaseUrl: endpoint,
        notaryBaseUrl: '',
        rpcUrl: '',
        registryContract: '',
        chainId: 421614,
        notaryEnabled: false,
      );
      var loads = 0;
      final files = ArtifactService(
        const HashService(),
        regularFont: () async {
          loads++;
          return pw.Font.helvetica();
        },
        boldFont: () async {
          loads++;
          return pw.Font.helveticaBold();
        },
      );
      final bm = WorkspaceArtifacts(b, config, artifacts: files),
          am = WorkspaceArtifacts(a, config, artifacts: files);
      try {
        final created = await b.create(await payerDraft());
        final bid = created['localId'] as String;
        expect(
          b.session(created).draft.fields.containsKey('accountNumber'),
          false,
        );
        final invited = SessionCapabilities.fromInviteFragment(
          b.invite(created),
        );
        expect(invited.workflowProfile, WorkflowRules.payerProfile);
        final aid = (await a.join(invited))['localId'] as String;
        await expectLater(
          b.act(
            bid,
            WorkflowAction.sign,
            identityService: identities,
            consent: true,
          ),
          throwsFormatException,
        );
        await expectLater(a.act(aid, WorkflowAction.approve), throwsStateError);
        await a.act(
          aid,
          WorkflowAction.approve,
          identityService: identities,
          consent: true,
          bankFields: {
            'bankBin': '970436',
            'accountNumber': '000000000001',
            'accountName': 'SYNTHETIC PAYEE',
          },
        );
        await a.act(
          aid,
          WorkflowAction.sign,
          identityService: identities,
          consent: true,
        );
        await b.sync(bid);
        expect(b.session(b.record(bid)).state, AgreementState.partyASigned);
        expect(
          b.session(b.record(bid)).draft.fields['partyAIdentitySummary'],
          isNotEmpty,
        );
        await b.act(
          bid,
          WorkflowAction.sign,
          identityService: identities,
          consent: true,
        );
        await expectLater(
          b.act(bid, WorkflowAction.reportTransfer),
          throwsStateError,
        );
        client.action = 'publishSignedArtifact';
        await expectLater(
          bm.savePayerStage(bid),
          throwsA(isA<http.ClientException>()),
        );
        expect(b.record(bid)['signedArchive'], isNotNull);
        await b.sync(bid);
        final signed = await bm.savePayerStage(bid);
        expect(signed.evidence.session.payment, isNull);
        expect(signed.evidence.session.state, AgreementState.bothSigned);
        await b.validator.validate(
          files.importZip(signed.zip).session,
          requirePartyB: true,
        );
        await a.sync(aid);
        expect((await am.savePayerStage(aid)).pdf, signed.pdf);
        client.action = 'reportTransfer';
        await expectLater(
          b.act(
            bid,
            WorkflowAction.reportTransfer,
            paymentReference: 'SYNTHETIC-REFERENCE',
            attachment: utf8.encode('%PDF-1.4\nSynthetic receipt fixture'),
          ),
          throwsA(isA<http.ClientException>()),
        );
        await b.sync(bid);
        final reported = await bm.savePayerStage(bid);
        expect(reported.pdf, signed.pdf);
        expect(reported.evidence.documentHash, signed.evidence.documentHash);
        expect(reported.evidence.session.transfer!['attachment'], isNotNull);
        final tampered = reported.evidence.session.toJson();
        (tampered['transfer'] as Map)['reference'] = 'TAMPER';
        await expectLater(
          b.validator.validate(SigningSession.fromJson(tampered)),
          throwsFormatException,
        );
        await a.sync(aid);
        await a.act(
          aid,
          WorkflowAction.reportIssue,
          responseNote: 'Synthetic: not received yet',
        );
        expect(a.session(a.record(aid)).payment, isNull);
        await a.act(
          aid,
          WorkflowAction.confirmReceived,
          paymentReference: 'Synthetic receipt confirmed',
        );
        final finalBundle = await am.finalize(aid);
        expect(finalBundle.pdf, signed.pdf);
        expect(finalBundle.evidence.documentHash, signed.evidence.documentHash);
        expect(loads, 2);
        expect(finalBundle.zip, isNot(equals(signed.zip)));
        await b.sync(bid);
        final downloaded = await bm.fetch(bid);
        expect(downloaded.zip, finalBundle.zip);
        expect((await bm.savePayerStage(bid)).zip, finalBundle.zip);
        expect((await am.savePayerStage(aid)).zip, finalBundle.zip);
        expect(downloaded.evidence.session.payment!.confirmedByPartyA, true);
        await b.validator.validate(
          files.importZip(downloaded.zip).session,
          requirePartyB: true,
        );
        bv.lock();
        await bv.unlock('synthetic payer password');
        expect((await bm.local(bid)).zip, finalBundle.zip);
      } finally {
        br.close();
        ar.close();
        bv.dispose();
        av.dispose();
        await identities.dispose();
      }
    },
    skip: endpoint.isEmpty ? 'Set LIVE_WORKSPACE_URL' : false,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'A may request changes or decline without signing or inventing bank details',
    () async {
      final bv = AgreementVault(MemoryVaultStorage()),
          av = AgreementVault(MemoryVaultStorage());
      await bv.unlock('synthetic payer password');
      await av.unlock('synthetic payee password');
      final br = WorkspaceRepository(endpoint),
          ar = WorkspaceRepository(endpoint);
      final b = WorkspaceService(bv, br), a = WorkspaceService(av, ar);
      try {
        for (final action in [
          WorkflowAction.requestChanges,
          WorkflowAction.decline,
        ]) {
          final created = await b.create(await payerDraft());
          final bid = created['localId'] as String;
          final aid =
              (await a.join(
                    SessionCapabilities.fromInviteFragment(b.invite(created)),
                  ))['localId']
                  as String;
          await a.act(aid, action, responseNote: 'Synthetic proposal feedback');
          await b.sync(bid);
          expect(b.session(b.record(bid)).response!['action'], action.name);
          await expectLater(
            a.act(aid, WorkflowAction.approve),
            throwsFormatException,
          );
        }
      } finally {
        br.close();
        ar.close();
        bv.dispose();
        av.dispose();
      }
    },
    skip: endpoint.isEmpty ? 'Set LIVE_WORKSPACE_URL' : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
