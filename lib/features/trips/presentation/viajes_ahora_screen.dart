import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../tickets/application/tickets_controllers.dart';
import '../application/trips_controller.dart';
import '../data/models/paradero.dart';
import '../data/models/ruta.dart';
import '../data/models/viaje.dart';
import '../data/trips_repository.dart';

class ViajesAhoraScreen extends ConsumerStatefulWidget {
  const ViajesAhoraScreen({super.key});

  @override
  ConsumerState<ViajesAhoraScreen> createState() => _ViajesAhoraScreenState();
}

class _ViajesAhoraScreenState extends ConsumerState<ViajesAhoraScreen> {
  String? _rutaId;
  String? _origenId;
  String? _destinoId;
  bool _loading = false;
  String? _error;
  List<Viaje> _viajes = const [];
  Timer? _auto;

  @override
  void initState() {
    super.initState();
    _auto = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_rutaId != null) _buscar();
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    super.dispose();
  }

  Future<void> _buscar() async {
    if (_rutaId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref.read(tripsRepositoryProvider).getViajesAbiertos(
            rutaId: _rutaId,
            origenId: _origenId,
            destinoId: _destinoId,
          );
      setState(() => _viajes = list);
    } on TripsException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Paradero> _paraderos(List<Ruta> rutas) {
    if (_rutaId == null) return const [];
    final r = rutas.where((x) => x.id == _rutaId).firstOrNull;
    return r?.paraderos.map((rp) => rp.paradero).toList() ?? const [];
  }

  void _irAlViaje(Viaje v) {
    if (_origenId != null && _destinoId != null) {
      ref.read(compraSeleccionProvider.notifier)
          .setOrigenDestino(_origenId, _destinoId);
    }
    context.push('${AppRoutes.viaje}/${v.id}');
  }

  @override
  Widget build(BuildContext context) {
    final rutasAsync = ref.watch(rutasProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Viajes disponibles ahora')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          rutasAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error cargando rutas: $e',
                style: const TextStyle(color: AppColors.danger)),
            data: (rutas) {
              final paraderos = _paraderos(rutas);
              return Column(children: [
                DropdownButtonFormField<String>(
                  value: _rutaId,
                  decoration: const InputDecoration(labelText: 'Ruta'),
                  items: rutas
                      .map((r) => DropdownMenuItem(
                          value: r.id, child: Text(r.nombre)))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _rutaId = v;
                      _origenId = null;
                      _destinoId = null;
                    });
                    _buscar();
                  },
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _origenId,
                      decoration:
                          const InputDecoration(labelText: 'Subes en'),
                      items: paraderos
                          .map((p) => DropdownMenuItem(
                              value: p.id, child: Text(p.nombre)))
                          .toList(),
                      onChanged: (v) {
                        setState(() => _origenId = v);
                        _buscar();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _destinoId,
                      decoration:
                          const InputDecoration(labelText: 'Bajas en'),
                      items: paraderos
                          .map((p) => DropdownMenuItem(
                              value: p.id, child: Text(p.nombre)))
                          .toList(),
                      onChanged: (v) {
                        setState(() => _destinoId = v);
                        _buscar();
                      },
                    ),
                  ),
                ]),
              ]);
            },
          ),
          const SizedBox(height: 16),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          const SizedBox(height: 8),
          if (_rutaId != null && !_loading && _viajes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No hay carros disponibles ahora.\n'
                  'Vuelve a intentar en unos minutos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          ..._viajes.map(
            (v) => _ViajeAbiertoCard(v: v, onTap: () => _irAlViaje(v)),
          ),
        ],
      ),
    );
  }
}

class _ViajeAbiertoCard extends StatelessWidget {
  const _ViajeAbiertoCard({required this.v, required this.onTap});
  final Viaje v;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cap = v.capacidadTotal;
    final vendidos = v.asientosVendidos;
    final pct = cap == 0 ? 0.0 : (vendidos / cap).clamp(0.0, 1.0);
    final tarifaTxt =
        v.tarifa != null ? 'S/ ${v.tarifa!.toStringAsFixed(2)}' : '—';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.directions_bus, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(v.vehiculoPlaca ?? 'Carro',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                _EtaBadge(minutos: v.etaMinutos),
              ]),
              const SizedBox(height: 6),
              Text(
                v.origenActualNombre != null
                    ? 'Esperando en ${v.origenActualNombre}'
                    : v.rutaNombre,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: pct,
                backgroundColor: AppColors.surfaceElevated,
                color: AppColors.primary,
                minHeight: 8,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$vendidos / $cap ocupados',
                      style: const TextStyle(fontSize: 12)),
                  Text('Tarifa $tarifaTxt',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EtaBadge extends StatelessWidget {
  const _EtaBadge({required this.minutos});
  final int minutos;
  @override
  Widget build(BuildContext context) {
    final color = minutos <= 5
        ? AppColors.primary
        : (minutos <= 15 ? AppColors.warning : AppColors.textSecondary);
    final txt = minutos <= 0 ? 'Sale ya' : '~$minutos min';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.timer, size: 14, color: color),
        const SizedBox(width: 4),
        Text(txt,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w600, fontSize: 12)),
      ]),
    );
  }
}

extension _ListX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
