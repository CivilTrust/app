import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'signed_commitment_token.dart';

class NotaryClientException implements Exception {
  const NotaryClientException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class NotaryClient {
  NotaryClient(
    this.baseUrl, {
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();
  final String baseUrl;
  final Duration timeout;
  final http.Client _client;

  Future<SignedCommitmentToken> submit(String documentHash) async {
    _checkHash(documentHash);
    final response = await _request(
      () => _client.post(
        _uri('/api/v1/agreements/submit'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'agreementHash': documentHash}),
      ),
    );
    final sct = SignedCommitmentToken.fromJson(_data(response)['sct']);
    if (!sct.matchesAgreementHash(documentHash)) {
      throw const FormatException(
        'SCT agreementHash does not match the PDF hash',
      );
    }
    return sct;
  }

  Future<Map<String, dynamic>> status(String documentHash) async {
    _checkHash(documentHash);
    final response = await _request(
      () => _client.get(_uri('/api/v1/agreements/status/$documentHash')),
    );
    return _data(response);
  }

  void _checkHash(String hash) {
    if (!RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(hash)) {
      throw const FormatException('agreementHash must be a 32-byte hex string');
    }
  }

  Uri _uri(String path) =>
      Uri.parse('${baseUrl.replaceFirst(RegExp(r'/$'), '')}$path');

  Future<http.Response> _request(Future<http.Response> Function() send) async {
    try {
      return await send().timeout(timeout);
    } on TimeoutException {
      throw const NotaryClientException('Notary request timed out');
    } on http.ClientException catch (error) {
      throw NotaryClientException('Notary network error: $error');
    }
  }

  Map<String, dynamic> _data(http.Response response) {
    Object? value;
    try {
      value = jsonDecode(response.body);
    } on FormatException {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        throw const FormatException('Notary response is not valid JSON');
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = value is Map ? value['error'] : null;
      throw NotaryClientException(
        error is String && error.isNotEmpty
            ? 'Notary HTTP ${response.statusCode}: $error'
            : 'Notary HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
    if (value is! Map<String, dynamic> || value['success'] != true) {
      throw const FormatException('Notary response has no success envelope');
    }
    final data = value['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Notary response data must be an object');
    }
    return data;
  }
}
