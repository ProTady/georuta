import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../application/tickets_controllers.dart';
import '../data/models/reserva.dart';
import '../data/tickets_repository.dart';

class ConfirmarReservaScreen extends ConsumerStatefulWidget {
  const ConfirmarReservaScreen({
    super.key,
    required this.reservaId,
    this.reservaInicial,
  });

  final String reservaId;
  final Reserva? reservaInicial;

  @override
  ConsumerState<ConfirmarReservaScreen> createState() =>
      _ConfirmarReservaScreenState();
}

class _ConfirmarReservaScreenState
    extends ConsumerState<ConfirmarReservaScreen> {
  late Reserva? _reserva = widget.reservaInicial;
  Timer? _timer;
  int _segundos = 0;
  bool _cargando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_reserva != null) {
      _segundos = _reserva!.segundosRestantes;
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_segundos > 0) _segundos--;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _confirmar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final res = await ref.read(ticketsRepositoryProvider).confirmar(widget.reservaId);
      ref.read(compraSeleccionProvider.notifier).reset();
      ref.invalidate(misBoletosProvider);
      if (!mounted) return;
      context.go(AppRoutes.boletos, extra: res.boletos);
    } on TicketsException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cancelar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ref.read(ticketsRepositoryProvider).cancelar(widget.reservaId);
      ref.read(compraSeleccionProvider.notifier).reset();
      if (!mounted) return;
      context.pop();
    } on TicketsException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  @override
  Widget build(BuildContext context) {
    final r = _reserva;
    if (r == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Confirmar pago')),
        body: const Center(
          child: Text('No hay reserva. Vuelve a la búsqueda.'),
        ),
      );
    }
    final expirada = _segundos <= 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar pago')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Reserva creada',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    SelectableText('ID: ${r.id}',
                        style: const TextStyle(fontSize: 12)),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Asientos'),
                        Text(r.items.map((i) => i.asientoNumero).join(', ')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                        Text(
                          'S/ ${r.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (expirada ? AppColors.danger : AppColors.warning)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer,
                      color: expirada ? AppColors.danger : AppColors.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      expirada
                          ? 'La reserva expiró. Cancela y crea una nueva.'
                          : 'Tienes ${_fmt(_segundos)} para confirmar el pago.',
                      style: TextStyle(
                          color: expirada
                              ? AppColors.danger
                              : AppColors.warning,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Esta es una confirmación simulada. '
              'En producción se integrará la pasarela de pagos.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            if (_error != null) ...[
              Text(_error!,
                  style: const TextStyle(color: AppColors.danger)),
              const SizedBox(height: 12),
            ],
            ElevatedButton.icon(
              onPressed: (_cargando || expirada) ? null : _confirmar,
              icon: const Icon(Icons.payment),
              label: _cargando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirmar pago'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _cargando ? null : _cancelar,
              child: const Text('Cancelar reserva'),
            ),
          ],
        ),
      ),
    );
  }
}
