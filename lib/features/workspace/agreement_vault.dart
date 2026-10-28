import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../../core/encoding/encoding_utils.dart';
import '../sessions/session_cipher.dart';
import '../sessions/session_models.dart';
import 'vault_storage.dart';

class AgreementVault extends ChangeNotifier {
  AgreementVault(this.storage);
  final VaultStorage storage;
  static const schema = 'civiltrust-vault/1';
  static const iterations = 600000;
  final _cipher = SessionCipher();
  List<int>? _key;
  String? _salt;
  int _revision = 0;
  Map<String, dynamic> _records = {};
  Future<void> _queue = Future.value();
  bool get unlocked => _key != null;
  List<Map<String, dynamic>> get records => _records.values
      .map((e) => jsonDecode(jsonEncode(e)) as Map<String, dynamic>)
      .toList();
  Future<bool> get exists async => await storage.read() != null;

  Future<List<int>> _derive(String password, String salt) async =>
      (await Pbkdf2(
            macAlgorithm: Hmac.sha256(),
            iterations: iterations,
            bits: 256,
          ).deriveKey(
            secretKey: SecretKey(utf8.encode(password)),
            nonce: base64UrlDecodeNoPadding(salt),
          ))
          .extractBytes();

  Future<void> unlock(String password) async {
    if (password.length < 12 || password.length > 256) {
      throw const FormatException(
        'Dùng mật khẩu kho từ 12 đến 256 ký tự. Không có chức năng quên mật khẩu.',
      );
    }
    final source = await storage.read();
    String salt;
    Map<String, dynamic>? decoded;
    if (source == null) {
      final random = Random.secure();
      salt = base64UrlNoPadding(List.generate(16, (_) => random.nextInt(256)));
    } else {
      decoded = _validate(source);
      salt = decoded['salt'] as String;
    }
    final key = List<int>.of(await _derive(password, salt));
    Map<String, dynamic> records = {};
    try {
      if (decoded != null) {
        final content = await _cipher.decrypt(
          EncryptedEnvelope.fromJson(
            Map<String, dynamic>.from(decoded['box'] as Map),
          ),
          key,
        );
        records = Map<String, dynamic>.from(content['records'] as Map);
        if (content['revision'] != decoded['revision']) {
          throw const FormatException('Vault revision mismatch');
        }
      }
    } catch (_) {
      key.fillRange(0, key.length, 0);
      throw const FormatException('Sai mật khẩu hoặc gói kho đã hỏng.');
    }
    lock();
    _key = key;
    _salt = salt;
    _revision = decoded?['revision'] as int? ?? 0;
    _records = records;
    if (source == null) {
      try {
        await _save(records);
      } catch (_) {
        lock();
        rethrow;
      }
    }
    notifyListeners();
  }

  Map<String, dynamic> _validate(String source) {
    if (source.length > 64 * 1024 * 1024) {
      throw const FormatException('Gói kho quá lớn.');
    }
    final json = jsonDecodeObject(source);
    if (json['schema'] != schema ||
        json['iterations'] != iterations ||
        json['revision'] is! int ||
        (json['revision'] as int) < 1 ||
        base64UrlDecodeNoPadding(json['salt'] as String).length != 16) {
      throw const FormatException('Định dạng kho không được hỗ trợ.');
    }
    return json;
  }

  Future<void> _save(Map<String, dynamic> next) async {
    final key = _key;
    if (key == null) throw StateError('Hãy mở khóa kho trước.');
    final expected = _revision;
    final box = await _cipher.encrypt({
      'revision': expected + 1,
      'records': next,
    }, key);
    if (!identical(key, _key)) {
      throw StateError('Kho đã khóa; chưa lưu thay đổi.');
    }
    final payload = jsonEncode({
      'schema': schema,
      'iterations': iterations,
      'salt': _salt,
      'revision': expected + 1,
      'box': box.toJson(),
    });
    await storage.write(payload, expected);
    if (!identical(key, _key)) return;
    _revision++;
    _records = next;
    notifyListeners();
  }

  Future<void> put(String id, Map<String, dynamic> record) {
    final done = _queue.then((_) async {
      if (!unlocked) throw StateError('Hãy mở khóa kho trước.');
      await _save({..._records, id: jsonDecode(jsonEncode(record))});
    });
    _queue = done.catchError((_) {});
    return done;
  }

  Future<String> exportEncrypted() async {
    if (!unlocked) throw StateError('Hãy mở khóa kho trước.');
    await _queue;
    return (await storage.read())!;
  }

  Future<void> importEncrypted(String source, String password) async {
    _validate(source);
    // Decrypt into an isolated vault first; never replace the current vault on failure.
    final temporary = MemoryVaultStorage()..value = source;
    final candidate = AgreementVault(temporary);
    try {
      await candidate.unlock(password);
      if (!unlocked) {
        throw StateError('Mở khóa/tạo kho hiện tại trước khi nhập.');
      }
      for (final record in candidate.records) {
        final id = record['localId'] as String;
        // Existing records win: importing an old backup cannot roll them back.
        if (!_records.containsKey(id)) await put(id, record);
      }
    } finally {
      candidate.lock();
      candidate.dispose();
    }
  }

  void lock() {
    _key?.fillRange(0, _key!.length, 0);
    _key = null;
    _records = {};
    _salt = null;
    _revision = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _key?.fillRange(0, _key!.length, 0);
    _key = null;
    _records = {};
    super.dispose();
  }
}
