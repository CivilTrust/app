import 'dart:convert';

import 'package:civiltrust_app/core/models/agreement.dart';
import 'package:civiltrust_app/features/sessions/remote_session_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('coordinator data envelope supports create, read and update', () async {
    Map<String, dynamic>? storedEnvelope;
    var version = 1;
    final client = MockClient((request) async {
      if (request.method == 'POST' && request.url.path == '/v1/sessions') {
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        storedEnvelope = Map<String, dynamic>.from(
          requestBody['encryptedPayload'] as Map,
        );
        return http.Response(
          jsonEncode({
            'data': {
              'id': 'session-1',
              'ownerToken': 'owner-token',
              'participantToken': 'participant-token',
              'version': version,
              'expiresAt': 1893456000000,
            },
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.method == 'GET') {
        expect(request.headers['authorization'], 'Bearer participant-token');
        return http.Response(
          jsonEncode({
            'data': {
              'id': 'session-1',
              'encryptedPayload': storedEnvelope,
              'version': version,
              'finalized': false,
              'expiresAt': 1893456000000,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.method == 'PUT') {
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(requestBody['expectedVersion'], version);
        storedEnvelope = Map<String, dynamic>.from(
          requestBody['encryptedPayload'] as Map,
        );
        version += 1;
        return http.Response(
          jsonEncode({
            'data': {'version': version},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.method == 'POST' &&
          request.url.path == '/v1/sessions/session-1/finalize') {
        expect(request.headers['authorization'], 'Bearer owner-token');
        version += 1;
        return http.Response(
          jsonEncode({
            'data': {'version': version, 'finalized': true},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(jsonEncode({'error': 'not found'}), 404);
    });

    final repository = RemoteSessionRepository(
      'http://coordinator.test',
      client: client,
    );
    final initial = SigningSession(
      draft: AgreementDraft(
        id: 'agreement-1',
        title: 'Demo',
        terms: 'Terms',
        amountVnd: 1000000,
        createdAt: DateTime.utc(2026, 10, 10),
      ),
      state: AgreementState.draft,
    );

    final created = await repository.create(initial);
    expect(created.owner.sessionId, 'session-1');
    expect(created.participant.token, 'participant-token');
    expect(created.expiresAt, DateTime.utc(2030));

    final snapshot = await repository.read(created.participant);
    expect(snapshot.value.draft.title, 'Demo');
    expect(snapshot.expiresAt, DateTime.utc(2030));

    final updatedVersion = await repository.update(
      created.participant,
      snapshot.value.copyWith(state: AgreementState.contentFrozen),
      snapshot.version,
    );
    expect(updatedVersion, 2);

    final finalizedVersion = await repository.finalize(created.owner);
    expect(finalizedVersion, 3);
  });
}
