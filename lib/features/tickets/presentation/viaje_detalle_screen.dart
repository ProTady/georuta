import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../trips/application/trips_controller.dart';
import '../../trips/data/models/paradero.dart';
import '../../trips/data/models/ruta.dart';
import '../application/tickets_controllers.dart';
import '../data/models/asiento.dart';
import '../data/tickets_repository.dart';

class ViajeDetalleScreen extends ConsumerStatefulWidget {
  const ViajeDetalleScreen({super.key, required this.viajeId});
  final String viajeId;

  @override
  ConsumerState<ViajeDetalleScreen> createState() => _ViajeDetalleScreenState();
}

class _ViajeDetalleScreenState extends ConsumerState<ViajeDetalleScreen> {
  bool _reservando = false;
  String? _error;

  Future<void> _reservar(ViajeDetalle v) async {
    final sel = ref.read(compraSeleccionProvider);
    if (sel.origenId == null || sel.destinoId == null) {
      setState(() => _error = 'Elige origen y destino.');
      return;
    }
    if (sel.asientos.isEmpty) {
      setState(() => _error = 'Selecciona al menos un asiento.');
      return;
    }
    setState(() {
      _reservando = true;
      _error = null;
    });
    try {
      final reserva = await ref.read(ticketsRepositoryProvider).reservar(
            viajeId: v.id,
            origenId: sel.origenId!,
            destinoId: sel.destinoId!,
            asientos: sel.asientos.toList()..sort(),
          );
      if (!mounted) return;
      context.push('${AppRoutes.reserva}/${reserva.id}', extra: reserva);
    } on TicketsException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _reservando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viajeAsync = ref.watch(viajeDetalleProvider(widget.viajeId));
    final rutasAsync = ref.watch(rutasProvider);
    final sel = ref.watch(compraSeleccionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del viaje')),
      body: viajeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error: $e',
                style: const TextStyle(color: AppColors.danger)),
          ),
        ),
        data: (v) {
          final paraderos = _paraderosDeRuta(rutasAsync.valueOrNull, v.rutaId);
          final tarifa = v.tarifaPara(sel.origenId, sel.destinoId);
          final total = _calcularTotal(sel.asientos.length, tarifa);
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(viajeDetalleProvider(widget.viajeId));
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ViajeHeader(v: v),
                const SizedBox(height: 16),
                _OrigenDestinoPicker(
                  paraderos: paraderos,
                  origenId: sel.origenId,
                  destinoId: sel.destinoId,
                  onChanged: (o, d) => ref
                      .read(compraSeleccionProvider.notifier)
                      .setOrigenDestino(o, d),
                ),
                const SizedBox(height: 20),
                const Text('Elige tus asientos',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const _Leyenda(),
                const SizedBox(height: 12),
                _AsientosGrid(
                  asientos: v.asientos,
                  seleccion: sel.asientos,
                  onTap: (n) =>
                      ref.read(compraSeleccionProvider.notifier).toggleAsiento(n),
                ),
                const SizedBox(height: 20),
                _ResumenCompra(
                  cantidad: sel.asientos.length,
                  tarifa: tarifa,
                  total: total,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(color: AppColors.danger)),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _reservando || sel.asientos.isEmpty
                      ? null
                      : () => _reservar(v),
                  child: _reservando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Reservar y pagar'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Paradero> _paraderosDeRuta(List<Ruta>? rutas, String rutaId) {
    if (rutas == null) return const [];
    final ruta = rutas.where((r) => r.id == rutaId).firstOrNull;
    return ruta?.paraderos.map((rp) => rp.paradero).toList() ?? const [];
  }

  double? _calcularTotal(int n, double? tarifa) {
    if (tarifa == null || n == 0) return null;
    return tarifa * n;
  }
}

// ---------------------------------------------------------------------------

class _ViajeHeader extends StatelessWidget {
  const _ViajeHeader({required this.v});
  final ViajeDetalle v;
  @override
  Widget build(BuildContext context) {
    final hora = DateFormat('HH:mm').format(v.horaSalidaProgramada.toLocal());
    final fecha = DateFormat('EEEE d MMM yyyy', 'es').format(v.fechaViaje);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(v.rutaNombre,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.calendar_today, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(fecha),
              const SizedBox(width: 14),
              const Icon(Icons.access_time, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(hora,
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.event_seat, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text('${v.asientosDisponibles}/${v.capacidadTotal} libres'),
              if (v.vehiculoPlaca != null) ...[
                const SizedBox(width: 14),
                const Icon(Icons.directions_bus,
                    size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(v.vehiculoPlaca!),
              ],
            ]),
          ],
        ),
      ),
    );
  }
}

class _OrigenDestinoPicker extends StatelessWidget {
  const _OrigenDestinoPicker({
    required this.paraderos,
    required this.origenId,
    required this.destinoId,
    required this.onChanged,
  });
  final List<Paradero> paraderos;
  final String? origenId;
  final String? destinoId;
  final void Function(String?, String?) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      DropdownButtonFormField<String>(
        value: origenId,
        decoration: const InputDecoration(labelText: 'Subes en'),
        items: paraderos
            .map((p) => DropdownMenuItem(value: p.id, child: Text(p.nombre)))
            .toList(),
        onChanged: (v) => onChanged(v, destinoId),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: destinoId,
        decoration: const InputDecoration(labelText: 'Bajas en'),
        items: paraderos
            .map((p) => DropdownMenuItem(value: p.id, child: Text(p.nombre)))
            .toList(),
        onChanged: (v) => onChanged(origenId, v),
      ),
    ]);
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda();
  @override
  Widget build(BuildContext context) {
    Widget tag(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                  color: c, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text(t, style: const TextStyle(fontSize: 12)),
        ]);
    return Wrap(spacing: 16, runSpacing: 6, children: [
      tag(AppColors.surfaceElevated, 'Libre'),
      tag(AppColors.primary, 'Seleccionado'),
      tag(AppColors.warning, 'Reservado'),
      tag(AppColors.danger, 'Vendido'),
    ]);
  }
}

class _AsientosGrid extends StatelessWidget {
  const _AsientosGrid({
    required this.asientos,
    required this.seleccion,
    required this.onTap,
  });
  final List<Asiento> asientos;
  final Set<int> seleccion;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: asientos.length,
      itemBuilder: (ctx, i) {
        final a = asientos[i];
        final selected = seleccion.contains(a.numero);
        Color color;
        switch (a.estado) {
          case AsientoEstado.libre:
            color = selected ? AppColors.primary : AppColors.surfaceElevated;
            break;
          case AsientoEstado.reservado:
            color = AppColors.warning;
            break;
          case AsientoEstado.vendido:
            color = AppColors.danger;
            break;
        }
        final onTapFn =
            a.estado == AsientoEstado.libre ? () => onTap(a.numero) : null;
        return Material(
          color: color,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTapFn,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_seat, color: Colors.white),
                  const SizedBox(height: 2),
                  Text(
                    '${a.numero}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ResumenCompra extends StatelessWidget {
  const _ResumenCompra({
    required this.cantidad,
    required this.tarifa,
    required this.total,
  });
  final int cantidad;
  final double? tarifa;
  final double? total;

  @override
  Widget build(BuildContext context) {
    final tarifaTxt =
        tarifa != null ? 'S/ ${tarifa!.toStringAsFixed(2)}' : 'N/D';
    final totalTxt =
        total != null ? 'S/ ${total!.toStringAsFixed(2)}' : 'S/ —';
    return Card(
      color: AppColors.surfaceElevated,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Asientos'),
              Text('$cantidad × $tarifaTxt'),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              Text(totalTxt,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: AppColors.primary)),
            ],
          ),
        ]),
      ),
    );
  }
}
