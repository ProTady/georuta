class Paradero {
  final String id;
  final String nombre;
  final String? direccion;
  final double? latitud;
  final double? longitud;

  const Paradero({
    required this.id,
    required this.nombre,
    this.direccion,
    this.latitud,
    this.longitud,
  });

  factory Paradero.fromJson(Map<String, dynamic> json) => Paradero(
        id: json['id'].toString(),
        nombre: json['nombre'] as String,
        direccion: json['direccion'] as String?,
        latitud: _asDouble(json['latitud']),
        longitud: _asDouble(json['longitud']),
      );

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

class RutaParadero {
  final int orden;
  final String tipo;
  final int? tiempoEstimadoMin;
  final Paradero paradero;

  const RutaParadero({
    required this.orden,
    required this.tipo,
    required this.paradero,
    this.tiempoEstimadoMin,
  });

  factory RutaParadero.fromJson(Map<String, dynamic> json) => RutaParadero(
        orden: json['orden'] as int,
        tipo: json['tipo'] as String,
        tiempoEstimadoMin: json['tiempo_estimado_min'] as int?,
        paradero: Paradero.fromJson(json['paradero'] as Map<String, dynamic>),
      );
}
