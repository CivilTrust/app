import 'dart:convert';

import 'package:civiltrust_app/features/notary/notary_client.dart';
import 'package:civiltrust_app/features/notary/signed_commitment_token.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const hash =
    '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const otherHash =
    '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const address = '0x1111111111111111111111111111111111111111';
final signature = '0x${List.filled(65, '22').join()}';

Map<String, dynamic> fixture({bool signer = true}) => {
  'version': '1.3.0',
  'domain': {
    'name': 'CivilTrustRegistry',
    'version': '1',
    'chainId': 421614,
    'verifyingContract': address,
  },
  'message': {
    'agreementHash': hash,
    'dateKey': 20261027,
    'timestamp': 1793059200,
    'nonce': otherHash,
  },
  if (signer) 'signer': address,
  'signature': signature,
};

http.Response success(Map<String, dynamic> sct, int status) => http.Response(
  jsonEncode({
    'success': true,
    'data': {'sct': sct},
  }),
  status,
);

void main() {
  test('201 sends only PDF hash and parses typed SCT', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/agreements/submit');
      expect(jsonDecode(request.body), {'agreementHash': hash});
      return success(fixture(), 201);
    });
    final sct = await NotaryClient(
      'http://notary.test/',
      client: client,
    ).submit(hash);
    expect(sct, isA<SignedCommitmentToken>());
    expect(sct.message.agreementHash, hash);
    expect(sct.signer, address);
    expect(sct.toJson(), fixture());
  });

  test('200 idempotent response without signer remains readable', () async {
    final sct = await NotaryClient(
      'http://notary.test',
      client: MockClient((_) async => success(fixture(signer: false), 200)),
    ).submit(hash);
    expect(sct.signer, isNull);
    expect(sct.toJson().containsKey('signer'), isFalse);
  });

  test('rejects mismatched PDF hash', () async {
    final bad = fixture();
    (bad['message'] as Map<String, dynamic>)['agreementHash'] = otherHash;
    await expectLater(
      NotaryClient(
        'http://notary.test',
        client: MockClient((_) async => success(bad, 201)),
      ).submit(hash),
      throwsFormatException,
    );
  });

  test('rejects unsupported version and malformed fields', () {
    expect(
      () => SignedCommitmentToken.fromJson(fixture()..['version'] = '2.0.0'),
      throwsUnsupportedError,
    );
    final badNonce = fixture();
    (badNonce['message'] as Map<String, dynamic>)['nonce'] = '0x1234';
    expect(
      () => SignedCommitmentToken.fromJson(badNonce),
      throwsFormatException,
    );
    final badTimestamp = fixture();
    (badTimestamp['message'] as Map<String, dynamic>)['timestamp'] =
        '1793059200';
    expect(
      () => SignedCommitmentToken.fromJson(badTimestamp),
      throwsFormatException,
    );
    expect(
      () => SignedCommitmentToken.fromJson(fixture()..['signature'] = '0x1234'),
      throwsFormatException,
    );
    expect(
      () => SignedCommitmentToken.fromJson(fixture()..['signer'] = null),
      throwsFormatException,
    );
    final badDomain = fixture();
    (badDomain['domain'] as Map<String, dynamic>)['name'] = 'OtherRegistry';
    expect(
      () => SignedCommitmentToken.fromJson(badDomain),
      throwsUnsupportedError,
    );
    final missingMessage = fixture()..remove('message');
    expect(
      () => SignedCommitmentToken.fromJson(missingMessage),
      throwsFormatException,
    );
  });

  test('rejects missing success envelope and malformed JSON', () async {
    final noSuccess = NotaryClient(
      'http://notary.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'data': {'sct': fixture()},
          }),
          201,
        ),
      ),
    );
    await expectLater(noSuccess.submit(hash), throwsFormatException);
    final nonJson = NotaryClient(
      'http://notary.test',
      client: MockClient((_) async => http.Response('<html>', 201)),
    );
    await expectLater(nonJson.submit(hash), throwsFormatException);
  });

  test('reports HTTP, network and timeout failures', () async {
    final httpFailure = NotaryClient(
      'http://notary.test',
      client: MockClient(
        (_) async => http.Response(jsonEncode({'error': 'Unavailable'}), 503),
      ),
    );
    await expectLater(
      httpFailure.submit(hash),
      throwsA(
        isA<NotaryClientException>().having(
          (error) => error.statusCode,
          'statusCode',
          503,
        ),
      ),
    );
    final networkFailure = NotaryClient(
      'http://notary.test',
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await expectLater(
      networkFailure.submit(hash),
      throwsA(isA<NotaryClientException>()),
    );
    final timeoutFailure = NotaryClient(
      'http://notary.test',
      timeout: const Duration(milliseconds: 1),
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return success(fixture(), 201);
      }),
    );
    await expectLater(
      timeoutFailure.submit(hash),
      throwsA(isA<NotaryClientException>()),
    );
  });

  test('status uses the existing service route', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/agreements/status/$hash');
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {'status': 'pending'},
        }),
        200,
      );
    });
    final status = await NotaryClient(
      'http://notary.test',
      client: client,
    ).status(hash);
    expect(status['status'], 'pending');
  });
}
