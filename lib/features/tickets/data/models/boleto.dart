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
        asientoNumero: json['asiento_numero'] is int
            ? json['asiento_numero'] as int
            : int.tryParse(json['asiento_numero'].toString()) ?? 0,
        origenNombre: (json['origen_nombre'] ?? '') as String,
        destinoNombre: (json['destino_nombre'] ?? '') as String,
        precio: json['precio'] is num
            ? (json['precio'] as num).toDouble()
            : double.tryParse(json['precio'].toString()) ?? 0,
        qrToken: json['qr_token'] as String,
        estado: json['estado'] as String,
        fechaEmision: DateTime.parse(json['fecha_emision'] as String),
      );
}
