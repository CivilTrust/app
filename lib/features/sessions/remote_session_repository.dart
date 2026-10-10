import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/models/agreement.dart';
import 'session_cipher.dart';
import 'session_models.dart';

class CreatedRemoteSession {
  const CreatedRemoteSession({
    required this.owner,
    required this.participant,
    required this.version,
    required this.expiresAt,
  });
  final SessionCapabilities owner;
  final SessionCapabilities participant;
  final int version;
  final DateTime expiresAt;
}

class RemoteSessionRepository {
  RemoteSessionRepository(this.baseUrl, {http.Client? client})
    : _client = client ?? http.Client(),
      _cipher = SessionCipher();

  final String baseUrl;
  final http.Client _client;
  final SessionCipher _cipher;

  Future<CreatedRemoteSession> create(SigningSession session) async {
    final key = await _cipher.createKey();
    final envelope = await _cipher.encrypt(session.toJson(), key);
    final response = await _client.post(
      Uri.parse('$baseUrl/v1/sessions'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'encryptedPayload': envelope.toJson(),
        'ttlSeconds': 86400,
      }),
    );
    final body = _body(response);
    return CreatedRemoteSession(
      owner: SessionCapabilities(
        sessionId: body['id'] as String,
        token: body['ownerToken'] as String,
        encryptionKey: key,
        isOwner: true,
      ),
      participant: SessionCapabilities(
        sessionId: body['id'] as String,
        token: body['participantToken'] as String,
        encryptionKey: key,
        isOwner: false,
      ),
      version: body['version'] as int,
      expiresAt: _parseExpiresAt(body['expiresAt']),
    );
  }

  Future<RemoteSessionSnapshot<SigningSession>> read(
    SessionCapabilities capability,
  ) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/v1/sessions/${capability.sessionId}'),
      headers: _headers(capability),
    );
    final body = _body(response);
    final clear = await _cipher.decrypt(
      EncryptedEnvelope.fromJson(
        Map<String, dynamic>.from(body['encryptedPayload'] as Map),
      ),
      capability.encryptionKey,
    );
    return RemoteSessionSnapshot(
      value: SigningSession.fromJson(clear),
      version: body['version'] as int,
      finalized: body['finalized'] as bool,
      expiresAt: _parseExpiresAt(body['expiresAt']),
    );
  }

  Future<int> update(
    SessionCapabilities capability,
    SigningSession session,
    int expectedVersion,
  ) async {
    final envelope = await _cipher.encrypt(
      session.toJson(),
      capability.encryptionKey,
    );
    final response = await _client.put(
      Uri.parse('$baseUrl/v1/sessions/${capability.sessionId}'),
      headers: _headers(capability, json: true),
      body: jsonEncode({
        'expectedVersion': expectedVersion,
        'encryptedPayload': envelope.toJson(),
      }),
    );
    return _body(response)['version'] as int;
  }

  Future<int> finalize(SessionCapabilities capability) async {
    if (!capability.isOwner) {
      throw StateError('Chỉ Bên A mới có thể đóng phiên.');
    }
    final response = await _client.post(
      Uri.parse('$baseUrl/v1/sessions/${capability.sessionId}/finalize'),
      headers: _headers(capability, json: true),
      body: '{}',
    );
    return _body(response)['version'] as int;
  }

  Map<String, String> _headers(SessionCapabilities c, {bool json = false}) => {
    'authorization': 'Bearer ${c.token}',
    if (json) 'content-type': 'application/json',
  };

  Map<String, dynamic> _body(http.Response response) {
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw StateError(
        'Coordinator trả dữ liệu không phải JSON (HTTP ${response.statusCode}).',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        decoded is Map && decoded['error'] != null
            ? decoded['error'].toString()
            : 'Coordinator HTTP ${response.statusCode}',
      );
    }
    if (decoded is! Map) {
      throw StateError('Coordinator trả JSON không đúng định dạng.');
    }
    final envelope = Map<String, dynamic>.from(decoded);
    final data = envelope['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return envelope;
  }

  DateTime _parseExpiresAt(Object? value) {
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
    }
    if (value is String) return DateTime.parse(value).toUtc();
    throw StateError('Coordinator thiếu trường expiresAt hợp lệ.');
  }
}
