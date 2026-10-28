import 'package:civiltrust_app/features/workspace/agreement_vault.dart';
import 'package:civiltrust_app/features/workspace/vault_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:civiltrust_app/features/workspace/workflow_event.dart';
import 'package:civiltrust_app/core/encoding/encoding_utils.dart';

void main() {
  test(
    'vault encrypts capabilities, restores after close and exports recovery',
    () async {
      final storage = MemoryVaultStorage();
      final vault = AgreementVault(storage);
      await vault.unlock('a long test passphrase');
      final actionKey = await WorkflowKey.create();
      await vault.put('session', {
        'localId': 'session',
        'token': 'SECRET_TOKEN',
        'key': 'SECRET_KEY',
        'role': 'partyB',
        'actionSeed': base64UrlNoPadding(actionKey.seed),
        'version': 1,
      });
      final backup = await vault.exportEncrypted();
      expect(backup, isNot(contains('SECRET')));
      vault.lock();
      expect(vault.records, isEmpty);
      final reopened = AgreementVault(storage);
      await reopened.unlock('a long test passphrase');
      expect(reopened.records.single['token'], 'SECRET_TOKEN');
      await expectLater(
        AgreementVault(storage).unlock('wrong password long'),
        throwsFormatException,
      );
      final other = AgreementVault(MemoryVaultStorage());
      await other.unlock('another test passphrase');
      await other.importEncrypted(backup, 'a long test passphrase');
      expect(other.records.single['key'], 'SECRET_KEY');
      await other.put('session', {
        ...other.records.single,
        'version': 9,
        'readOnly': true,
        'actionSeed': base64UrlNoPadding((await WorkflowKey.create()).seed),
        'registeredKeys': {'partyB': await actionKey.publicKey},
      });
      await other.importEncrypted(backup, 'a long test passphrase');
      expect(other.records.single['version'], 9);
      expect(other.records.single['readOnly'], false);
      expect(
        other.records.single['actionSeed'],
        base64UrlNoPadding(actionKey.seed),
      );
      vault.dispose();
      reopened.lock();
      reopened.dispose();
      other.lock();
      other.dispose();
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
  test('two tabs cannot silently overwrite newer vault data', () async {
    final storage = MemoryVaultStorage();
    final first = AgreementVault(storage);
    await first.unlock('a long test passphrase');
    final second = AgreementVault(storage);
    await second.unlock('a long test passphrase');
    await first.put('one', {'localId': 'one'});
    await expectLater(
      second.put('two', {'localId': 'two'}),
      throwsA(isA<VaultConflict>()),
    );
    expect(second.records, isEmpty);
    final pending = first.put('locked', {'localId': 'locked'});
    first.lock();
    await expectLater(pending, throwsStateError);
    second.lock();
    first.dispose();
    second.dispose();
  });
}
