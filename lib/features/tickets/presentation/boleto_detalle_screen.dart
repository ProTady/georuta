import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../data/models/boleto.dart';

class BoletoDetalleScreen extends StatelessWidget {
  const BoletoDetalleScreen({super.key, required this.boleto});
  final Boleto boleto;

  @override
  Widget build(BuildContext context) {
    final fecha = DateFormat('EEEE d MMM yyyy', 'es').format(boleto.fechaViaje);
    final hora = DateFormat('HH:mm').format(boleto.horaSalida.toLocal());
    return Scaffold(
      appBar: AppBar(title: const Text('Boleto')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Text(
                      boleto.rutaNombre,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text('${boleto.origenNombre} → ${boleto.destinoNombre}',
                        style: const TextStyle(
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 18),
                    // QR
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: QrImageView(
                        data: boleto.qrToken,
                        version: QrVersions.auto,
                        size: 220,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      boleto.qrToken,
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                          letterSpacing: 0.5),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _row('Asiento', '${boleto.asientoNumero}'),
                    _row('Fecha', fecha),
                    _row('Hora de salida', hora),
                    _row('Precio', 'S/ ${boleto.precio.toStringAsFixed(2)}'),
                    _row('Estado', boleto.estado),
                    _row('Emitido', DateFormat('d MMM · HH:mm', 'es')
                        .format(boleto.fechaEmision.toLocal())),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Muestra este QR al conductor para abordar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: const TextStyle(color: AppColors.textSecondary)),
            Flexible(
                child: Text(v,
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}
