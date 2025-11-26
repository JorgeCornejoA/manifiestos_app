// lib/models/client.dart
class Client {
  final String? id;
  final String name;
  final String domicilio;
  final String ciudad;

  Client({
    this.id,
    required this.name,
    this.domicilio = '',
    this.ciudad = '',
  });

  // Lee desde un mapa de Supabase (JSON)
  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'] as String?,
      name: map['name'] as String? ?? '',
      domicilio: map['domicilio'] as String? ?? '',
      ciudad: map['ciudad'] as String? ?? '',
    );
  }

  // Escribe a un mapa para Supabase (JSON)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'domicilio': domicilio,
      'ciudad': ciudad,
    };
  }
}