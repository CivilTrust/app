import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'vault_storage.dart';

VaultStorage createVaultStorage() => FileVaultStorage();

class FileVaultStorage implements VaultStorage {
  FileVaultStorage({this.directory});
  final Directory? directory;
  Future<Directory> get _dir async =>
      directory ??
      Directory('${(await getApplicationSupportDirectory()).path}/civiltrust');
  @override
  Future<String?> read() async {
    final file = File('${(await _dir).path}/vault.json');
    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<void> write(String encrypted, int expectedRevision) async {
    final dir = await _dir;
    await dir.create(recursive: true);
    final lock = await File('${dir.path}/vault.lock')
        .open(mode: FileMode.append);
    try {
      await lock.lock();
      final current = await read();
      final revision = current == null
          ? 0
          : (jsonDecode(current) as Map)['revision'];
      if (revision != expectedRevision) throw const VaultConflict();
      final file = File('${dir.path}/vault.next');
      await file.writeAsString(encrypted, flush: true);
      await file.rename('${dir.path}/vault.json');
    } finally {
      await lock.unlock();
      await lock.close();
    }
  }
}
