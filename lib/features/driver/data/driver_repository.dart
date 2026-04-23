import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../trips/data/models/viaje.dart';
import 'models/vehiculo.dart';

class DriverException implements Exception {
  final String message;
  DriverException(this.message);
  @override
  String toString() => message;
}

class DriverRepository {
  DriverRepository(this._api);
  final ApiClient _api;

  Future<List<Vehiculo>> getVehiculos() async {
    try {
      final res = await _api.dio.get('/api/fleet/vehiculos/');
      final data = res.data;
      final list = data is List ? data : (data['results'] as List? ?? const []);
      return list
          .map((e) => Vehiculo.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw DriverException(_err(e));
    }
  }

  Future<Viaje> abrirViaje({
    required String rutaId,
    required String vehiculoId,
    required String origenParaderoId,
  }) async {
    try {
      final res = await _api.dio.post(
        '/api/driver/viajes/abrir/',
        data: {
          'ruta_id': rutaId,
          'vehiculo_id': vehiculoId,
          'paradero_origen_id': origenParaderoId,
          'origen_paradero_id': origenParaderoId,
        },
      );
      return Viaje.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw DriverException(_err(e));
    }
  }

  Future<Viaje> salirViaje(String viajeId) async {
    try {
      final res = await _api.dio.post('/api/driver/viajes/$viajeId/salir/');
      return Viaje.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw DriverException(_err(e));
    }
  }

  Future<Viaje> cancelarViaje(String viajeId) async {
    try {
      final res = await _api.dio.post('/api/driver/viajes/$viajeId/cancelar/');
      return Viaje.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw DriverException(_err(e));
    }
  }

  String _err(DioException e) {
    final d = e.response?.data;
    if (d is Map && d['detail'] is String) return d['detail'] as String;
    if (d is Map) return d.values.first.toString();
    return 'Error de red. Intenta de nuevo.';
  }
}
