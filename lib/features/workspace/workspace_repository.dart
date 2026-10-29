import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

import '../../core/encoding/encoding_utils.dart';
import '../../core/crypto/hash_service.dart';
import '../../core/models/agreement.dart';
import '../../core/models/party_role.dart';
import '../sessions/session_cipher.dart';
import '../sessions/session_models.dart';
import 'workflow_event.dart';
import 'workflow_rules.dart';

class WorkspaceSnapshot {
  WorkspaceSnapshot(
    this.session,
    this.version,
    this.expiresAt,
    this.role,
    this.finalized,
    this.keys,
    this.signedArtifactReady,
  );
  final SigningSession session;
  final int version;
  final DateTime expiresAt;
  final PartyRole role;
  final bool finalized;
  final Map<String, dynamic> keys;
  final bool signedArtifactReady;
}

class WorkspaceRepository {
  WorkspaceRepository(this.baseUrl, {http.Client? client})
    : _client = client ?? http.Client();
  final String baseUrl;
  final http.Client _client;
  final cipher = SessionCipher();
  void close() => _client.close();
  Future<Map<String, dynamic>> _data(http.Response response) async {
    if (response.statusCode == 409) {
      throw StateError(
        'Phiên đã thay đổi ở thiết bị khác. Làm mới trước khi tiếp tục; không tự ký lại.',
      );
    }
    if (response.statusCode == 404) {
      throw StateError(
        'Không tìm thấy phiên hoặc phiên đã hết hạn. Bản lưu cục bộ vẫn giữ nguyên.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Coordinator từ chối thao tác (HTTP ${response.statusCode}).',
      );
    }
    return Map<String, dynamic>.from(
      (jsonDecode(response.body) as Map)['data'] as Map,
    );
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> record) async {
    final session = SigningSession.fromJson(
      Map<String, dynamic>.from(record['session'] as Map),
    );
    final actionKey = WorkflowKey(
      base64UrlDecodeNoPadding(record['actionSeed'] as String),
    );
    final box = await cipher.encrypt(
      session.toJson(),
      base64UrlDecodeNoPadding(record['key'] as String),
    );
    final packet = <String, dynamic>{
      'domain': 'civiltrust-workspace-create/1',
      'id': record['sessionId'],
      'creatorRole': record['role'],
      'publicKey': await actionKey.publicKey,
      if (WorkflowRules.isPayerProposal(session.draft))
        'workflowProfile': WorkflowRules.payerProfile,
    };
    final data = await _data(
      await _client
          .post(
            Uri.parse('$baseUrl/v2/sessions'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              ...packet,
              'ownerToken': record['token'],
              'participantToken': record['participantToken'],
              'createSignature': await actionKey.sign(packet),
              'encryptedPayload': box.toJson(),
            }),
          )
          .timeout(const Duration(seconds: 20)),
    );
    return data;
  }

  SessionCapabilities capability(Map<String, dynamic> record) =>
      SessionCapabilities(
        sessionId: record['sessionId'] as String,
        token: record['token'] as String,
        encryptionKey: base64UrlDecodeNoPadding(record['key'] as String),
        isOwner: record['isOwner'] as bool,
        workflowProfile: record['session'] is Map
            ? ((record['session'] as Map)['draft']
                      as Map)['fields']['workflowProfile']
                  as String?
            : null,
      );
  Map<String, String> _headers(SessionCapabilities c) => {
    'authorization': 'Bearer ${c.token}',
    'content-type': 'application/json',
  };
  Future<WorkspaceSnapshot> read(Map<String, dynamic> record) async {
    final c = capability(record);
    final data = await _data(
      await _client
          .get(
            Uri.parse('$baseUrl/v2/sessions/${c.sessionId}'),
            headers: _headers(c),
          )
          .timeout(const Duration(seconds: 20)),
    );
    final session = SigningSession.fromJson(
      await cipher.decrypt(
        EncryptedEnvelope.fromJson(
          Map<String, dynamic>.from(data['encryptedPayload'] as Map),
        ),
        c.encryptionKey,
      ),
    );
    if (WorkflowRules.creator(session.draft).name != data['creatorRole'] ||
        (data['workflowProfile'] ?? WorkflowRules.profile) !=
            session.draft.fields['workflowProfile'] ||
        data['phase'] != session.state.name ||
        data['frozenDigest'] != session.frozenDigest) {
      throw const FormatException(
        'Trạng thái server không khớp hồ sơ đã giải mã.',
      );
    }
    final keys = Map<String, dynamic>.from(data['keys'] as Map);
    for (final event in session.events) {
      if (event['publicKey'] != keys[(event['body'] as Map)['role']]) {
        throw const FormatException('Khóa hành động không khớp quyền phiên.');
      }
    }
    return WorkspaceSnapshot(
      session,
      data['version'] as int,
      DateTime.fromMillisecondsSinceEpoch(
        (data['expiresAt'] as num).toInt(),
        isUtc: true,
      ),
      PartyRole.values.byName(data['role'] as String),
      data['finalized'] as bool,
      keys,
      data['signedArtifactReady'] == true,
    );
  }

  Future<Map<String, dynamic>> apply(
    Map<String, dynamic> record,
    SigningSession next,
    String action, {
    Map<String, Object?>? encryptedArtifact,
  }) async {
    final c = capability(record);
    final key = WorkflowKey(
      base64UrlDecodeNoPadding(record['actionSeed'] as String),
    );
    final box = await cipher.encrypt(next.toJson(), c.encryptionKey);
    Future<String> sha(Map<String, Object?> value) async => bytesToHex(
      (await Sha256().hash(utf8.encode(canonicalJson(value)))).bytes,
    );
    final packet = <String, dynamic>{
      'domain': 'civiltrust-workspace-request/1',
      'sessionId': c.sessionId,
      'role': record['role'],
      'action': action,
      'expectedVersion': record['version'],
      'draftDigest': const HashService().canonicalObjectHash(
        next.draft.toJson(),
      ),
      'payloadSha256': await sha(box.toJson()),
      'artifactSha256': encryptedArtifact == null
          ? ''
          : await sha(encryptedArtifact),
    };
    return _data(
      await _client
          .post(
            Uri.parse('$baseUrl/v2/sessions/${c.sessionId}/actions'),
            headers: _headers(c),
            body: jsonEncode({
              'packet': packet,
              'publicKey': await key.publicKey,
              'signature': await key.sign(packet),
              'encryptedPayload': box.toJson(),
              'encryptedArtifact': ?encryptedArtifact,
            }),
          )
          .timeout(const Duration(seconds: 20)),
    );
  }

  Future<Map<String, dynamic>> artifact(Map<String, dynamic> record) async {
    final c = capability(record);
    final data = await _data(
      await _client
          .get(
            Uri.parse('$baseUrl/v2/sessions/${c.sessionId}/artifact'),
            headers: _headers(c),
          )
          .timeout(const Duration(seconds: 20)),
    );
    return cipher.decrypt(
      EncryptedEnvelope.fromJson(
        Map<String, dynamic>.from(data['encryptedArtifact'] as Map),
      ),
      c.encryptionKey,
    );
  }
}
