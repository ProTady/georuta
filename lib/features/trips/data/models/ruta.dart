import 'paradero.dart';

class Ruta {
  final String id;
  final String nombre;
  final String origenNombre;
  final String destinoNombre;
  final double? distanciaKm;
  final int? duracionEstimadaMin;
  final String estado;
  final List<RutaParadero> paraderos;

  const Ruta({
    required this.id,
    required this.nombre,
    required this.origenNombre,
    required this.destinoNombre,
    required this.estado,
    required this.paraderos,
    this.distanciaKm,
    this.duracionEstimadaMin,
  });

  factory Ruta.fromJson(Map<String, dynamic> json) => Ruta(
        id: json['id'].toString(),
        nombre: json['nombre'] as String,
        origenNombre: json['origen_nombre'] as String,
        destinoNombre: json['destino_nombre'] as String,
        distanciaKm: _asDouble(json['distancia_km']),
        duracionEstimadaMin: json['duracion_estimada_min'] as int?,
        estado: json['estado'] as String,
        paraderos: ((json['paraderos'] as List?) ?? const [])
            .map((e) => RutaParadero.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
