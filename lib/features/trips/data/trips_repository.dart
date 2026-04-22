import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import 'models/ruta.dart';
import 'models/viaje.dart';

class TripsException implements Exception {
  final String message;
  TripsException(this.message);
  @override
  String toString() => message;
}

class TripsRepository {
  TripsRepository(this._api);
  final ApiClient _api;

  Future<List<Ruta>> getRutas() async {
    try {
      final res = await _api.dio.get('/api/routes/');
      final data = res.data;
      final list = data is List ? data : (data['results'] as List? ?? const []);
      return list
          .map((e) => Ruta.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw TripsException(_parseError(e));
    }
  }

  Future<List<Viaje>> searchViajes({
    String? rutaId,
    String? origenId,
    String? destinoId,
    DateTime? fecha,
  }) async {
    final params = <String, dynamic>{};
    if (rutaId != null) params['ruta_id'] = rutaId;
    if (origenId != null) params['origen_id'] = origenId;
    if (destinoId != null) params['destino_id'] = destinoId;
    if (fecha != null) {
      params['fecha'] = DateFormat('yyyy-MM-dd').format(fecha);
    }
    try {
      final res = await _api.dio.get(
        '/api/trips/search/',
        queryParameters: params,
      );
      final data = res.data;
      final list = data is List ? data : (data['results'] as List? ?? const []);
      return list
          .map((e) => Viaje.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw TripsException(_parseError(e));
    }
  }

  String _parseError(DioException e) {
    final d = e.response?.data;
    if (d is Map && d['detail'] is String) return d['detail'] as String;
    return 'Error de red. Intenta de nuevo.';
  }
}
