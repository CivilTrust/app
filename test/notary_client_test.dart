import 'dart:convert';

import 'package:civiltrust_app/features/notary/notary_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('submit sends only the 32-byte agreementHash', () async {
    const hash =
        '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/agreements/submit');
      expect(jsonDecode(request.body), {'agreementHash': hash});
      return http.Response(
        jsonEncode({
          'data': {
            'sct': {'agreementHash': hash, 'signature': '0x1234'},
          },
        }),
        201,
        headers: {'content-type': 'application/json'},
      );
    });

    final sct = await NotaryClient(
      'http://notary.test',
      client: client,
    ).submit(hash);
    expect(sct['agreementHash'], hash);
  });

  test('status uses the existing service route', () async {
    const hash =
        '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/agreements/status/$hash');
      return http.Response(
        jsonEncode({
          'data': {'status': 'pending'},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final status = await NotaryClient(
      'http://notary.test',
      client: client,
    ).status(hash);
    expect(status['status'], 'pending');
  });
}
