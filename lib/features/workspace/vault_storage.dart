abstract interface class VaultStorage {
  Future<String?> read();

  /// Must atomically reject stale revisions across tabs/processes.
  Future<void> write(String encrypted, int expectedRevision);
}

class VaultConflict implements Exception {
  const VaultConflict();
  @override
  String toString() =>
      'Kho đã thay đổi ở tab khác. Hãy khóa và mở lại trước khi tiếp tục.';
}

class MemoryVaultStorage implements VaultStorage {
  String? value;
  int revision = 0;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String encrypted, int expectedRevision) async {
    if (revision != expectedRevision) throw const VaultConflict();
    value = encrypted;
    revision++;
  }
}
