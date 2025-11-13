// NUEVO ARCHIVO: Modelo para la tabla de Clientes
// Contiene solo los 3 campos que solicitaste.

class Client {
  final String? id;
  final String name;
  final String? address;
  final String? city;
  final DateTime? createdAt;

  Client({
    this.id,
    required this.name,
    this.address,
    this.city,
    this.createdAt,
  });

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'],
      name: map['name'] ?? '',
      address: map['address'],
      city: map['city'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'city': city,
    };
  }
}