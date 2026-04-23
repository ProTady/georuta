import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import 'models/asiento.dart';
import 'models/boleto.dart';
import 'models/reserva.dart';

class TicketsException implements Exception {
  final String message;
  TicketsException(this.message);
  @override
  String toString() => message;
}

class ConfirmarResult {
  final Reserva reserva;
  final List<Boleto> boletos;
  ConfirmarResult(this.reserva, this.boletos);
}

class TicketsRepository {
  TicketsRepository(this._api);
  final ApiClient _api;

  Future<ViajeDetalle> getViajeDetalle(String viajeId) async {
    try {
      final res = await _api.dio.get('/api/trips/viajes/$viajeId/');
      return ViajeDetalle.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw TicketsException(_err(e));
    }
  }

  Future<Reserva> reservar({
    required String viajeId,
    required String origenId,
    required String destinoId,
    required List<int> asientos,
  }) async {
    try {
      final res = await _api.dio.post(
        '/api/trips/viajes/$viajeId/reservar/',
        data: {
          'paradero_origen_id': origenId,
          'paradero_destino_id': destinoId,
          'asientos': asientos,
        },
      );
      return Reserva.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw TicketsException(_err(e));
    }
  }

  Future<ConfirmarResult> confirmar(String reservaId) async {
    try {
      final res = await _api.dio.post('/api/reservas/$reservaId/confirmar/');
      final data = res.data as Map<String, dynamic>;
      final reserva = Reserva.fromJson(data['reserva'] as Map<String, dynamic>);
      final boletos = (data['boletos'] as List)
          .map((e) => Boleto.fromJson(e as Map<String, dynamic>))
          .toList();
      return ConfirmarResult(reserva, boletos);
    } on DioException catch (e) {
      throw TicketsException(_err(e));
    }
  }

  Future<Reserva> cancelar(String reservaId) async {
    try {
      final res = await _api.dio.post('/api/reservas/$reservaId/cancelar/');
      return Reserva.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw TicketsException(_err(e));
    }
  }

  Future<List<Boleto>> misBoletos() async {
    try {
      final res = await _api.dio.get('/api/boletos/mis/');
      final data = res.data;
      final list = data is List ? data : (data['results'] as List? ?? const []);
      return list
          .map((e) => Boleto.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw TicketsException(_err(e));
    }
  }

  String _err(DioException e) {
    final d = e.response?.data;
    if (d is Map && d['detail'] is String) return d['detail'] as String;
    if (d is Map) return d.values.first.toString();
    return 'Error de red. Intenta de nuevo.';
  }
}
