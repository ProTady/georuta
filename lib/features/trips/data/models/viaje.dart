class Viaje {
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

  const Viaje({
    required this.id,
    required this.rutaId,
    required this.rutaNombre,
    required this.fechaViaje,
    required this.horaSalidaProgramada,
    required this.capacidadTotal,
    required this.asientosDisponibles,
    required this.estado,
    this.vehiculoPlaca,
    this.conductorNombre,
    this.tarifa,
  });

  factory Viaje.fromJson(Map<String, dynamic> json) => Viaje(
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
      );

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
