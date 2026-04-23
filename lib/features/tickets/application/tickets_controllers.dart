import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/models/asiento.dart';
import '../data/models/boleto.dart';
import '../data/tickets_repository.dart';

final ticketsRepositoryProvider = Provider<TicketsRepository>((ref) {
  return TicketsRepository(ref.watch(apiClientProvider));
});

/// Detalle de viaje (incluye asientos). Se refresca al invalidar.
final viajeDetalleProvider =
    FutureProvider.family<ViajeDetalle, String>((ref, viajeId) async {
  return ref.watch(ticketsRepositoryProvider).getViajeDetalle(viajeId);
});

/// Lista de boletos del usuario.
final misBoletosProvider = FutureProvider<List<Boleto>>((ref) async {
  return ref.watch(ticketsRepositoryProvider).misBoletos();
});

/// Selección de compra transitoria (ruta_id/origen_id/destino_id + asientos elegidos).
class CompraSeleccion {
  final String? origenId;
  final String? destinoId;
  final Set<int> asientos;

  const CompraSeleccion({
    this.origenId,
    this.destinoId,
    this.asientos = const {},
  });

  CompraSeleccion copyWith({
    String? origenId,
    String? destinoId,
    Set<int>? asientos,
  }) =>
      CompraSeleccion(
        origenId: origenId ?? this.origenId,
        destinoId: destinoId ?? this.destinoId,
        asientos: asientos ?? this.asientos,
      );
}

class CompraSeleccionController extends StateNotifier<CompraSeleccion> {
  CompraSeleccionController() : super(const CompraSeleccion());

  void setOrigenDestino(String? origenId, String? destinoId) {
    state = state.copyWith(
      origenId: origenId,
      destinoId: destinoId,
      asientos: const {},
    );
  }

  void toggleAsiento(int numero) {
    final next = Set<int>.from(state.asientos);
    if (next.contains(numero)) {
      next.remove(numero);
    } else {
      next.add(numero);
    }
    state = state.copyWith(asientos: next);
  }

  void reset() => state = const CompraSeleccion();
}

final compraSeleccionProvider =
    StateNotifierProvider<CompraSeleccionController, CompraSeleccion>((ref) {
  return CompraSeleccionController();
});
