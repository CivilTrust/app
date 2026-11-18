import 'package:civiltrust_app/core/encoding/encoding_utils.dart';
import 'package:civiltrust_app/core/models/agreement.dart';
import 'package:civiltrust_app/core/models/party_role.dart';
import 'package:civiltrust_app/features/payment/payment_details.dart';
import 'package:civiltrust_app/features/signing/signing_context.dart';
import 'package:civiltrust_app/features/workspace/agreement_vault.dart';
import 'package:civiltrust_app/features/workspace/vault_storage.dart';
import 'package:civiltrust_app/features/workspace/workflow_engine.dart';
import 'package:civiltrust_app/features/workspace/workflow_event.dart';
import 'package:civiltrust_app/features/workspace/workflow_rules.dart';
import 'package:civiltrust_app/features/workspace/workspace_repository.dart';
import 'package:civiltrust_app/features/workspace/workspace_service.dart';
import 'package:civiltrust_app/features/workspace/workspace_watcher.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves a scripted snapshot and records which records were requested.
class FakeRepository extends WorkspaceRepository {
  FakeRepository() : super('https://coordinator.test');
  WorkspaceSnapshot? next;
  final requested = <String>[];

  @override
  Future<WorkspaceSnapshot> read(Map<String, dynamic> record) async {
    requested.add(record['localId'] as String);
    return next!;
  }
}

SigningSession draftSession() {
  const id = 'synthetic-watch';
  return SigningSession(
    draft: AgreementDraft(
      id: id,
      title: 'Hợp đồng đặt cọc',
      terms: 'Synthetic terms',
      amountVnd: 100000,
      createdAt: DateTime.utc(2026, 11, 18),
      fields: {
        'workflowProfile': WorkflowRules.profile,
        'creatorRole': 'partyA',
        'payerRole': 'partyB',
        'payeeRole': 'partyA',
        'revision': '1',
        'identityCeremonyId': 'synthetic-ceremony',
        'signingProtocol': SigningContext.protocol,
        'bankBin': '970436',
        'accountNumber': '000000000001',
        'accountName': 'SYNTHETIC',
        'paymentQrProfile': PaymentDetails.profile,
        'paymentPurpose': PaymentDetails.purposeFor(id),
      },
    ),
    state: AgreementState.draft,
  );
}

void main() {
  late AgreementVault vault;
  late FakeRepository repository;
  late WorkspaceWatcher watcher;
  late SigningSession approved;

  setUpAll(() async {
    final key = await WorkflowKey.create();
    approved = await WorkflowEngine.apply(
      draftSession(),
      PartyRole.partyA,
      key,
      WorkflowAction.approve,
    );
  });

  setUp(() async {
    vault = AgreementVault(MemoryVaultStorage());
    repository = FakeRepository();
    final service = WorkspaceService(vault, repository);
    watcher = WorkspaceWatcher(service, interval: const Duration(hours: 1));
    await vault.unlock('a long test passphrase');
    final actionKey = await WorkflowKey.create();
    Map<String, dynamic> record(String id, String endpoint) => {
      'localId': id,
      'sessionId': id,
      'role': 'partyB',
      'isOwner': false,
      'token': 'synthetic',
      'key': 'synthetic',
      'actionSeed': base64UrlNoPadding(actionKey.seed),
      'version': 1,
      'session': draftSession().toJson(),
      'finalized': false,
      'endpoint': endpoint,
    };
    await vault.put('mine', record('mine', 'https://coordinator.test'));
    await vault.put('foreign', record('foreign', 'https://other.test'));
    await vault.put('draft-form', {
      'localId': 'draft-form',
      'kind': 'form',
      'templateId': 'deposit-v1',
    });
    repository.requested.clear();
  });

  tearDown(() => watcher.dispose());

  WorkspaceSnapshot snapshot(SigningSession session, int version) =>
      WorkspaceSnapshot(
        session,
        version,
        DateTime.utc(2026, 11, 25),
        PartyRole.partyB,
        false,
        const {},
        false,
      );

  test('only polls records bound to the configured coordinator', () async {
    repository.next = snapshot(draftSession(), 1);
    await watcher.checkNow();
    expect(repository.requested, ['mine']);
    expect(watcher.notifications, isEmpty);
  });

  test('a newer verified version creates one notification', () async {
    repository.next = snapshot(approved, 2);
    await watcher.checkNow();
    expect(watcher.unread, 1);
    expect(watcher.hasUpdate('mine'), isTrue);
    final note = watcher.notifications.single;
    expect(note.message, contains('Bên A đã khóa nội dung'));
    expect(note.needsAction, isFalse);
    // Same remote version again: no duplicate.
    await watcher.checkNow();
    expect(watcher.notifications, hasLength(1));
    // The vault copy was never modified by polling.
    expect(
      vault.records.firstWhere((r) => r['localId'] == 'mine')['version'],
      1,
    );
    watcher.markSeen('mine');
    expect(watcher.unread, 0);
    expect(watcher.hasUpdate('mine'), isFalse);
  });

  test('locking the vault clears notifications and stops polling', () async {
    repository.next = snapshot(approved, 2);
    await watcher.checkNow();
    expect(watcher.unread, 1);
    vault.lock();
    expect(watcher.notifications, isEmpty);
    repository.requested.clear();
    await watcher.checkNow();
    expect(repository.requested, isEmpty);
  });

  test('network or validation errors stay silent', () async {
    final broken = SigningSession(
      draft: draftSession().draft,
      state: AgreementState.bothSigned,
    );
    repository.next = snapshot(broken, 5);
    await watcher.checkNow();
    expect(watcher.notifications, isEmpty);
    expect(watcher.hasUpdate('mine'), isFalse);
  });
}
