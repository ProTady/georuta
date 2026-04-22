import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import 'models/user.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class AuthResult {
  final User user;
  final String access;
  final String refresh;
  AuthResult(this.user, this.access, this.refresh);
}

class AuthRepository {
  AuthRepository(this._api, this._tokens);

  final ApiClient _api;
  final TokenStorage _tokens;

  Future<AuthResult> register({
    required String telefono,
    required String nombres,
    required String password,
    String? apellidos,
    String? email,
  }) async {
    final body = {
      'telefono': telefono.trim(),
      'nombres': nombres.trim(),
      'password': password,
      if (apellidos != null && apellidos.trim().isNotEmpty)
        'apellidos': apellidos.trim(),
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
    };
    try {
      final res = await _api.dio.post('/api/auth/register/', data: body);
      return _handleAuthResponse(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(_parseError(e));
    }
  }

  Future<AuthResult> login({
    required String telefono,
    required String password,
  }) async {
    try {
      final res = await _api.dio.post('/api/auth/login/', data: {
        'telefono': telefono.trim(),
        'password': password,
      });
      return _handleAuthResponse(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(_parseError(e));
    }
  }

  Future<User?> me() async {
    try {
      final res = await _api.dio.get('/api/auth/me/');
      return User.fromJson(res.data as Map<String, dynamic>);
    } on DioException {
      return null;
    }
  }

  Future<void> logout() async {
    await _tokens.clear();
  }

  Future<AuthResult> _handleAuthResponse(Map<String, dynamic> data) async {
    final tokens = data['tokens'] as Map<String, dynamic>;
    final access = tokens['access'] as String;
    final refresh = tokens['refresh'] as String;
    await _tokens.saveTokens(access: access, refresh: refresh);
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    return AuthResult(user, access, refresh);
  }

  String _parseError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      if (data['detail'] is String) return data['detail'] as String;
      final buffer = <String>[];
      data.forEach((k, v) {
        if (v is List) {
          buffer.add('$k: ${v.join(', ')}');
        } else {
          buffer.add('$k: $v');
        }
      });
      if (buffer.isNotEmpty) return buffer.join('\n');
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'No se pudo conectar al servidor. Verifica tu conexión.';
    }
    return 'Error inesperado. Intenta nuevamente.';
  }
}
