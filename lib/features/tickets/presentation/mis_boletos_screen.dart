import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../application/tickets_controllers.dart';
import '../data/models/boleto.dart';

class MisBoletosScreen extends ConsumerWidget {
  const MisBoletosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(misBoletosProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mis boletos')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(misBoletosProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error: $e',
                    style: const TextStyle(color: AppColors.danger)),
              ),
            ],
          ),
          data: (boletos) {
            if (boletos.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 80),
                Icon(Icons.confirmation_number_outlined,
                    size: 60, color: AppColors.textMuted),
                SizedBox(height: 12),
                Center(
                  child: Text('Aún no tienes boletos.',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              ]);
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: boletos.length,
              itemBuilder: (ctx, i) => _BoletoTile(boleto: boletos[i]),
            );
          },
        ),
      ),
    );
  }
}

class _BoletoTile extends StatelessWidget {
  const _BoletoTile({required this.boleto});
  final Boleto boleto;

  @override
  Widget build(BuildContext context) {
    final hora = DateFormat('HH:mm').format(boleto.horaSalida.toLocal());
    final fecha = DateFormat('EEE d MMM', 'es').format(boleto.fechaViaje);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            context.push('${AppRoutes.boleto}/${boleto.id}', extra: boleto),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Asiento',
                          style: TextStyle(
                              color: AppColors.primary, fontSize: 10)),
                      Text('${boleto.asientoNumero}',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(boleto.rutaNombre,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('${boleto.origenNombre} → ${boleto.destinoNombre}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('$fecha · $hora',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('S/ ${boleto.precio.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  _EstadoChip(estado: boleto.estado),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  const _EstadoChip({required this.estado});
  final String estado;
  @override
  Widget build(BuildContext context) {
    Color c;
    switch (estado) {
      case 'VIGENTE':
        c = AppColors.success;
        break;
      case 'USADO':
        c = AppColors.textMuted;
        break;
      default:
        c = AppColors.danger;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(estado,
          style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}
