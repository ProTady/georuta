import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../application/driver_controllers.dart';
import '../data/models/vehiculo.dart';

/// Estados de una celda del layout.
enum _CellKind { vacio, chofer, asiento }

class _Cell {
  _CellKind kind;
  int? numero;
  _Cell({this.kind = _CellKind.vacio, this.numero});
}

class LayoutEditorScreen extends ConsumerStatefulWidget {
  const LayoutEditorScreen({
    super.key,
    required this.vehiculoId,
    this.inicial,
  });
  final String vehiculoId;
  final Vehiculo? inicial;

  @override
  ConsumerState<LayoutEditorScreen> createState() => _LayoutEditorScreenState();
}

class _LayoutEditorScreenState extends ConsumerState<LayoutEditorScreen> {
  late int _filas;
  late int _columnas;
  late List<List<_Cell>> _grid;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final raw = widget.inicial?.layout;
    if (raw != null &&
        raw['filas'] is int &&
        raw['columnas'] is int &&
        raw['celdas'] is List) {
      final l = raw;
      _filas = l['filas'] as int;
      _columnas = l['columnas'] as int;
      _grid = List.generate(
        _filas,
        (i) => List.generate(_columnas, (j) {
          try {
            final row = (l['celdas'] as List)[i] as List;
            final c = row[j];
            if (c is Map) {
              if (c['tipo'] == 'CHOFER') return _Cell(kind: _CellKind.chofer);
              if (c['tipo'] == 'ASIENTO') {
                return _Cell(
                    kind: _CellKind.asiento,
                    numero: c['numero'] is int ? c['numero'] as int : null);
              }
            }
          } catch (_) {}
          return _Cell();
        }),
      );
    } else {
      _filas = 4;
      _columnas = 3;
      _grid = List.generate(
        _filas,
        (_) => List.generate(_columnas, (_) => _Cell()),
      );
    }
  }

  void _onTapCell(int i, int j) {
    setState(() {
      final c = _grid[i][j];
      // Rota: vacío → chofer → asiento → vacío
      if (c.kind == _CellKind.vacio) {
        c.kind = _CellKind.chofer;
        c.numero = null;
      } else if (c.kind == _CellKind.chofer) {
        c.kind = _CellKind.asiento;
        c.numero = _siguienteNumero();
      } else {
        c.kind = _CellKind.vacio;
        c.numero = null;
      }
      _renumerar();
    });
  }

  int _siguienteNumero() {
    final usados = <int>{};
    for (final row in _grid) {
      for (final c in row) {
        if (c.kind == _CellKind.asiento && c.numero != null) {
          usados.add(c.numero!);
        }
      }
    }
    var n = 1;
    while (usados.contains(n)) {
      n++;
    }
    return n;
  }

  void _renumerar() {
    // Renumera asientos en orden de lectura (fila a fila) para mantener consistencia.
    var n = 1;
    for (final row in _grid) {
      for (final c in row) {
        if (c.kind == _CellKind.asiento) {
          c.numero = n;
          n++;
        }
      }
    }
  }

  void _resize({int? filas, int? columnas}) {
    setState(() {
      _filas = filas ?? _filas;
      _columnas = columnas ?? _columnas;
      final nuevo = List.generate(
        _filas,
        (i) => List.generate(_columnas, (j) {
          if (i < _grid.length && j < _grid[i].length) return _grid[i][j];
          return _Cell();
        }),
      );
      _grid = nuevo;
      _renumerar();
    });
  }

  Map<String, dynamic> _serializar() {
    return {
      'filas': _filas,
      'columnas': _columnas,
      'celdas': _grid
          .map((row) => row.map((c) {
                switch (c.kind) {
                  case _CellKind.chofer:
                    return {'tipo': 'CHOFER'};
                  case _CellKind.asiento:
                    return {'tipo': 'ASIENTO', 'numero': c.numero};
                  case _CellKind.vacio:
                    return null;
                }
              }).toList())
          .toList(),
    };
  }

  Future<void> _guardar() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.put(
        '/api/fleet/vehiculos/${widget.vehiculoId}/layout/',
        data: _serializar(),
      );
      ref.invalidate(vehiculosProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Layout guardado.')),
      );
      context.pop();
    } on DioException catch (e) {
      final d = e.response?.data;
      setState(() => _error = d is Map
          ? (d['detail']?.toString() ?? d.values.first.toString())
          : 'Error al guardar.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Layout del vehículo'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _guardar,
            child: const Text('Guardar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Toca una celda para alternar: vacío → chofer → asiento → vacío. '
            'Los asientos se renumeran automáticamente.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _Stepper(
                    label: 'Filas',
                    value: _filas,
                    onMinus: _filas > 1 ? () => _resize(filas: _filas - 1) : null,
                    onPlus: _filas < 10 ? () => _resize(filas: _filas + 1) : null)),
            const SizedBox(width: 12),
            Expanded(
                child: _Stepper(
                    label: 'Columnas',
                    value: _columnas,
                    onMinus: _columnas > 1
                        ? () => _resize(columnas: _columnas - 1)
                        : null,
                    onPlus: _columnas < 6
                        ? () => _resize(columnas: _columnas + 1)
                        : null)),
          ]),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) {
            final cellSize = (constraints.maxWidth - 8 * (_columnas - 1)) /
                _columnas.clamp(1, 10);
            return Column(
              children: [
                const Text('Frente del vehículo',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 4),
                for (int i = 0; i < _filas; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int j = 0; j < _columnas; j++)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _CellTile(
                              cell: _grid[i][j],
                              size: cellSize.clamp(40, 80).toDouble(),
                              onTap: () => _onTapCell(i, j),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          }),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _saving ? null : _guardar,
            icon: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: const Text('Guardar layout'),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper(
      {required this.label,
      required this.value,
      required this.onMinus,
      required this.onPlus});
  final String label;
  final int value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(child: Text('$label: $value')),
          IconButton(
              onPressed: onMinus,
              icon: const Icon(Icons.remove),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32)),
          IconButton(
              onPressed: onPlus,
              icon: const Icon(Icons.add),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32)),
        ],
      ),
    );
  }
}

class _CellTile extends StatelessWidget {
  const _CellTile(
      {required this.cell, required this.size, required this.onTap});
  final _Cell cell;
  final double size;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    late Color color;
    late Widget content;
    switch (cell.kind) {
      case _CellKind.vacio:
        color = AppColors.surfaceElevated;
        content = const Icon(Icons.add, color: AppColors.textMuted, size: 18);
        break;
      case _CellKind.chofer:
        color = AppColors.warning;
        content = const Icon(Icons.drive_eta, color: Colors.white);
        break;
      case _CellKind.asiento:
        color = AppColors.primary;
        content = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_seat, color: Colors.white, size: 18),
            Text('${cell.numero ?? '?'}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        );
        break;
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: content,
      ),
    );
  }
}
