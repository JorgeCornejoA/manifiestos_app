class Employee {
  final String? id;
  final String name;
  final String? signatureUrl;
  final String? email;
  final bool isAdmin; // <--- NUEVO CAMPO
  final bool soloLectura;

  Employee({
    this.id,
    required this.name,
    this.signatureUrl,
    this.email,
    this.isAdmin = false,
    this.soloLectura = false, // Por defecto falso
  });

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id']?.toString(),
      name: map['name'] ?? '',
      signatureUrl: map['signature_url'],
      email: map['email'],
      isAdmin: map['is_admin'] ?? false, // <--- NUEVO
      soloLectura: map['solo_lectura'] as bool? ?? false, // <--- MAPEO SEGURO
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'signature_url': signatureUrl,
      'email': email,
      'is_admin': isAdmin, // <--- NUEVO
      'solo_lectura': soloLectura, // <--- NUEVA COLUMNA
    };
  }
  
  @override
  String toString() => name;
}