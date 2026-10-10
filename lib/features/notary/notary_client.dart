import 'dart:convert';

import 'package:http/http.dart' as http;

class NotaryClient {
  NotaryClient(this.baseUrl, {http.Client? client})
    : _client = client ?? http.Client();
  final String baseUrl;
  final http.Client _client;

  Future<Map<String, dynamic>> submit(String documentHash) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/agreements/submit'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'agreementHash': documentHash}),
    );
    final body = _body(response);
    final data = Map<String, dynamic>.from(body['data'] as Map);
    return Map<String, dynamic>.from(data['sct'] as Map);
  }

  Future<Map<String, dynamic>> status(String documentHash) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/agreements/status/$documentHash'),
    );
    final body = _body(response);
    return Map<String, dynamic>.from(body['data'] as Map);
  }

  Map<String, dynamic> _body(http.Response response) {
    final value = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        value is Map && value['error'] != null
            ? value['error'].toString()
            : 'Notary HTTP ${response.statusCode}',
      );
    }
    return Map<String, dynamic>.from(value as Map);
  }
}
