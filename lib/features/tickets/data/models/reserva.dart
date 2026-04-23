class ReservaItem {
  final String asientoId;
  final int asientoNumero;
  final double precio;

  const ReservaItem({
    required this.asientoId,
    required this.asientoNumero,
    required this.precio,
  });

  factory ReservaItem.fromJson(Map<String, dynamic> json) => ReservaItem(
        asientoId: json['asiento'].toString(),
        asientoNumero: json['asiento_numero'] as int,
        precio: (json['precio'] as num).toDouble(),
      );
}

class Reserva {
  final String id;
  final String viajeId;
  final String estado;
  final double total;
  final DateTime expiraEn;
  final int segundosRestantes;
  final List<ReservaItem> items;

  const Reserva({
    required this.id,
    required this.viajeId,
    required this.estado,
    required this.total,
    required this.expiraEn,
    required this.segundosRestantes,
    required this.items,
  });

  factory Reserva.fromJson(Map<String, dynamic> json) => Reserva(
        id: json['id'].toString(),
        viajeId: json['viaje'].toString(),
        estado: json['estado'] as String,
        total: (json['total'] as num).toDouble(),
        expiraEn: DateTime.parse(json['expira_en'] as String),
        segundosRestantes: (json['segundos_restantes'] ?? 0) as int,
        items: ((json['items'] as List?) ?? const [])
            .map((e) => ReservaItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
