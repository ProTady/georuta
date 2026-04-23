import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../../trips/application/trips_controller.dart';
import '../../trips/data/models/paradero.dart';
import '../../trips/data/models/ruta.dart';
import '../application/driver_controllers.dart';
import '../data/driver_repository.dart';
import '../data/models/vehiculo.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  String? _rutaId;
  String? _origenId;
  String? _vehiculoId;
  bool _loading = false;
  String? _error;

  Future<void> _abrir() async {
    if (_rutaId == null || _origenId == null || _vehiculoId == null) {
      setState(() => _error = 'Elige ruta, paradero y vehículo.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final viaje = await ref.read(driverRepositoryProvider).abrirViaje(
            rutaId: _rutaId!,
            vehiculoId: _vehiculoId!,
            origenParaderoId: _origenId!,
          );
      if (!mounted) return;
      context.push('${AppRoutes.driverViaje}/${viaje.id}');
    } on DriverException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Paradero> _paraderosDeRuta(List<Ruta> rutas, String? rutaId) {
    if (rutaId == null) return const [];
    final r = rutas.where((x) => x.id == rutaId).firstOrNull;
    return r?.paraderos.map((rp) => rp.paradero).toList() ?? const [];
  }

  @override
  Widget build(BuildContext context) {
    final user = (ref.watch(authControllerProvider) as AuthAuthenticated?)?.user;
    final rutasAsync = ref.watch(rutasProvider);
    final vehiculosAsync = ref.watch(vehiculosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel conductor'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hola, ${user?.nombres ?? 'Conductor'} 🚐',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Abre un viaje para empezar a tomar pasajeros.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Ponerme disponible',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          rutasAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error cargando rutas: $e',
                style: const TextStyle(color: AppColors.danger)),
            data: (rutas) {
              final paraderos = _paraderosDeRuta(rutas, _rutaId);
              return Column(children: [
                DropdownButtonFormField<String>(
                  value: _rutaId,
                  decoration: const InputDecoration(labelText: 'Ruta'),
                  items: rutas
                      .map((r) => DropdownMenuItem(
                          value: r.id, child: Text(r.nombre)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _rutaId = v;
                    _origenId = null;
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _origenId,
                  decoration: const InputDecoration(
                      labelText: 'Paradero donde esperas'),
                  items: paraderos
                      .map((p) => DropdownMenuItem(
                          value: p.id, child: Text(p.nombre)))
                      .toList(),
                  onChanged: (v) => setState(() => _origenId = v),
                ),
              ]);
            },
          ),
          const SizedBox(height: 12),
          vehiculosAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error cargando vehículos: $e',
                style: const TextStyle(color: AppColors.danger)),
            data: (vehiculos) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: _vehiculoId,
                    decoration: const InputDecoration(labelText: 'Vehículo'),
                    items: vehiculos
                        .map((v) => DropdownMenuItem(
                              value: v.id,
                              child: Text(
                                  '${v.descripcion} · ${v.capacidadAsientos} asientos'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _vehiculoId = v),
                  ),
                  const SizedBox(height: 8),
                  if (_vehiculoId != null)
                    OutlinedButton.icon(
                      onPressed: () => context.push(
                        '${AppRoutes.driverLayout}/$_vehiculoId',
                        extra: vehiculos.firstWhere((v) => v.id == _vehiculoId),
                      ),
                      icon: const Icon(Icons.grid_view),
                      label: const Text('Editar layout del vehículo'),
                    ),
                ],
              );
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loading ? null : _abrir,
            icon: _loading
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_circle),
            label: const Text('Abrir viaje y tomar pasajeros'),
          ),
        ],
      ),
    );
  }
}

extension _ListX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
