class User {
  final String id;
  final String telefono;
  final String? email;
  final String nombres;
  final String apellidos;
  final String role;
  final String estado;
  final DateTime? fechaRegistro;

  const User({
    required this.id,
    required this.telefono,
    required this.nombres,
    required this.apellidos,
    required this.role,
    required this.estado,
    this.email,
    this.fechaRegistro,
  });

  String get fullName => '$nombres $apellidos'.trim();

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        telefono: json['telefono'] as String,
        email: json['email'] as String?,
        nombres: (json['nombres'] as String?) ?? '',
        apellidos: (json['apellidos'] as String?) ?? '',
        role: (json['role'] as String?) ?? 'PASAJERO',
        estado: (json['estado'] as String?) ?? 'ACTIVO',
        fechaRegistro: json['fecha_registro'] != null
            ? DateTime.tryParse(json['fecha_registro'] as String)
            : null,
      );
}
