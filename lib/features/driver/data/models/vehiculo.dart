class Vehiculo {
  final String id;
  final String placa;
  final String marca;
  final String modelo;
  final String color;
  final int capacidadAsientos;
  final Map<String, dynamic>? layout;

  const Vehiculo({
    required this.id,
    required this.placa,
    required this.marca,
    required this.modelo,
    required this.color,
    required this.capacidadAsientos,
    this.layout,
  });

  factory Vehiculo.fromJson(Map<String, dynamic> json) => Vehiculo(
        id: json['id'].toString(),
        placa: (json['placa'] ?? '') as String,
        marca: (json['marca'] ?? '') as String,
        modelo: (json['modelo'] ?? '') as String,
        color: (json['color'] ?? '') as String,
        capacidadAsientos: json['capacidad_asientos'] is int
            ? json['capacidad_asientos'] as int
            : int.tryParse('${json['capacidad_asientos']}') ?? 0,
        layout: json['layout'] is Map
            ? Map<String, dynamic>.from(json['layout'] as Map)
            : null,
      );

  String get descripcion {
    final mm = [marca, modelo].where((s) => s.isNotEmpty).join(' ');
    return mm.isEmpty ? placa : '$placa · $mm';
  }
}
