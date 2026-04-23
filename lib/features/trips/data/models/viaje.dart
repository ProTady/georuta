class Viaje {
  final String id;
  final String rutaId;
  final String rutaNombre;
  final DateTime fechaViaje;
  final DateTime horaSalidaProgramada;
  final int capacidadTotal;
  final int asientosDisponibles;
  final int asientosVendidos;
  final int minPasajerosParaSalir;
  final int etaMinutos;
  final String? origenActualNombre;
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
    this.asientosVendidos = 0,
    this.minPasajerosParaSalir = 0,
    this.etaMinutos = 0,
    this.origenActualNombre,
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
        capacidadTotal: _asInt(json['capacidad_total']),
        asientosDisponibles: _asInt(json['asientos_disponibles']),
        asientosVendidos: _asInt(json['asientos_vendidos']),
        minPasajerosParaSalir: _asInt(json['min_pasajeros_para_salir']),
        etaMinutos: _asInt(json['eta_minutos']),
        origenActualNombre: json['origen_actual_nombre'] as String?,
        estado: json['estado'] as String,
        vehiculoPlaca: json['vehiculo_placa'] as String?,
        conductorNombre: json['conductor_nombre'] as String?,
        tarifa: _asDouble(json['tarifa']),
      );

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
