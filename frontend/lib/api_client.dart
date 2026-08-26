import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'config.dart';
import 'models.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;
}

class LoginData {
  const LoginData({required this.token, required this.username});

  final String token;
  final String username;
}

class ApiClient {
  ApiClient({this.token});

  final String? token;
  static const _uuid = Uuid();

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$apiBaseUrl$path').replace(queryParameters: query);

  Future<LoginData> login(String username, String password) async {
    final response = await http.post(
      _uri('/auth/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    final json = _decode(response);
    return LoginData(
      token: json['token'] as String,
      username: json['username'] as String,
    );
  }

  Future<String> validateSession() async {
    final json = await _authorizedGet('/auth/session');
    return json['username'] as String;
  }

  Future<void> logout() async {
    final response = await http.post(_uri('/auth/logout'), headers: _headers);
    if (response.statusCode != 204) {
      _decode(response);
    }
  }

  Future<DayData> getDay(DateTime date) async {
    final json = await _authorizedGet('/day', {'date': _formatDate(date)});
    return DayData.fromJson(json);
  }

  Future<CommandResult> sendCommand(
    String transcript, {
    ConfirmationData? confirmation,
  }) async {
    final response = await http.post(
      _uri('/commands'),
      headers: _headers,
      body: jsonEncode({
        'request_id': _uuid.v4(),
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
        'timezone': userTimezone,
        'source': 'voice',
        'transcript': transcript,
        if (confirmation != null) 'confirmation_context': confirmation.toJson(),
      }),
    );
    return CommandResult.fromJson(_decode(response));
  }

  Future<Map<String, dynamic>> _authorizedGet(
    String path, [
    Map<String, String>? query,
  ]) async {
    final response = await http.get(_uri(path, query), headers: _headers);
    return _decode(response);
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body = {};
    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    final detail = body['detail'];
    final code = detail is Map<String, dynamic> ? detail['code'] : null;
    throw ApiException(
      _messageFor(response.statusCode, code as String?),
      statusCode: response.statusCode,
    );
  }

  String _messageFor(int statusCode, String? code) {
    if (statusCode == 401) {
      return 'Sua sessão não é mais válida. Entre novamente.';
    }
    if (statusCode == 409) {
      return code == 'invalid_state'
          ? 'Essa ação não é permitida no estado atual da tarefa.'
          : 'A solicitação ainda está sendo processada.';
    }
    if (statusCode == 410) {
      return 'A confirmação expirou. Envie o comando novamente.';
    }
    return 'Não foi possível concluir a solicitação agora.';
  }

  String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
