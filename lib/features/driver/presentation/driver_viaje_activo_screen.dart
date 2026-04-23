import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../tickets/application/tickets_controllers.dart';
import '../../tickets/data/models/asiento.dart';
import '../application/driver_controllers.dart';
import '../data/driver_repository.dart';

class DriverViajeActivoScreen extends ConsumerStatefulWidget {
  const DriverViajeActivoScreen({super.key, required this.viajeId});
  final String viajeId;

  @override
  ConsumerState<DriverViajeActivoScreen> createState() =>
      _DriverViajeActivoScreenState();
}

class _DriverViajeActivoScreenState
    extends ConsumerState<DriverViajeActivoScreen> {
  Timer? _refresh;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Refresco cada 8 seg para ver entrada/salida de pasajeros.
    _refresh = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) ref.invalidate(viajeDetalleProvider(widget.viajeId));
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _salir() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await ref.read(driverRepositoryProvider).salirViaje(widget.viajeId);
      if (!mounted) return;
      // Por ahora sólo notificamos; Fase 4.14 integrará tracking.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Viaje EN CURSO')),
      );
      ref.invalidate(viajeDetalleProvider(widget.viajeId));
    } on DriverException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _cancelar() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await ref.read(driverRepositoryProvider).cancelarViaje(widget.viajeId);
      if (!mounted) return;
      context.pop();
    } on DriverException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(viajeDetalleProvider(widget.viajeId));
    return Scaffold(
      appBar: AppBar(title: const Text('Mi viaje')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (v) {
          final libres = v.asientos
              .where((a) => a.estado == AsientoEstado.libre)
              .length;
          final vendidos = v.asientos
              .where((a) => a.estado == AsientoEstado.vendido)
              .length;
          final reservados = v.asientos
              .where((a) => a.estado == AsientoEstado.reservado)
              .length;
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(viajeDetalleProvider(widget.viajeId)),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v.rutaNombre,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('Estado: ${v.estado}',
                            style: const TextStyle(
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: _Metric(
                          label: 'Vendidos',
                          value: '$vendidos',
                          color: AppColors.danger)),
                  Expanded(
                      child: _Metric(
                          label: 'Reservados',
                          value: '$reservados',
                          color: AppColors.warning)),
                  Expanded(
                      child: _Metric(
                          label: 'Libres',
                          value: '$libres',
                          color: AppColors.primary)),
                ]),
                const SizedBox(height: 20),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!,
                        style: const TextStyle(color: AppColors.danger)),
                  ),
                ElevatedButton.icon(
                  onPressed: _working ? null : _salir,
                  icon: const Icon(Icons.directions_bus),
                  label: const Text('Salir ahora'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _working ? null : _cancelar,
                  child: const Text('Cancelar viaje'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Text(value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: const TextStyle(fontSize: 12)),
      ]),
    );
  }
}
