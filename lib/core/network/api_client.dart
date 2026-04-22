import 'package:dio/dio.dart';

import '../config/env.dart';
import '../storage/token_storage.dart';

class ApiClient {
  final Dio dio;
  final TokenStorage _tokens;

  ApiClient(this._tokens) : dio = Dio(BaseOptions(
          baseUrl: Env.apiBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {'Accept': 'application/json'},
        )) {
    dio.interceptors.add(_AuthInterceptor(dio, _tokens));
  }
}

class _AuthInterceptor extends QueuedInterceptor {
  _AuthInterceptor(this._dio, this._tokens);

  final Dio _dio;
  final TokenStorage _tokens;

  static const _skipAuthPaths = <String>{
    '/api/auth/login/',
    '/api/auth/register/',
    '/api/auth/refresh/',
    '/api/health/',
  };

  bool _isSkipped(String path) => _skipAuthPaths.any(path.endsWith);

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    if (!_isSkipped(options.path)) {
      final access = await _tokens.readAccess();
      if (access != null && access.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $access';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;
    final request = err.requestOptions;

    final is401 = response?.statusCode == 401;
    final alreadyRetried = request.extra['_retried'] == true;

    if (!is401 || alreadyRetried || _isSkipped(request.path)) {
      return handler.next(err);
    }

    final refresh = await _tokens.readRefresh();
    if (refresh == null || refresh.isEmpty) {
      await _tokens.clear();
      return handler.next(err);
    }

    try {
      final refreshResponse = await _dio.post(
        '/api/auth/refresh/',
        data: {'refresh': refresh},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      final newAccess = refreshResponse.data['access'] as String?;
      final newRefresh = refreshResponse.data['refresh'] as String?;
      if (newAccess == null) {
        await _tokens.clear();
        return handler.next(err);
      }
      if (newRefresh != null) {
        await _tokens.saveTokens(access: newAccess, refresh: newRefresh);
      } else {
        await _tokens.saveAccessToken(newAccess);
      }

      request.headers['Authorization'] = 'Bearer $newAccess';
      request.extra['_retried'] = true;
      final retry = await _dio.fetch(request);
      return handler.resolve(retry);
    } catch (_) {
      await _tokens.clear();
      return handler.next(err);
    }
  }
}
