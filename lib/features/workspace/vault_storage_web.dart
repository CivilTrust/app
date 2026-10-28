import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'vault_storage.dart';

VaultStorage createVaultStorage() => IndexedVaultStorage();

class IndexedVaultStorage implements VaultStorage {
  Future<web.IDBDatabase> _open() {
    final done = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open('civiltrust-encrypted-vault', 1);
    request.onupgradeneeded = ((web.Event _) {
      final database = request.result as web.IDBDatabase;
      database.createObjectStore('vault');
    }).toJS;
    request.onsuccess = ((web.Event _) {
      if (!done.isCompleted) done.complete(request.result as web.IDBDatabase);
    }).toJS;
    request.onerror = ((web.Event _) {
      if (!done.isCompleted) {
        done.completeError(StateError('Không mở được kho trên trình duyệt.'));
      }
    }).toJS;
    request.onblocked = ((web.Event _) {
      if (!done.isCompleted) {
        done.completeError(StateError('Đóng các tab app cũ rồi thử lại.'));
      }
    }).toJS;
    return done.future;
  }

  @override
  Future<String?> read() async {
    final db = await _open();
    final done = Completer<String?>();
    final tx = db.transaction('vault'.toJS, 'readonly');
    final request = tx.objectStore('vault').get('main'.toJS);
    request.onsuccess = ((web.Event _) {
      final result = request.result;
      done.complete(result == null ? null : (result as JSString).toDart);
    }).toJS;
    request.onerror = ((web.Event _) => done.completeError(
      StateError('Không đọc được kho.'),
    )).toJS;
    try {
      return await done.future;
    } finally {
      db.close();
    }
  }

  @override
  Future<void> write(String encrypted, int expectedRevision) async {
    final db = await _open();
    final done = Completer<void>();
    final tx = db.transaction('vault'.toJS, 'readwrite');
    final store = tx.objectStore('vault');
    final request = store.get('main'.toJS);
    bool conflict = false;
    request.onsuccess = ((web.Event _) {
      try {
        final current = request.result;
        final revision = current == null
            ? 0
            : (jsonDecode((current as JSString).toDart) as Map)['revision'];
        if (revision != expectedRevision) {
          conflict = true;
          tx.abort();
        } else {
          store.put(encrypted.toJS, 'main'.toJS);
        }
      } catch (_) {
        tx.abort();
      }
    }).toJS;
    tx.oncomplete = ((web.Event _) {
      if (!done.isCompleted) done.complete();
    }).toJS;
    void failed(web.Event _) {
      if (!done.isCompleted) {
        done.completeError(
          conflict
              ? const VaultConflict()
              : StateError(
                  'Không lưu được kho; dữ liệu chưa được xác nhận lưu.',
                ),
        );
      }
    }

    tx.onabort = failed.toJS;
    tx.onerror = failed.toJS;
    try {
      await done.future;
    } finally {
      db.close();
    }
  }
}
