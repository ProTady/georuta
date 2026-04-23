double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

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
        asientoNumero: _toInt(json['asiento_numero']),
        precio: _toDouble(json['precio']),
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
        total: _toDouble(json['total']),
        expiraEn: DateTime.parse(json['expira_en'] as String),
        segundosRestantes: _toInt(json['segundos_restantes']),
        items: ((json['items'] as List?) ?? const [])
            .map((e) => ReservaItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
