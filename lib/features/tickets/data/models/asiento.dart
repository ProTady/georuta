enum AsientoEstado { libre, reservado, vendido }

AsientoEstado _parseEstado(String s) {
  switch (s) {
    case 'LIBRE':
      return AsientoEstado.libre;
    case 'RESERVADO':
      return AsientoEstado.reservado;
    case 'VENDIDO':
      return AsientoEstado.vendido;
    default:
      return AsientoEstado.libre;
  }
}

class Asiento {
  final String id;
  final int numero;
  final AsientoEstado estado;

  const Asiento({
    required this.id,
    required this.numero,
    required this.estado,
  });

  factory Asiento.fromJson(Map<String, dynamic> json) => Asiento(
        id: json['id'].toString(),
        numero: json['numero'] as int,
        estado: _parseEstado(json['estado'] as String),
      );
}

class TarifaTramo {
  final String origenId;
  final String destinoId;
  final double precio;
  const TarifaTramo({
    required this.origenId,
    required this.destinoId,
    required this.precio,
  });

  factory TarifaTramo.fromJson(Map<String, dynamic> json) => TarifaTramo(
        origenId: json['origen_id'].toString(),
        destinoId: json['destino_id'].toString(),
        precio: double.tryParse(json['precio'].toString()) ?? 0,
      );
}

/// Viaje con sus asientos (respuesta de /api/trips/viajes/<id>/).
class ViajeDetalle {
  final String id;
  final String rutaId;
  final String rutaNombre;
  final DateTime fechaViaje;
  final DateTime horaSalidaProgramada;
  final int capacidadTotal;
  final int asientosDisponibles;
  final String estado;
  final String? vehiculoPlaca;
  final String? conductorNombre;
  final double? tarifa;
  final List<Asiento> asientos;
  final List<TarifaTramo> tarifas;

  const ViajeDetalle({
    required this.id,
    required this.rutaId,
    required this.rutaNombre,
    required this.fechaViaje,
    required this.horaSalidaProgramada,
    required this.capacidadTotal,
    required this.asientosDisponibles,
    required this.estado,
    required this.asientos,
    this.vehiculoPlaca,
    this.conductorNombre,
    this.tarifa,
    this.tarifas = const [],
  });

  /// Busca el precio para el tramo origen→destino.
  double? tarifaPara(String? origenId, String? destinoId) {
    if (origenId == null || destinoId == null) return tarifa;
    for (final t in tarifas) {
      if (t.origenId == origenId && t.destinoId == destinoId) return t.precio;
    }
    return tarifa;
  }

  factory ViajeDetalle.fromJson(Map<String, dynamic> json) => ViajeDetalle(
        id: json['id'].toString(),
        rutaId: json['ruta'].toString(),
        rutaNombre: (json['ruta_nombre'] ?? '') as String,
        fechaViaje: DateTime.parse(json['fecha_viaje'] as String),
        horaSalidaProgramada:
            DateTime.parse(json['hora_salida_programada'] as String),
        capacidadTotal: json['capacidad_total'] as int,
        asientosDisponibles: json['asientos_disponibles'] as int,
        estado: json['estado'] as String,
        vehiculoPlaca: json['vehiculo_placa'] as String?,
        conductorNombre: json['conductor_nombre'] as String?,
        tarifa: _asDouble(json['tarifa']),
        asientos: ((json['asientos'] as List?) ?? const [])
            .map((e) => Asiento.fromJson(e as Map<String, dynamic>))
            .toList(),
        tarifas: ((json['tarifas'] as List?) ?? const [])
            .map((e) => TarifaTramo.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
