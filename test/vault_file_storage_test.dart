import 'dart:io';

import 'package:civiltrust_app/features/workspace/vault_storage_native.dart';
import 'package:civiltrust_app/features/workspace/vault_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'native ciphertext file survives reopen and rejects stale replace',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'civiltrust-vault-test-',
      );
      try {
        final first = FileVaultStorage(directory: directory);
        await first.write('{"revision":1,"box":"opaque"}', 0);
        final reopened = FileVaultStorage(directory: directory);
        expect(await reopened.read(), contains('opaque'));
        await reopened.write('{"revision":2,"box":"new"}', 1);
        await expectLater(
          first.write('{"revision":2}', 1),
          throwsA(isA<VaultConflict>()),
        );
        expect(await first.read(), contains('new'));
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}
