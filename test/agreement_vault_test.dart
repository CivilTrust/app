import 'package:civiltrust_app/features/workspace/agreement_vault.dart';
import 'package:civiltrust_app/features/workspace/vault_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'vault encrypts capabilities, restores after close and exports recovery',
    () async {
      final storage = MemoryVaultStorage();
      final vault = AgreementVault(storage);
      await vault.unlock('a long test passphrase');
      await vault.put('session', {
        'localId': 'session',
        'token': 'SECRET_TOKEN',
        'key': 'SECRET_KEY',
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
      vault.dispose();
      reopened.lock();
      reopened.dispose();
      other.lock();
      other.dispose();
    },
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
    first.lock();
    second.lock();
    first.dispose();
    second.dispose();
  });
}
