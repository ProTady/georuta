class Boleto {
  final String id;
  final String viajeId;
  final String rutaNombre;
  final DateTime fechaViaje;
  final DateTime horaSalida;
  final int asientoNumero;
  final String origenNombre;
  final String destinoNombre;
  final double precio;
  final String qrToken;
  final String estado;
  final DateTime fechaEmision;

  const Boleto({
    required this.id,
    required this.viajeId,
    required this.rutaNombre,
    required this.fechaViaje,
    required this.horaSalida,
    required this.asientoNumero,
    required this.origenNombre,
    required this.destinoNombre,
    required this.precio,
    required this.qrToken,
    required this.estado,
    required this.fechaEmision,
  });

  factory Boleto.fromJson(Map<String, dynamic> json) => Boleto(
        id: json['id'].toString(),
        viajeId: json['viaje'].toString(),
        rutaNombre: (json['ruta_nombre'] ?? '') as String,
        fechaViaje: DateTime.parse(json['fecha_viaje'] as String),
        horaSalida: DateTime.parse(json['hora_salida'] as String),
        asientoNumero: json['asiento_numero'] as int,
        origenNombre: (json['origen_nombre'] ?? '') as String,
        destinoNombre: (json['destino_nombre'] ?? '') as String,
        precio: (json['precio'] as num).toDouble(),
        qrToken: json['qr_token'] as String,
        estado: json['estado'] as String,
        fechaEmision: DateTime.parse(json['fecha_emision'] as String),
      );
}
