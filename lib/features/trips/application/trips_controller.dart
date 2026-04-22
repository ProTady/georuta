import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/models/ruta.dart';
import '../data/models/viaje.dart';
import '../data/trips_repository.dart';

final tripsRepositoryProvider = Provider<TripsRepository>((ref) {
  return TripsRepository(ref.watch(apiClientProvider));
});

/// Lista de rutas activas (se carga al entrar a la pantalla de búsqueda).
final rutasProvider = FutureProvider<List<Ruta>>((ref) async {
  return ref.watch(tripsRepositoryProvider).getRutas();
});

// ---- Estado de búsqueda ----
class TripSearchState {
  final bool loading;
  final List<Viaje> results;
  final String? error;
  final bool searched;

  const TripSearchState({
    this.loading = false,
    this.results = const [],
    this.error,
    this.searched = false,
  });

  TripSearchState copyWith({
    bool? loading,
    List<Viaje>? results,
    String? error,
    bool? searched,
  }) =>
      TripSearchState(
        loading: loading ?? this.loading,
        results: results ?? this.results,
        error: error,
        searched: searched ?? this.searched,
      );
}

class TripSearchController extends StateNotifier<TripSearchState> {
  TripSearchController(this._repo) : super(const TripSearchState());
  final TripsRepository _repo;

  Future<void> search({
    String? rutaId,
    String? origenId,
    String? destinoId,
    DateTime? fecha,
  }) async {
    state = state.copyWith(loading: true, error: null, searched: true);
    try {
      final r = await _repo.searchViajes(
        rutaId: rutaId,
        origenId: origenId,
        destinoId: destinoId,
        fecha: fecha,
      );
      state = state.copyWith(loading: false, results: r);
    } on TripsException catch (e) {
      state = state.copyWith(loading: false, results: const [], error: e.message);
    } catch (_) {
      state = state.copyWith(
        loading: false,
        results: const [],
        error: 'Error inesperado.',
      );
    }
  }

  void reset() => state = const TripSearchState();
}

final tripSearchControllerProvider =
    StateNotifierProvider<TripSearchController, TripSearchState>((ref) {
  return TripSearchController(ref.watch(tripsRepositoryProvider));
});
