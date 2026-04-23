import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../tickets/application/tickets_controllers.dart';
import '../application/trips_controller.dart';
import '../data/models/paradero.dart';
import '../data/models/ruta.dart';
import '../data/models/viaje.dart';

class TripSearchScreen extends ConsumerStatefulWidget {
  const TripSearchScreen({super.key});

  @override
  ConsumerState<TripSearchScreen> createState() => _TripSearchScreenState();
}

class _TripSearchScreenState extends ConsumerState<TripSearchScreen> {
  Ruta? _ruta;
  Paradero? _origen;
  Paradero? _destino;
  DateTime _fecha = DateTime.now();

  List<Paradero> get _paraderos =>
      _ruta?.paraderos.map((rp) => rp.paradero).toList() ?? const [];

  Future<void> _pickFecha() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
      locale: const Locale('es'),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  void _submit() {
    if (_ruta == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una ruta.')),
      );
      return;
    }
    if (_origen != null && _destino != null && _origen!.id == _destino!.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Origen y destino deben ser distintos.')),
      );
      return;
    }
    ref.read(tripSearchControllerProvider.notifier).search(
          rutaId: _ruta!.id,
          origenId: _origen?.id,
          destinoId: _destino?.id,
          fecha: _fecha,
        );
  }

  @override
  Widget build(BuildContext context) {
    final rutasAsync = ref.watch(rutasProvider);
    final search = ref.watch(tripSearchControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Buscar viaje')),
      body: rutasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBox(
          message: 'No se pudieron cargar las rutas.\n$e',
          onRetry: () => ref.invalidate(rutasProvider),
        ),
        data: (rutas) {
          if (rutas.isEmpty) {
            return const _ErrorBox(message: 'No hay rutas activas.');
          }
          // auto-seleccionar si solo hay una
          _ruta ??= rutas.first;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _RutaDropdown(
                value: _ruta,
                items: rutas,
                onChanged: (r) => setState(() {
                  _ruta = r;
                  _origen = null;
                  _destino = null;
                }),
              ),
              const SizedBox(height: 12),
              _ParaderoDropdown(
                label: 'Origen',
                value: _origen,
                items: _paraderos,
                onChanged: (p) => setState(() => _origen = p),
              ),
              const SizedBox(height: 12),
              _ParaderoDropdown(
                label: 'Destino',
                value: _destino,
                items: _paraderos,
                onChanged: (p) => setState(() => _destino = p),
              ),
              const SizedBox(height: 12),
              _FechaField(fecha: _fecha, onTap: _pickFecha),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: search.loading ? null : _submit,
                child: search.loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Buscar viajes'),
              ),
              const SizedBox(height: 24),
              _Results(
                state: search,
                onTapViaje: (v) {
                  // Persistir selección de origen/destino en el provider
                  // para que la pantalla de detalle la use al reservar.
                  ref.read(compraSeleccionProvider.notifier).setOrigenDestino(
                        _origen?.id,
                        _destino?.id,
                      );
                  context.push('${AppRoutes.viaje}/${v.id}');
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------

class _RutaDropdown extends StatelessWidget {
  const _RutaDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final Ruta? value;
  final List<Ruta> items;
  final ValueChanged<Ruta?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Ruta>(
      value: value,
      decoration: const InputDecoration(labelText: 'Ruta'),
      items: items
          .map((r) => DropdownMenuItem(value: r, child: Text(r.nombre)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _ParaderoDropdown extends StatelessWidget {
  const _ParaderoDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final Paradero? value;
  final List<Paradero> items;
  final ValueChanged<Paradero?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Paradero>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((p) => DropdownMenuItem(value: p, child: Text(p.nombre)))
          .toList(),
      onChanged: items.isEmpty ? null : onChanged,
    );
  }
}

class _FechaField extends StatelessWidget {
  const _FechaField({required this.fecha, required this.onTap});
  final DateTime fecha;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('EEEE d MMM yyyy', 'es').format(fecha);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Fecha del viaje',
          suffixIcon: Icon(Icons.calendar_today_outlined),
        ),
        child: Text(label),
      ),
    );
  }
}

// -----------------------------------------------------------------------------

class _Results extends StatelessWidget {
  const _Results({required this.state, required this.onTapViaje});
  final TripSearchState state;
  final void Function(Viaje) onTapViaje;

  @override
  Widget build(BuildContext context) {
    if (state.error != null) {
      return _ErrorBox(message: state.error!);
    }
    if (!state.searched) {
      return const _Hint('Elige una ruta y una fecha para buscar viajes.');
    }
    if (state.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.results.isEmpty) {
      return const _Hint('No hay viajes para los criterios indicados.');
    }
    return Column(
      children: state.results
          .map((v) => _ViajeCard(viaje: v, onTap: () => onTapViaje(v)))
          .toList(),
    );
  }
}

class _ViajeCard extends StatelessWidget {
  const _ViajeCard({required this.viaje, required this.onTap});
  final Viaje viaje;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hora = DateFormat('HH:mm').format(viaje.horaSalidaProgramada.toLocal());
    final fecha = DateFormat('d MMM', 'es').format(viaje.fechaViaje);
    final tarifa = viaje.tarifa != null
        ? 'S/ ${viaje.tarifa!.toStringAsFixed(2)}'
        : '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  hora,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  tarifa,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(viaje.rutaNombre,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.event_seat, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text('${viaje.asientosDisponibles}/${viaje.capacidadTotal} libres'),
                const SizedBox(width: 16),
                const Icon(Icons.calendar_today, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(fecha),
                if (viaje.vehiculoPlaca != null) ...[
                  const SizedBox(width: 16),
                  const Icon(Icons.directions_bus, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(viaje.vehiculoPlaca!),
                ],
              ],
            ),
            if (viaje.conductorNombre != null) ...[
              const SizedBox(height: 4),
              Text('Conductor: ${viaje.conductorNombre}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ],
        ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger)),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary)),
    );
  }
}
